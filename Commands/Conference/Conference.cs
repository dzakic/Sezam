using Microsoft.EntityFrameworkCore;
using Sezam.Data.EF;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using static System.Collections.Specialized.BitVector32;

namespace Sezam.Commands
{


    // TODO: Implement topic management commands (create, delete, redirect, etc.)
    [Command]
    public class Topic : CommandSet
    {
        public Topic(Session session)
           : base(session)
        {
            // currentTopic = null;
        }
    }

    [Command]
    public class Conference : CommandSet
    {
        public Conference(Session session)
           : base(session)
        {
            currentConference = null;
        }

        public ConfStat Status() => null;

        public Sezam.Data.EF.Conference CurrentConference
        { get { return currentConference; } }

        public override string GetPrompt()
        {
            return currentConference != null ?
               string.Format("Conf:{0}", currentConference.VolumeName) : "Conference";
        }

        private IQueryable<Sezam.Data.EF.Conference> GetConferences(bool IncludeResigned = false)
        {
            var userId = session.User.Id;
            var conferences =
                session.Db.Conferences
                    .Include(c => c.UserConf)
                    .Where(c =>
                        c.UserConf.Status.HasFlag(UserConf.UserConfStat.Admin) ||
                        (
                            (!c.Status.HasFlag(ConfStatus.Private) || c.UserConf.Status.HasFlag(UserConf.UserConfStat.Allowed)) &&
                            !c.Status.HasFlag(ConfStatus.Closed) &&
                            !c.UserConf.Status.HasFlag(UserConf.UserConfStat.Denied)
                        ));

            // Default: Restrict to non-resigned
            if (!IncludeResigned)
                conferences = conferences
                    .Where(c =>
                        !c.UserConf.Status.HasFlag(UserConf.UserConfStat.Resigned));

            return conferences
                .Include(c => c.ConfTopics
                 //.Where(t =>
                 // !string.IsNullOrEmpty(t.Name) &&
                 //    !t.Status.HasFlag(ConfTopic.TopicStatus.Deleted) &&
                 //   !t.Status.HasFlag(ConfTopic.TopicStatus.Private)
                 //)
                 )
                .OrderBy(c => c.Name)
                .ThenBy(c => c.VolumeNo);
        }

        [Command(Aliases = ["Show"], Description = "Show a list of all conferences")]
        [CommandSwitch('a', "Show all conferences, including resigned")]
        public async IAsyncEnumerable<string> View()
        {
            string confPattern = session.cmdLine.GetToken();
            bool showAll = session.cmdLine.Switch("a");
            var conferences = GetConferences(showAll);
            if (!string.IsNullOrEmpty(confPattern))
                conferences = conferences.Where(c => EF.Functions.Like(c.Name, confPattern + "%"));
            await foreach (var g in conferences.DisplayOrder().AsAsyncEnumerable().WithCancellation(session.CancellationToken))
                yield return string.Format(CultureInfo.InvariantCulture,
                    "{0,-16} {1,5} {2:MMM yyyy} - {3:MMM yyyy}",
                    g.VolumeName, g.ConfTopics.Sum(t => t.NextSequence), g.FromDate, g.ToDate);
        }

        [Command]
        private async Task Unresign()
        {
            // Unresign
            var userConfData = session.User.GetUserConfInfo(currentConference);
            if (userConfData.Status.HasFlag(UserConf.UserConfStat.Resigned))
            {
                userConfData.Status &= ~UserConf.UserConfStat.Resigned;
                // Show welcome?
                await session.terminal.Line(L("Conf_Welcome"), currentConference.VolumeName);
                await session.Db.SaveChangesAsync();
                Debug.WriteLine($"Joined conf {0}", currentConference.VolumeName);
            }
        }

