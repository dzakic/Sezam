using System;
using System.Linq;
using System.Threading.Tasks;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Sezam.Commands;
using Sezam.Data;
using Sezam.Data.EF;
using static Sezam.Commands.MailDTOExtensions;

namespace Sezam.Commands
{
    [Command]
    public class Mail : CommandSet
    {
        public Mail(Session session) : base(session) { }

        [Command(Description = "Write and send mail to a user")]
        public async Task Write()
        {
            // Get recipient user from command line
            var recipient = await GetRequiredUser();

            if (recipient.Id == session.User.Id)
            {
                await session.terminal.Line("You cannot send mail to yourself.");
                return;
            }

            await session.terminal.Line($"Message for {recipient.Username}. End with '.' on a line by itself.");

            // Get message text
            var messageBody = await session.terminal.PromptMultiLineEdit();

            if (string.IsNullOrWhiteSpace(messageBody))
            {
                await session.terminal.Line("Message is empty. Not sent.");
                return;
            }

            // Create MessageText entity
            var messageText = new MessageText
            {
                Id = Guid.NewGuid(),
                Text = messageBody
            };

            // Create PrivateMessage entity
            var privateMessage = new PrivateMessage
            {
                Id = Guid.NewGuid(),
                SenderId = session.User.Id,
                RecipientId = recipient.Id,
                MessageTextId = messageText.Id,
                SentTime = DateTime.UtcNow,
                IsDeleted = false
            };

            // Save to database
            session.Db.MessageTexts.Add(messageText);
            session.Db.PrivateMessages.Add(privateMessage);
            await session.Db.SaveChangesAsync();

            await session.terminal.Line();
            await session.terminal.Line($"Message sent to {recipient.Username}");
        }

        /// <summary>
        /// Builds the message selection query based on command line parameters.
        /// All filtering (id, sender, date, read status) is applied server-side so the query
        /// stays lazily evaluated and streamable; nothing is materialized before filtering.
        /// The current-user scope is provided by the PrivateMessage global query filter, so
        /// id/sender lookups never surface other users' mail.
        /// </summary>
        private async Task<IQueryable<PrivateMessage>> GetMailMsgSelection()
        {
            // Select all messages (including already read)
            bool selectAll = session.cmdLine.Switch("a");

            // Date range filtering
            var dateRange = session.cmdLine.TryScanForDateRange();

            // Get next token - could be a #hex ID or a username
            string token = session.cmdLine.GetToken();
            string rawToken = token;
            string cleanToken = rawToken;

            IQueryable<PrivateMessage> messages = session.Db.PrivateMessages
                .Where(pm => !pm.IsDeleted);

            if (!string.IsNullOrEmpty(rawToken) && rawToken[0] == '#')
            {
                cleanToken = rawToken[1..]; // Strip the leading '#'
            }

            // Message id lookup: exactly 4 hex chars map to the 2-byte stored GuidTail, so
            // this becomes an indexed equality predicate (no in-memory filter, no string scan).
            byte[] idKey = Array.Empty<byte>();
            if (!string.IsNullOrWhiteSpace(cleanToken) && cleanToken.Length == 4 && Regex.IsMatch(cleanToken, "^[0-9a-fA-F]{4}$"))
            {
                idKey = Convert.FromHexString(cleanToken);
                messages = messages.Where(pm => pm.GuidTail == idKey);
            }
            // Username filter (if no # prefix was present)
            else if (!string.IsNullOrWhiteSpace(rawToken) && rawToken[0] != '#')
            {
                var fromUser = await session.GetUser(rawToken);
                if (fromUser == null)
                    throw new ArgumentException("Unknown User", rawToken);

                // Filter by sender
                messages = messages.Where(pm => pm.SenderId == fromUser.Id);
            }
            // 3. Handle invalid/unmatched arguments
            else if (!string.IsNullOrWhiteSpace(rawToken))
            {
                throw new ArgumentException("Invalid argument provided", rawToken);
            }

            // Date range filter (inclusive)
            if (dateRange != null!)
            {
                if (dateRange.Low.HasValue)
                    messages = messages.Where(pm => pm.SentTime >= dateRange.Low.Value);
                if (dateRange.High.HasValue)
                    messages = messages.Where(pm => pm.SentTime < dateRange.High!.Value.AddDays(1));
            }

            // Read status (only when /a switch not given)
            if (!selectAll)
            {
                if (idKey.Length > 0)
                {
                    // Explicit message ID: read regardless of read status. The global
                    // query filter already scopes to the current user; the id predicate
                    // below narrows to the exact message.
                }
                else
                {
                    // Default inbox: only unread messages addressed to the current user
                    messages = messages.Where(pm => pm.RecipientId == session.User.Id && pm.ReadTime == null);
                }
            }

            return messages.OrderBy(pm => pm.SentTime);
        }

