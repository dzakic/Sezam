using Microsoft.EntityFrameworkCore;
using Sezam.Data.EF;
using System;
using System.Collections.Generic;
using System.Diagnostics;
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

        public static ConfStat Status()
        {
            return null;
        }

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
                        !c.UserConf.Status.HasFlag(UserConf.UserConfStat.Admin) ||
                        (!c.Status.HasFlag(ConfStatus.Private) || c.UserConf.Status.HasFlag(UserConf.UserConfStat.Allowed)) &&
                        !c.Status.HasFlag(ConfStatus.Closed) &&
                        !c.UserConf.Status.HasFlag(UserConf.UserConfStat.Denied));

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
        public async Task View()
        {
            string confPattern = session.cmdLine.GetToken();
            bool showAll = session.cmdLine.Switch("a");
            var conferences = GetConferences(showAll)
                .Where(c => EF.Functions.Like(c.Name, confPattern + "%"));
            foreach (var g in conferences.DisplayOrder())
            {
                await session.terminal.Line("{0,-16} {1,5} {2:MMM yyyy} - {3:MMM yyyy}",
                    g.VolumeName, g.ConfTopics.Sum(t => t.NextSequence), g.FromDate, g.ToDate);
            }
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
                session.Db.SaveChanges();
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

            // Filter TO (topic)
            string topicMsgs = session.cmdLine.GetToken();
            var topicMsgRange = currentConference.GetTopicMsgRange(topicMsgs, true);

            IQueryable<ConfMessage> messages = session.Db.ConfMessages;

            messages = messages
                .Include(m => m.Topic)
                    .ThenInclude(t => t.UserTopic)
                .Include(m => m.ParentMessage)
                .Include(m => m.Author);

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

            // Filter by SeenTime - only new messages (unless /a switch)
            if (!selectAll)
            {
                messages = messages
                    .Where(m => m.Topic.UserTopic == null || m.Time > m.Topic.UserTopic.SeenTime);
            }

            // Message number range
            if (topicMsgRange != null)
            {
                // Selection by MsgNo
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
                .OrderBy(m => m.TopicId)
                .ThenBy(m => m.MsgNo);
        }

        private void ConfDir(Data.EF.Conference conf)
        {
            var selTopics = session.Db.ConfTopics
                .Include(t => t.UserTopic)
                .Where(t => t.ConferenceId == conf.Id)
                .Where(t => t.UserTopic == null || !t.UserTopic.Status.HasFlag(UserTopic.UserTopicStat.Resigned))
                .OrderBy(t => t.TopicNo);

            foreach (var topic in selTopics)
                session.terminal.Line(ConfFormatter.FormatTopic(topic));
        }

        [Command(Description = "Show a list of topics in the current conference, or all in all conferences if none open")]
        public async Task Directory()
        {
            if (currentConference != null)
                ConfDir(currentConference);
            else
            {
                var activeConferences = GetConferences()
                    .DisplayOrder()
                    .ToList();  // Materialize to avoid open DataReader conflict with ConfDir()
                foreach (var conf in activeConferences)
                {
                    await session.terminal.Line("Conference {0}", conf.VolumeName);
                    ConfDir(conf);
                    await session.terminal.Line();
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
        public async Task List()
        {
            var query = (await GetConfMsgSelection())
                .AsListDTO();
            await foreach (var confListItem in query)
                await session.terminal.Line(ConfFormatter.FormatConfMsgList(confListItem, session.User.ToLocalTime));
//            await ProcessMessages(query, async msg => 
                //await session.terminal.Line(ConfFormatter.FormatConfMsgList(msg, session.User.ToLocalTime)));
        }

        [Command(Description = "Read new messages in the conference or a topic")]
        [CommandParameter("topic[.msgLow[-msgHigh]]", "Topic and optional message number or range to list, e.g. 'General', 'General.5' or 'General.5-10'. Use '*' for all topics, e.g. '*.5' or '*.5-10'.")]
        [CommandParameter("from", "Only select messages from this author, specify the username.")]
        [CommandSwitch('f', "Select only messages with files")]
        [CommandSwitch('a', "Select all messages, including old")]
        public async Task Read()
        {
            var query = (await GetConfMsgSelection())
                .Include(m => m.MessageText)
                .AsReadDTO();
            await foreach (var msg in query)
                await ConfFormatter.ConfMsgRead(session.terminal, msg, session.User.ToLocalTime);
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
        [CommandParameter("datetime", "Optional datetime to set as seen time (UTC). Defaults to now. Format: yyyy-MM-dd or dd/MM/yyyy with optional HH:mm")]
        public async Task SEEn()
        {
            bool allConferences = session.cmdLine.Switch("a");

            if (!allConferences)
                MustHaveConf();

            // Get datetime from command line, default to UTC now
            var seenTime = session.cmdLine.GetDateTime() ?? DateTime.UtcNow;

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
                await session.terminal.Line(L("Conf_SeenAll"));
            else
                await session.terminal.Line(L("Conf_Seen"), currentConference.VolumeName);
        }

        public Sezam.Data.EF.Conference currentConference;
    }

    public static class ConfFormatter
    {
        public static string FormatTopic(ConfTopic topic)
        {
            var sb = new StringBuilder();
            var typ = topic.Status.GetType();
            var values = Enum.GetValues(typ).Cast<ConfTopic.TopicStatus>()
                .Where(v => topic.Status.HasFlag(v));

            var valStrs = new List<string>();
            foreach (var value in values)
                valStrs.Add(Enum.GetName(typ, value));

            sb.AppendFormat("{0,2}. {1,-16} {2,5}",
               topic.TopicNo, topic.Name, topic.NextSequence);
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

        public static async Task ConfMsgRead(ITerminal terminal, ConfReadDTO msg, Func<DateTime, DateTime> toLocalTime)
        {
            const string Header = "================================";
            const string Delimiter = "----------------------------------------------------------------";
            const string Footer = "---------------------------------------------------- {0,-7} ---";

            await terminal.Line(Header);
            var msgIdentifier = string.Format("{0}.{1}", msg.topicNo, msg.msgNo);
            var localTime = toLocalTime(msg.time);
            await terminal.Line(string.Format("{0}.{1}, {2}.{3}, {4}", msg.confName, msg.confVolumeNo, msg.topic, msg.msgNo, msg.author));
            await terminal.Line(string.Format("({0}) {1:dd/MM/yyyy HH:mm}, {2} chr", msgIdentifier, localTime, msg.text.Length));
            if (msg.HasParent())
            {
                var localOrigTime = msg.origTime.HasValue ? toLocalTime(msg.origTime.Value) : (DateTime?)null;
                await terminal.Line(string.Format("Odgovor na {0}.{1}, {2}, {3:dd/MM/yyyy HH:mm}", msg.replyToTopicNo, msg.replyToMsgNo, msg.replyToAuthor, localOrigTime));
            }

            await terminal.Line(Delimiter);
            await terminal.Text(msg.text);
            await terminal.Line(string.Format(Footer, msgIdentifier));

            if (msg.HasFile())
                await terminal.Line(string.Format("** Datoteka {0}", msg.filename));

            await terminal.Line();
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