        [Command(Aliases = ["Open"], Description = "Open a conference, make it current and default for subsequent commands")]
        public async Task Join()
        {

            string userInput = session.cmdLine.GetToken();

            string confName = string.Empty;
            int volumeNo = 0;

            var regex = new Regex(@"^(.+?)(\.(\d+))?$");
            var match = regex.Match(userInput);
            if (match.Success)
            {
                if (match.Groups.Count >= 1)
                    confName = match.Groups[1].Value;
                if (match.Groups.Count >= 3 && int.TryParse(match.Groups[3].Value, out int i))
                    volumeNo = i;
            }

            var exactMatch = GetConferences(true);
            if (!string.IsNullOrEmpty(confName))
                exactMatch = exactMatch
                    .Where(c => EF.Functions.Like(c.Name, confName + "%") && c.VolumeNo == volumeNo);
            var conf = exactMatch
                .Include(c => c.ConfTopics)
                .FirstOrDefault();
            if (conf != null)
            {
                currentConference = conf;
                await Unresign();
            }
            else
            {
                var activeConf = GetConferences(false);
                if (!string.IsNullOrEmpty(confName))
                    activeConf = activeConf.Where(c => EF.Functions.Like(c.Name, confName + "%"));
                if (volumeNo > 0)
                    activeConf = activeConf.Where(c => c.VolumeNo == volumeNo);
                conf = activeConf
                    .Include(c => c.ConfTopics)
                    .OrderBy(c => c.Name)
                    .ThenByDescending(c => c.VolumeNo)
                    .FirstOrDefault();

                if (conf != null)
                    currentConference = conf;
                else
                    await session.terminal.Line("Unknown conference {0}", confName);
            }
        }

        [Command(Description = "Close the currently open conference")]
        public void Close()
        {
            currentConference = null;
        }

        private void MustHaveConf()
        {
            if (currentConference == null)
                throw new ArgumentException("Conference not selected");
        }

        /// <summary>
        /// Builds the message selection query based on command line parameters.
        /// Reads switches /a, /f, /r from command line.
        /// Returns IQueryable for streaming - caller should add .Include() as needed.
        /// </summary>
        /// <returns>IQueryable for deferred execution</returns>
        private async Task<IQueryable<ConfMessage>> GetConfMsgSelection()
        {
            MustHaveConf();

            // Filter Files only
            bool filesOnly = session.cmdLine.Switch("f");

            // Replies to my messages only
            bool myRepliesOnly = session.cmdLine.Switch("r");

            // Select all messages (including already seen)
            bool selectAll = session.cmdLine.Switch("a");

            // Date range (optional). A bare token like 05012026 or a 'lo-high' range
            // (e.g. 01012026-01032026, 01012026-, -01032026) where either bound may
            // use a 2- or 4-digit year and may carry a trailing HHmm time. The date
            // is scanned out of the queue first so that the remaining positional tokens
            // are only topic/msg-range and "from" user, e.g.
            //   're 01012026-01032026'         (all topics)
            //   're borland 01012026-01032026' (topic + date)
            var dateRange = session.cmdLine.TryScanForDateRange();

            // The first positional token is always a topic / msg-range selector
            // ('borland', '1', '1.2', '1.4-', '*', ...).
            string topicMsgs = session.cmdLine.GetToken();
            var topicMsgRange = currentConference.GetTopicMsgRange(topicMsgs, true);

            IQueryable<ConfMessage> messages = session.Db.ConfMessages;

            // Note: No .Include() for Author/ParentMessage.Author needed here.
            // The DTO projections (AsListDTO/AsReadDTO) use .Select() which makes
            // EF Core generate JOINs only for the projected columns (e.g. Username),
            // ignoring any .Include() calls. Navigation properties in .Where() clauses
            // are also handled automatically by EF Core.
            messages = messages
                .Include(m => m.Topic)
                    .ThenInclude(t => t.UserTopic);

            // Topic Selection
            if (topicMsgRange?.topic != null)
            {
                messages = messages
                    .Where(m => m.TopicId == topicMsgRange.topic.Id);
            }
            else
            {
                messages = messages
                    .Where(m => m.Topic.ConferenceId == currentConference.Id
                        && !string.IsNullOrEmpty(m.Topic.Name)
                        && !m.Topic.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                        && !m.Topic.Status.HasFlag(ConfTopic.TopicStatus.Private)
                     );
            }

            // Explicit selector (msg range / single msg / open-ended) OR an explicit
            // date range bypasses the seen filter.
            bool hasExplicitSelector = topicMsgRange?.HasMessageSelector == true || dateRange != null!;

            // Message number range (only when an explicit msg selector was given)
            if (topicMsgRange?.HasMessageSelector == true)
            {
                if (topicMsgRange.msgLow > 0)
                    if (topicMsgRange.msgLow == topicMsgRange.msgHigh)
                    {
                        // Single msg
                        messages = messages.Where(m => m.MsgNo.Equals(topicMsgRange.msgLow));
                    }
                    else
                    {
                        // Range
                        messages = messages.Where(m => m.MsgNo >= topicMsgRange.msgLow);
                    }

                // Upper bound
                if (topicMsgRange.msgHigh > 0 && topicMsgRange.msgLow != topicMsgRange.msgHigh)
                    messages = messages.Where(m => m.MsgNo <= topicMsgRange.msgHigh);
            }

            // Date-range filter (inclusive of both endpoints' full days). The upper
            // bound is exclusive on the day after, so all messages on the end day are
            // included regardless of their time-of-day.
            if (dateRange != null!)
            {
                if (dateRange.Low.HasValue)
                    messages = messages.Where(m => m.Time >= dateRange.Low.Value);
                if (dateRange.High.HasValue)
                    messages = messages.Where(m => m.Time < dateRange.High!.Value.AddDays(1));
            }

            // Filter by SeenTime - only new messages (unless /a switch or an explicit selector)
            else if (!selectAll && !hasExplicitSelector)
            {
                messages = messages
                    .Where(m => m.Topic.UserTopic == null || m.Time > m.Topic.UserTopic.SeenTime);
            }

            // Filter FROM (user)
            string fromStr = session.cmdLine.GetToken();
            Data.EF.User fromUser = null;
            if (!string.IsNullOrWhiteSpace(fromStr) && fromStr != "*")
            {
                if (fromStr == "$")
                    fromUser = session.User;
                else
                {
                    fromUser = await session.GetUser(fromStr);
                    if (fromUser == null)
                        throw new ArgumentException("Unknown User", fromStr);
                }
            }
            if (fromUser != null)
                messages = messages.Where(m => m.AuthorId == fromUser.Id && !m.Status.HasFlag(ConfMessage.MessageStatus.Anonymous));

            if (filesOnly)
                messages = messages.Where(m => !string.IsNullOrEmpty(m.Filename));

            if (myRepliesOnly)
                messages = messages.Where(m => m.ParentMessage.AuthorId == session.User.Id);

            return messages
                .Where(m => !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted))
                .OrderBy(m => m.Topic.TopicNo)
                .ThenBy(m => m.MsgNo);
        }