        [Command(Description = "Show a list of mail messages")]
        [CommandParameter("id", "Message ID to display")]
        [CommandParameter("username", "Username to filter by sender")]
        [CommandSwitch('a', "Select all messages, including already read")]
        public async IAsyncEnumerable<string> List()
        {
            var selection = await GetMailMsgSelection();
            bool selectAll = session.cmdLine.Switch("a");
            int currentUserId = session.User.Id;
            int count = 0;

            // Stream server-side filtered rows; format each entity client-side. No full
            // list is materialized into memory before display.
            await foreach (var pm in selection
                .Include(pm => pm.Sender)
                .Include(pm => pm.Recipient)
                .AsNoTracking()
                .AsAsyncEnumerable()
                .WithCancellation(session.CancellationToken))
            {
                count++;
                var dto = new MailListDTO
                {
                    displayId = "#" + GetGuidSuffix(pm.Id),
                    headerPrefix = GetHeaderPrefix(pm.SenderId, pm.RecipientId, GetUsernameSafe(pm.Sender), GetUsernameSafe(pm.Recipient), currentUserId),
                    sentTime = session.User.ToLocalTime(pm.SentTime),
                    time = pm.SentTime
                };
                yield return $"{dto.displayId} {dto.headerPrefix}, {dto.sentTime:dd/MM/yyyy HH:mm}";
            }

            if (count == 0)
                yield return selectAll ? L("Mail_NoMessages") : L("Mail_NoNewMessages");
        }

        [Command(Description = "Read mail messages")]
        [CommandParameter("id", "Message ID to display")]
        [CommandParameter("username", "Username to filter by sender")]
        [CommandSwitch('a', "Select all messages, including already read")]
        public async IAsyncEnumerable<string> Read()
        {
            var selection = await GetMailMsgSelection();
            bool selectAll = session.cmdLine.Switch("a");
            int currentUserId = session.User.Id;
            int count = 0;

            // Stream server-side filtered rows (JOIN pulls the body via MessageText);
            // format each entity client-side. No full message set is materialized.
            await foreach (var pm in selection
                .Include(pm => pm.Sender)
                .Include(pm => pm.Recipient)
                .Include(pm => pm.MessageText)
                .AsNoTracking()
                .AsAsyncEnumerable()
                .WithCancellation(session.CancellationToken))
            {
                count++;
                var dto = new MailReadDTO
                {
                    id = pm.Id,
                    senderUsername = GetUsernameSafe(pm.Sender),
                    recipientUsername = GetUsernameSafe(pm.Recipient),
                    sentTime = session.User.ToLocalTime(pm.SentTime),
                    time = pm.SentTime,
                    origTime = pm.SentTime,
                    readTime = pm.ReadTime.HasValue ? session.User.ToLocalTime(pm.ReadTime.Value) : null,
                    text = pm.MessageText?.Text ?? ""
                };
                await foreach (var line in FormatMailRead(dto)
                    .WithCancellation(session.CancellationToken))
                {
                    yield return line;
                }
            }

            if (count == 0)
                yield return selectAll ? L("Mail_NoMessages") : L("Mail_NoNewMessages");
        }

        public static IAsyncEnumerable<string> FormatMailRead(MailReadDTO message)
        {
            var lines = new List<string>();

            lines.Add("");
            lines.Add($"Message ID: {message.id:N}");
            lines.Add($"From: {message.senderUsername}");
            lines.Add($"To: {message.recipientUsername}");
            lines.Add($"Sent: {message.sentTime:dd/MM/yyyy HH:mm}");

            if (message.readTime.HasValue)
            {
                lines.Add($"Read: {message.readTime.Value:dd/MM/yyyy HH:mm}");
            }

            lines.Add("");

            foreach (var line in message.text.Split(["\r\n", "\n"], StringSplitOptions.None))
            {
                lines.Add(line);
            }

            lines.Add("");

            return lines.AsAsyncEnumerable();
        }

