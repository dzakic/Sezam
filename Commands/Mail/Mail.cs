using System;
using System.Linq;
using System.Threading.Tasks;
using System.Text.RegularExpressions;
using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Sezam.Data.EF;

namespace Sezam.Commands
{
    [Command]
    public class Mail : CommandSet
    {
        public Mail(Session session): base(session) { }

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
        /// Reads switches /a from command line.
        /// Returns IQueryable for streaming - caller should add .Include() as needed.
        /// </summary>
        /// <returns>IQueryable for deferred execution</returns>
        private async Task<IQueryable<PrivateMessage>> GetMailMsgSelection()
        {
            // Select all messages (including already read)
            bool selectAll = session.cmdLine.Switch("a");
            bool selectById = false;

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

            // 1. Message ID lookup by suffix match (#hex)
            // Check if the remaining token is exactly 4 chars AND all are valid hex digits using Regex
            if (!string.IsNullOrWhiteSpace(cleanToken) && cleanToken.Length == 4 && Regex.IsMatch(cleanToken, "^[0-9a-fA-F]{4}$"))
            {
                // Single message selection by GUID suffix
                messages = messages.Where(pm => pm.Id.ToString().EndsWith(cleanToken, StringComparison.OrdinalIgnoreCase));
            }
            // 2. Username filter (if no # prefix was present)
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

            // Filter by read status - only unread messages (unless /a switch)
            if (!selectAll)
            {
                messages = messages.Where(pm => pm.RecipientId == session.User.Id && pm.ReadTime == null);
            }

            return messages.OrderBy(pm => pm.SentTime);
        }

        [Command(Description = "Show a list of mail messages")]
        [CommandParameter("id|username", "Message ID to show or username to filter by sender")]
        [CommandSwitch('a', "Select all messages, including already read")]
        public async Task List()
        {
            var query = (await GetMailMsgSelection())
                .Include(pm => pm.Sender)
                .Include(pm => pm.Recipient);

            bool selectAll = session.cmdLine.Switch("a");
            bool hasMessages = false;

            foreach (var msg in query)
            {
                hasMessages = true;
                var localTime = session.User.ToLocalTime(msg.SentTime);
                // Start with ID suffix prepended by '#'
                string displayId = $"#{GetGuidSuffix(msg.Id)}";

                // Determine the party name and whether to show a 'From:' prefix is needed for clarity.
                string headerPrefix = "";
                if (msg.SenderId == session.User.Id) // Message SENT by current user
                {
                    headerPrefix = $"To: {msg.Recipient.Username}";
                } 
                else if (msg.RecipientId == session.User.Id) // Message RECEIVED by current user
                {
                    // No explicit prefix needed for the recipient, just show From:
                    headerPrefix = $"From: {msg.Sender.Username}";
                } else {
                    headerPrefix = $"Unknown Party";
                }

                await session.terminal.Line($"{displayId} {headerPrefix}, {localTime:dd/MM/yyyy HH:mm}");
            }

            if (!hasMessages)
                await session.terminal.Line(selectAll ? "You have no mail." : "You have no unread mail.");
        }

        [Command(Description = "Read mail messages")]
        [CommandParameter("id|username", "Message ID to display or username to filter by sender")]
        [CommandSwitch('a', "Select all messages, including already read")]
        public async Task Read()
        {
            var query = (await GetMailMsgSelection())
                .Include(pm => pm.Sender)
                .Include(pm => pm.Recipient)
                .Include(pm => pm.MessageText);

            bool selectAll = session.cmdLine.Switch("a");
            bool hasMessages = false;

            await foreach (var message in query.AsAsyncEnumerable())
            {
                hasMessages = true;

                // Display message
                var localTime = session.User.ToLocalTime(message.SentTime);
                await session.terminal.Line();
                await session.terminal.Line($"Message ID: {message.Id:N}");
                await session.terminal.Line($"From: {message.Sender.Username}");
                await session.terminal.Line($"To: {message.Recipient.Username}");
                await session.terminal.Line($"Date: {localTime:dd/MM/yyyy HH:mm}");

                if (message.ReadTime.HasValue && message.RecipientId == session.User.Id)
                {
                    var readLocalTime = session.User.ToLocalTime(message.ReadTime.Value);
                    await session.terminal.Line($"Read: {readLocalTime:dd/MM/yyyy HH:mm}");
                }

                await session.terminal.Line();
                await session.terminal.Text(message.MessageText.Text);
                await session.terminal.Line();

            }

            if (!hasMessages)
                await session.terminal.Line(selectAll ? "You have no mail." : "You have no unread mail.");
        }

        /// <summary>
        /// Helper to get the last 4 hexadecimal characters of a GUID for simplified display.
        /// </summary>
        private string GetGuidSuffix(Guid id)
        {
            var guidString = id.ToString("N"); // N format removes hyphens
            return guidString.Length >= 4 ? guidString[^4..] : guidString;
        }


    }
}