        private async IAsyncEnumerable<string> ConfDir(Data.EF.Conference conf)
        {
            var topicsWithCounts = await (from t in session.Db.ConfTopics
                                          where t.ConferenceId == conf.Id
                                          where t.UserTopic == null || !t.UserTopic.Status.HasFlag(UserTopic.UserTopicStat.Resigned)
                                          select new
                                          {
                                              Topic = t,
                                              TotalCount = (from m in session.Db.ConfMessages
                                                            where m.TopicId == t.Id
                                                            where !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted)
                                                            select m).Count(),
                                              NewCount = (from m in session.Db.ConfMessages
                                                          where m.TopicId == t.Id
                                                          where !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted)
                                                          where m.Topic.UserTopic == null || m.Time > m.Topic.UserTopic.SeenTime
                                                          select m).Count()
                                          }).ToListAsync();

            foreach (var topicWithCount in topicsWithCounts.OrderBy(t => t.Topic.TopicNo))
                yield return ConfFormatter.FormatTopic(topicWithCount.Topic, topicWithCount.TotalCount, topicWithCount.NewCount);
        }

        [Command(Description = "Show a list of topics in the current conference, or all in all conferences if none open")]
        public async IAsyncEnumerable<string> Directory()
        {
            if (currentConference != null)
            {
                await foreach (var line in ConfDir(currentConference))
                    yield return line;
            }
            else
            {
                var activeConferences = GetConferences()
                    .DisplayOrder()
                    .ToList();  // Materialize to avoid open DataReader conflict with ConfDir()
                foreach (var conf in activeConferences)
                {
                    yield return string.Format("Conference {0}", conf.VolumeName);
                    await foreach (var line in ConfDir(conf))
                        yield return line;
                    yield return "";
                }
            }
        }

        /// <summary>
        /// Iterates over messages, applies action to each, shows "no messages" if empty.
        /// </summary>
        private async Task ProcessMessages(IQueryable<ConfMessage> query, Func<ConfMessage, Task> processMessage)
        {
            bool selectAll = session.cmdLine.Switch("a");
            bool hasMessages = false;

            foreach (var msg in query)
            {
                hasMessages = true;
                await processMessage(msg);
            }

            if (!hasMessages)
                await session.terminal.Line(selectAll ? L("Conf_NoMessages") : L("Conf_NoNewMessages"));
        }

        [Command(Description = "Show a list of new messages in the conference or a topic")]
        [CommandParameter("topic[.msgLow[-msgHigh]]", "Topic and optional message number or range to list, e.g. 'General', 'General.5' or 'General.5-10'. Use '*' for all topics, e.g. '*.5' or '*.5-10'.")]
        [CommandParameter("from", "Only select messages from this author, specify the username.")]
        [CommandSwitch('f', "Select only messages with files")]
        [CommandSwitch('a', "Select all messages, including already seen")]
        public async IAsyncEnumerable<string> List()
        {
            var query = (await GetConfMsgSelection())
                .AsListDTO();
            await foreach (var confListItem in query.WithCancellation(session.CancellationToken))
                yield return ConfFormatter.FormatConfMsgList(confListItem, session.User.ToLocalTime);
        }

        [Command(Description = "Read new messages in the conference or a topic")]
        [CommandParameter("topic[.msgLow[-msgHigh]]", "Topic and optional message number or range to list, e.g. 'General', 'General.5' or 'General.5-10'. Use '*' for all topics, e.g. '*.5' or '*.5-10'.")]
        [CommandParameter("from", "Only select messages from this author, specify the username.")]
        [CommandSwitch('f', "Select only messages with files")]
        [CommandSwitch('a', "Select all messages, including old")]
        public async IAsyncEnumerable<string> Read()
        {
            // No need to .Include(m => m.MessageText)
            // AsReadTDO projection will pull the text and EF Core will generate the necessary JOIN
            var query = (await GetConfMsgSelection())
                .AsReadDTO();
            await foreach (var msg in query.WithCancellation(session.CancellationToken))
                await foreach (var line in ConfFormatter.ConfMsgRead(msg, session.User.ToLocalTime, L)
                    .WithCancellation(session.CancellationToken))
                    yield return line;
        }

        [Command(Description = "Reply to a conference message, or start a new message in a topic")]
        [CommandParameter("topic[.msgno]", "Topic name (abbreviated) or number, optionally '.msgno' to reply to a specific message")]
        public async Task REPly()
        {
            MustHaveConf();

            string userInput = session.cmdLine.GetToken();
            if (string.IsNullOrWhiteSpace(userInput))
                throw new ArgumentException("Topic required");

            string topicStr = userInput;
            int? parentMsgNo = null;
            int dotPos = userInput.IndexOf('.');
            if (dotPos >= 0)
            {
                topicStr = userInput[..dotPos];
                string msgNoStr = userInput[(dotPos + 1)..];
                if (msgNoStr.Length > 0 && int.TryParse(msgNoStr, out int parentNo))
                    parentMsgNo = parentNo;
            }

            ConfTopic topic = currentConference.GetTopicFromStr(topicStr, Required: true);
            if (topic == null || topic.IsDeleted())
                throw new ArgumentException(string.Format(strings.Conf_UnknownTopic, topicStr));

            if (session.User.GetUserTopicfInfo(topic).Status.HasFlag(UserTopic.UserTopicStat.Denied))
            {
                await session.terminal.Line(L("Conf_ReplyDenied"), topic.Name);
                return;
            }

            ConfMessage parentMessage = null;
            if (parentMsgNo.HasValue)
            {
                parentMessage = await session.Db.ConfMessages
                    .Include(m => m.Topic)
                    .Include(m => m.ParentMessage)
                    .Include(m => m.MessageText)
                    .Where(m => m.TopicId == topic.Id && m.MsgNo == parentMsgNo.Value)
                    .FirstOrDefaultAsync();
                if (parentMessage == null)
                    throw new ArgumentException(string.Format(strings.Conf_UnknownTopic, topicStr + "." + parentMsgNo.Value));
            }

            bool isReply = parentMessage != null;
            string replyPrompt = isReply ? L("Conf_ReplyPrompt") : L("Conf_ReplyNewPrompt");
            await session.terminal.Line(replyPrompt, topic.Name);

            var messageText = await session.terminal.PromptMultiLineEdit();
            if (string.IsNullOrWhiteSpace(messageText))
            {
                await session.terminal.Line("Message is empty. Not sent.");
                return;
            }

            topic.NextSequence++;
            int msgNo = topic.NextSequence;

            Guid messageId = Guid.NewGuid();
            var messageEntity = new MessageText { Id = messageId, Text = messageText };
            var confMessage = new ConfMessage
            {
                Id = messageId,
                AuthorId = session.User.Id,
                Status = ConfMessage.MessageStatus.Notify,
                TopicId = topic.Id,
                MsgNo = msgNo,
                ParentMessageId = parentMessage?.Id,
                Time = DateTime.UtcNow,
                MessageText = messageEntity
            };
            confMessage.Topic = topic;
            confMessage.ParentMessage = parentMessage;

            session.Db.MessageTexts.Add(messageEntity);
            session.Db.ConfMessages.Add(confMessage);
            await session.Db.SaveChangesAsync();

            string replySent = isReply ? L("Conf_ReplySent") : L("Conf_ReplyNewMsg");
            await session.terminal.Line(replySent, topic.Name, msgNo);
        }

        [Command(Description = "Topic management. Not implemented.")]
        public void Topic()
        {
            // Needs to parse a further topic command (Nexted CommandSet?))
            throw new NotImplementedException();
        }

        [Command("RESign", Description = "Unfollowing this conference. To join again, use join command with the exact conference name.")]
        public async Task RESign()
        {
            MustHaveConf();

            string topicStr = session.cmdLine.GetToken();
            var topic = currentConference.GetTopicFromStr(topicStr, false);

            if (topic != null)
            {
                // Resign Topic
                var utData = session.User.GetUserTopicfInfo(topic);
                utData.Status |= UserTopic.UserTopicStat.Resigned;
                await session.terminal.Line(L("Conf_TopicResigned"), topic.Name);
            }
            else
            {
                // Resign Conference
                var ucData = session.User.GetUserConfInfo(currentConference);
                ucData.Status |= UserConf.UserConfStat.Resigned;
                await session.terminal.Line(L("Conf_Resigned"), currentConference.VolumeName);
                currentConference = null;
            }

            await session.Db.SaveChangesAsync();

        }

        [Command(Description = "Make all messages 'seen'")]
        [CommandSwitch('a', "All conferences, otherwise only the current one")]
        [CommandParameter("datetime", "Optional datetime to set as seen time. Defaults to now. Format: ddMMyyyy[HHmm]")]
        public async IAsyncEnumerable<string> SEEn()
        {
            bool allConferences = session.cmdLine.Switch("a");

            if (!allConferences)
                MustHaveConf();

            // Get date range from command line
            DateTime? seenDate = session.cmdLine.GetDateTime();
            DateTime seenTime = seenDate.HasValue ? seenDate.Value.ToUniversalTime() : DateTime.UtcNow;

            // Get topics to update (excluding resigned topics)
            IEnumerable<ConfTopic> topics;
            if (allConferences)
            {
                // All topics from all conferences the user has access to
                var conferenceIds = GetConferences()
                    .Select(c => c.Id)
                    .ToList();

                topics = session.Db.ConfTopics
                    .Include(t => t.UserTopic)
                    .Where(t => conferenceIds.Contains(t.ConferenceId))
                    .Where(t => t.UserTopic == null || !t.UserTopic.Status.HasFlag(UserTopic.UserTopicStat.Resigned))
                    .ToList();
            }
            else
            {
                // Only topics from the current conference
                topics = session.Db.ConfTopics
                    .Include(t => t.UserTopic)
                    .Where(t => t.ConferenceId == currentConference.Id)
                    .Where(t => t.UserTopic == null || !t.UserTopic.Status.HasFlag(UserTopic.UserTopicStat.Resigned))
                    .ToList();
            }

            // Update SeenTime for each topic via the User's UserTopic collection
            foreach (var topic in topics)
            {
                var utData = session.User.GetUserTopicfInfo(topic);
                utData.SeenTime = seenTime;
            }

            await session.Db.SaveChangesAsync();

            if (allConferences)
                yield return L("Conf_SeenAll");
            else
                yield return string.Format(L("Conf_Seen"), currentConference.VolumeName);
        }

        public Sezam.Data.EF.Conference currentConference;
    }

    public static class ConfFormatter
    {
        public static string FormatTopic(ConfTopic topic, int totalCount, int newCount)
        {
            var sb = new StringBuilder();
            var typ = topic.Status.GetType();
            var values = Enum.GetValues(typ).Cast<ConfTopic.TopicStatus>()
                .Where(v => topic.Status.HasFlag(v));

            var valStrs = new List<string>();
            foreach (var value in values)
                valStrs.Add(Enum.GetName(typ, value));

            var newMsgStr = newCount > 0 ? $"{newCount} new" : "no new messages";

            sb.AppendFormat("{0,2}. {1,-16} {2,5} total, {3}",
               topic.TopicNo, topic.Name, topic.NextSequence, newMsgStr);
            if (topic.RedirectTo != null)
            {
                sb.Append(string.Format(" -> {0}", topic.RedirectTo.Name));
            }
            sb.Append(' ');
            sb.Append(string.Join(", ", valStrs));
            return sb.ToString();
        }

        #region MessageSample

        /*
        ================================
        Sezam, Pitanja.178, evlad
        (2.178) Uto 16/01/1996 20:24, 1278 chr
        Odgovor na 2.172, fancy, Uto 16/01/1996 11:00
        ----------------------------------------------------------------
        $> Zato što su prethodni vlasnici "GoToHob" softvera u posedu baze
        ===================================
        */

        #endregion MessageSample

        public static async IAsyncEnumerable<string> ConfMsgRead(
            ConfReadDTO msg, Func<DateTime, DateTime> toLocalTime, Func<string, string> localize)
        {
            const string Header = "================================";
            const string Delimiter = "----------------------------------------------------------------";
            const string Footer = "---------------------------------------------------- {0,-7} ---";

            yield return Header;
            var msgIdentifier = string.Format("{0}.{1}", msg.topicNo, msg.msgNo);
            var localTime = toLocalTime(msg.time);
            yield return string.Format("{0}.{1}, {2}.{3}, {4}", msg.confName, msg.confVolumeNo, msg.topic, msg.msgNo, msg.author);
            yield return string.Format("({0}) {1:dd/MM/yyyy HH:mm}, {2} chr", msgIdentifier, localTime, msg.text.Length);
            if (msg.HasParent())
            {
                var localOrigTime = msg.origTime.HasValue ? toLocalTime(msg.origTime.Value) : (DateTime?)null;
                yield return string.Format("{0} {1}.{2}, {3}, {4:dd/MM/yyyy HH:mm}",
                    localize("Conf_ReplyTo"), msg.replyToTopicNo, msg.replyToMsgNo, msg.replyToAuthor, localOrigTime);
            }

            yield return Delimiter;

            var textLines = msg.text.Split(["\r\n", "\n"], StringSplitOptions.None);
            int end = textLines.Length;
            while (end > 0 && string.IsNullOrEmpty(textLines[end - 1]))
                end--;
            for (int i = 0; i < end; i++)
                yield return textLines[i];

            yield return string.Format(Footer, msgIdentifier);

            if (msg.HasFile())
                yield return string.Format(localize("Conf_File"), msg.filename);

            yield return "";
        }

        public static IAsyncEnumerable<ConfListDTO> AsListDTO(this IQueryable<ConfMessage> msgs)
        {
            return msgs
                .Select(m => new ConfListDTO()
                {
                    confName = m.Topic.Conference.Name,
                    confVolumeNo = m.Topic.Conference.VolumeNo,
                    topic = m.Topic.Name,
                    topicNo = m.Topic.TopicNo,
                    msgNo = m.MsgNo,
                    author = m.Author.Username,
                    time = m.Time,
                    replyToTopicNo = m.ParentMessage != null ? m.ParentMessage.Topic.TopicNo : (int?)null,
                    replyToMsgNo = m.ParentMessage != null ? m.ParentMessage.MsgNo : (int?)null,
                    filename = m.Filename
                })
                .AsAsyncEnumerable();
        }

        public static IAsyncEnumerable<ConfReadDTO> AsReadDTO(this IQueryable<ConfMessage> msgs)
        {
            return msgs
                .Select(m => new ConfReadDTO()
                {
                    confName = m.Topic.Conference.Name,
                    confVolumeNo = m.Topic.Conference.VolumeNo,
                    topic = m.Topic.Name,
                    topicNo = m.Topic.TopicNo,
                    msgNo = m.MsgNo,
                    author = m.Author.Username,
                    time = m.Time,
                    origTime = m.ParentMessage.Time,
                    replyToTopicNo = m.ParentMessage != null ? m.ParentMessage.Topic.TopicNo : (int?)null,
                    replyToMsgNo = m.ParentMessage != null ? m.ParentMessage.MsgNo : (int?)null,
                    replyToAuthor = m.ParentMessage != null ? m.ParentMessage.Author.Username : "",
                    filename = m.Filename,
                    text = m.MessageText.Text
                })
                .AsAsyncEnumerable();
        }

        public static string FormatConfMsgList(ConfListDTO msg, Func<DateTime, DateTime> toLocalTime)
        {
            var sb = new StringBuilder();
            var localTime = toLocalTime(msg.time);

            string msgId = msg.topic + "." + msg.msgNo;
            sb.Append(string.Format("{0,-20} {1,-16} {2:dd/MM/yyyy HH:mm}",
                msgId, msg.author, localTime));

            if (msg.replyToTopicNo != null)
                sb.Append(string.Format(" -> {0}.{1}", msg.replyToTopicNo, msg.replyToMsgNo));

            return sb.ToString();
        }
    }

    /// <summary>
    /// Gets the topic identifier from string.
    /// </summary>
    /// <returns>The topic identifier from string. Returns zero if all topics. Throws Argument Exception if bad topic number/string provided.</returns>
    /// <param name="conf">Conf.</param>
    /// <param name="topicName">Topic name.</param>
    /// <param name="Required">If set to <c>true</c> required.</param>
    public static class ConfCmdLineParser
    {

        public class ConfTopicMsgRangeDTO
        {
            public ConfTopic topic;
            public int msgLow;
            public int msgHigh;

            /// <summary>
            /// True when a message number / range selector was given on the command line
            /// ('1', '1.2', '1.4-', ...). An explicit selector bypasses the seen filter.
            /// </summary>
            public bool HasMessageSelector => msgLow != 0 || msgHigh != 0;
        }

        public static ConfTopicMsgRangeDTO GetTopicMsgRange(this Data.EF.Conference conf, string topicMsgRange, bool required = false)
        {
            // Regex: ^(.+?)(\.(\d+)(\-(\d+))?)?$
            // Groups: 1 (topic), 3 (lo), 5 (hi)
            var regex = new Regex(@"^(.+?)(\.(\d+)\-?(\-(\d+))?)?$");
            var match = regex.Match(topicMsgRange);
            if (!match.Success)
                return null;
            var result = new ConfTopicMsgRangeDTO();
            if (match.Groups.Count >= 1)
                result.topic = conf.GetTopicFromStr(match.Groups[1].Value, required);
            if (match.Groups.Count >= 3 && int.TryParse(match.Groups[3].Value, out int i))
                result.msgLow = i;
            if (match.Groups.Count >= 5 && int.TryParse(match.Groups[5].Value, out i))
                result.msgHigh = i;

            if (!topicMsgRange.EndsWith("-") && result.msgHigh == 0)
                result.msgHigh = result.msgLow;

            return result;
        }

        public static ConfTopic GetTopicFromStr(this Data.EF.Conference conf, string topicName, bool Required = false)
        {
            // All?
            if (topicName == "*")
                return null;

            // Numeric?
            if (int.TryParse(topicName, out int topicNo))
            {
                // check the number is valid
                if (topicNo > 0)
                {
                    var topic = conf.ConfTopics.Where(t => t.TopicNo == topicNo).FirstOrDefault();
                    if (topic != null)
                        return topic;
                    throw new ArgumentException(string.Format(strings.Conf_UnknownTopic, topicNo));
                }
            }

            if (conf.ConfTopics.Count(t => t.Name.StartsWith(topicName)) == 1)
            {
                var topic = conf.ConfTopics.First(t => t.Name.StartsWith(topicName));
                return topic;
            }

            if (Required)
                throw new ArgumentException(string.Format(strings.Conf_UnknownTopic, topicName));

            return null;
        }
    }
}