        [Command(Description = "Mark messages as read (seen)")]
        [CommandParameter("date", "Optional date to mark as seen (format: ddMMyy[yy] or ddMMyy[yy]-ddMm[yy] for date range)")]
        [CommandSwitch('a', "Mark all messages as seen")]
        public async Task Seen()
        {
            bool selectAll = session.cmdLine.Switch("a");

            string token = session.cmdLine.GetToken();

            // Get date range
            var dateRange = session.cmdLine.TryScanForDateRange();

            IQueryable<PrivateMessage> messages = session.Db.PrivateMessages
                .Where(pm => !pm.IsDeleted && pm.RecipientId == session.User.Id);

            if (!selectAll)
            {
                // Date range filter (inclusive)
                if (dateRange != null!)
                {
                    if (dateRange.Low.HasValue)
                        messages = messages.Where(pm => pm.SentTime >= dateRange.Low.Value);
                    if (dateRange.High.HasValue)
                        messages = messages.Where(pm => pm.SentTime < dateRange.High!.Value.AddDays(1));
                }
            }

            var messagesToMark = await messages.ToListAsync();

            if (messagesToMark.Count == 0)
            {
                await session.terminal.Line(selectAll ? L("Mail_NoMessages") : L("Mail_NoNewMessages"));
                return;
            }

            foreach (var message in messagesToMark)
            {
                if (!selectAll)
                {
                    // Check if message falls within date range
                    if (dateRange != null!)
                    {
                        if (dateRange.Low.HasValue && message.SentTime < dateRange.Low.Value)
                            continue;
                        if (dateRange.High.HasValue && message.SentTime >= dateRange.High!.Value.AddDays(1))
                            continue;
                    }
                }

                message.ReadTime = DateTime.UtcNow;
            }

            await session.Db.SaveChangesAsync();

            var count = messagesToMark.Count;
            await session.terminal.Line($"Marked {count} message(s) as read");
        }

        [Command(Description = "Delete a mail message")]
        public async Task Delete()
        {
            bool selectAll = session.cmdLine.Switch("a");

            string token = session.cmdLine.GetToken();
            string rawToken = token;
            string cleanToken = rawToken;

            IQueryable<PrivateMessage> messages = session.Db.PrivateMessages
                .Where(pm => !pm.IsDeleted);

            if (!string.IsNullOrEmpty(rawToken) && rawToken[0] == '#')
            {
                cleanToken = rawToken[1..]; // Strip the leading '#'
            }

            // Message id lookup: 4 hex -> 2-byte stored GuidTail (indexed predicate, no in-memory scan).
            if (!string.IsNullOrWhiteSpace(cleanToken) && cleanToken.Length == 4 && Regex.IsMatch(cleanToken, "^[0-9a-fA-F]{4}$"))
            {
                byte[] key = Convert.FromHexString(cleanToken);
                messages = messages.Where(pm => pm.GuidTail == key);
            }
            else if (!string.IsNullOrWhiteSpace(rawToken) && rawToken[0] != '#')
            {
                var fromUser = await session.GetUser(rawToken);
                if (fromUser == null)
                    throw new ArgumentException("Unknown User", rawToken);

                messages = messages.Where(pm => pm.SenderId == fromUser.Id);
            }
            else if (!string.IsNullOrWhiteSpace(rawToken))
            {
                throw new ArgumentException("Invalid argument provided", rawToken);
            }

            if (!selectAll)
            {
                messages = messages.Where(pm => pm.RecipientId == session.User.Id);
            }

            var messagesToDelete = await messages.ToListAsync();

            if (messagesToDelete.Count == 0)
            {
                await session.terminal.Line(L("Mail_NoMessages"));
                return;
            }

            foreach (var message in messagesToDelete)
            {
                message.IsDeleted = true;
                if (!selectAll && message.RecipientId == session.User.Id)
                {
                    message.ReadTime = DateTime.UtcNow;
                }
            }

            await session.Db.SaveChangesAsync();

            await session.terminal.Line($"Deleted {messagesToDelete.Count} message(s)");
        }

        new private async Task<User> GetRequiredUser()
        {
            var username = session.cmdLine.GetToken();
            if (!username.HasValue())
                throw new ArgumentException("Username required");

            var user = await session.GetUser(username)
                ?? throw new ArgumentException($"Unknown user: {username}");
            return user;
        }
    }
}
