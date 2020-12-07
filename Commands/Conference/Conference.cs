using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Sezam.Library.EF;
using Sezam.Server;

namespace Sezam.Commands
{
    [Command]
    public class Conference : CommandSet
    {
        public Conference(Session session)
           : base(session)
        {
            currentConference = null;
        }

        public ConfStat Status()
        {
            return null;
        }

        public Library.EF.Conference CurrentConference
        { get { return currentConference; } }

        public override string GetPrompt()
        {
            return currentConference != null ?
               string.Format("Conf:{0}", currentConference.VolumeName) : "Conference";
        }

        private IQueryable<Sezam.Library.EF.Conference> GetConferences(bool IncludeResigned = false)
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

        [Command(Aliases = "Show")]
        public void View()
        {
            string confPattern = session.cmdLine.GetToken();
            bool showAll = session.cmdLine.Switch("a");
            var conferences = GetConferences(showAll)
                .Where(c => EF.Functions.Like(c.Name, confPattern + "%"));
            foreach (var g in conferences.DisplayOrder())
                session.terminal.Line("{0,-16} {1,5} {2:MMM yyyy} - {3:MMM yyyy}",
                    g.VolumeName, g.ConfTopics.Sum(t => t.NextSequence), g.FromDate, g.ToDate);
        }

        private void Unresign()
        {
            // Unresign
            var userConfData = session.User.GetUserConfInfo(currentConference);
            if (userConfData.Status.HasFlag(UserConf.UserConfStat.Resigned))
            {
                userConfData.Status &= ~UserConf.UserConfStat.Resigned;
                // Show welcome?
                session.terminal.Line("Welcome to conf {0}", currentConference.Name);
                session.Db.SaveChanges();
                Debug.WriteLine(string.Format("Joined conf {0}", currentConference.Name));
            }
        }

        [Command(Aliases = "Open")]
        public void Join()
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
                Unresign();
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
                    session.terminal.Line("Unknown conference {0}", confName);
            }
        }

        [Command]
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
        ///
        /// </summary>
        /// <returns></returns>
        private IQueryable<ConfMessage> GetConfMsgSelection()
        {
            MustHaveConf();

            // Filter Files only
            bool filesOnly = session.cmdLine.Switch("f");

            // Replies to my messages only
            bool myRepliesOnly = session.cmdLine.Switch("r");


            // Filter TO (topic)
            string topicMsgs = session.cmdLine.GetToken(1);
            var topicMsgRange = currentConference.GetTopicMsgRange(topicMsgs, true);

            IQueryable<ConfMessage> messages = session.Db.ConfMessages;

            // Topic Selection
            if (topicMsgRange?.topic != null)
            {
                messages = messages.Where(m => m.TopicId == topicMsgRange.topic.Id);
            }
            else
            {
                messages = messages
                    .Include(m => m.Topic)
                    .Where(m => m.Topic.ConferenceId == currentConference.Id
                        && !string.IsNullOrEmpty(m.Topic.Name)
                        //&& !m.Topic.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                        //&& !m.Topic.Status.HasFlag(ConfTopic.TopicStatus.Private)
                     );
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
            string fromStr = session.cmdLine.GetToken(2);
            Library.EF.User fromUser = null;
            if (!string.IsNullOrWhiteSpace(fromStr) && fromStr != "*")
            {
                if (fromStr == "$")
                    fromUser = session.User;
                else
                {
                    fromUser = session.GetUser(fromStr);
                    if (fromUser == null)
                        throw new ArgumentException("Unknown User", fromStr);
                }
            }
            if (fromUser != null)
                messages = messages.Where(m => m.AuthorId == fromUser.Id); // && !m.Status.HasFlag(ConfMessage.MessageStatus.Anonymous));

            //if (fromUser != null)
            //    messages = messages.Where(m => !m.Status.HasFlag(ConfMessage.MessageStatus.Anonymous));

            if (filesOnly)
                messages = messages.Where(m => !string.IsNullOrEmpty(m.Filename));

            if (myRepliesOnly)
                messages = messages.Where(m => m.ParentMessage.AuthorId == session.User.Id);

            return messages
                .Include(m => m.Author)
                .Where(m => !m.Status.HasFlag(ConfMessage.MessageStatus.Deleted))
                .OrderBy(m => m.TopicId)
                .ThenBy(m => m.MsgNo)
            ;

        }

        private void ConfDir(Library.EF.Conference conf)
        {
            var selTopics = conf.ConfTopics;
            foreach (var topic in selTopics.OrderBy(t => t.TopicNo))
                session.terminal.Line(ConfFormatter.FormatTopic(topic));
        }

        [Command]
        public void Directory()
        {
            if (currentConference != null)
                ConfDir(currentConference);
            else
            {
                var activeConferences = GetConferences()
                    .Include(c => c.ConfTopics)
                    .DisplayOrder();
                foreach (var conf in activeConferences)
                {
                    session.terminal.Line("Conference {0}", conf.VolumeName);
                    ConfDir(conf);
                    session.terminal.Line();
                }
            }
        }

        [Command]
        public void List()
        {
            var selection = GetConfMsgSelection().AsListDTO();
            foreach (var confListItem in selection)
                session.terminal.Line(ConfFormatter.FormatConfMsgList(confListItem));
        }

        [Command]
        public void Read()
        {
            var selection = GetConfMsgSelection().AsReadDTO();
            foreach (var msg in selection)
            {
                ConfFormatter.ConfMsgRead(session.terminal, msg);
            }
        }

        [Command]
        public void Topic()
        {
            // Needs to parse a further topic command (from a class?)
            throw new NotImplementedException();
        }

        [Command("RESign")]
        public void RESign()
        {
            MustHaveConf();

            string topicStr = session.cmdLine.GetToken(1);
            var topic = currentConference.GetTopicFromStr(topicStr, false);

            if (topic != null)
            {
                // Resign Topic
                var utData = session.User.GetUserTopicfInfo(topic);
                utData.Status |= UserTopic.UserTopicStat.Resigned;
                session.terminal.Line("Resigned from topic {0}", topic.Name);
            }
            else
            {
                // Resign Conference
                var ucData = session.User.GetUserConfInfo(currentConference);
                ucData.Status |= UserConf.UserConfStat.Resigned;
                session.terminal.Line("Resigned from conference {0}", currentConference.VolumeName);
                currentConference = null;
            }

            session.Db.SaveChanges();

        }

        public void SEEn()
        {
            throw new NotImplementedException();
        }

        public Library.EF.Conference currentConference;
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

        public static void ConfMsgRead(ITerminal terminal, ConfReadDTO msg)
        {
            const string Header = "================================";
            const string Delimiter = "----------------------------------------------------------------";
            const string Footer = "---------------------------------------------------- {0,-7} ---";

            terminal.Line(Header);
            var msgIdentifier = string.Format("{0}.{1}", msg.topicNo, msg.msgNo);
            terminal.Line(string.Format("{0}.{1}, {2}.{3}, {4}", msg.confName, msg.confVolumeNo, msg.topic, msg.msgNo, msg.author));
            terminal.Line(string.Format("({0}) {1:dd/MM/yyyy HH:mm}, {2} chr", msgIdentifier, msg.time, msg.text.Length));
            if (msg.HasParent())
                terminal.Line(string.Format("Odgovor na {0}.{1}, {2}, {3}", msg.replyToTopicNo, msg.replyToMsgNo, msg.replyToAuthor, msg.origTime));

            terminal.Line(Delimiter);
            terminal.Text(msg.text);
            terminal.Line(string.Format(Footer, msgIdentifier));

            if (msg.HasFile())
                terminal.Line(string.Format("** Datoteka {0}", msg.filename));

            terminal.Line();
        }

        public static IEnumerable<ConfListDTO> AsListDTO(this IQueryable<ConfMessage> msgs)
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
                    //replyToTopicNo = m.ParentMessage != null ? m.ParentMessage.Topic.TopicNo : (int?)null,
                    //replyToMsgNo = m.ParentMessage != null ? m.ParentMessage.MsgNo : (int?)null,
                    filename = m.Filename
                })
            ;
        }

        public static IEnumerable<ConfReadDTO> AsReadDTO(this IQueryable<ConfMessage> msgs)
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
                    //origTime = m.ParentMessage.Time,
                    //replyToAuthor = m.ParentMessage.Author.Username,
                    //replyToTopicNo = m.ParentMessage.Topic.TopicNo,
                    //replyToMsgNo = m.ParentMessage.MsgNo,
                    filename = m.Filename,
                    text = m.MessageText.Text
                })
            ;
        }

        public static string FormatConfMsgList(ConfListDTO msg)
        {
            var sb = new StringBuilder();

            string msgId = msg.topic + "." + msg.msgNo;
            sb.Append(string.Format("{0,-20} {1,-16} {2:dd/MM/yyyy HH:mm}",
                msgId, msg.author, msg.time));

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

        public static ConfTopicMsgRangeDTO GetTopicMsgRange(this Library.EF.Conference conf, string topicMsgRange, bool required = false)
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
            int i;
            if (match.Groups.Count >= 3 && int.TryParse(match.Groups[3].Value, out i))
                result.msgLow = i;
            if (match.Groups.Count >= 5 && int.TryParse(match.Groups[5].Value, out i))
                result.msgHigh = i;

            if (!topicMsgRange.EndsWith("-") && result.msgHigh == 0)
                result.msgHigh = result.msgLow;
                
            return result;
        }

        public static ConfTopic GetTopicFromStr(this Library.EF.Conference conf, string topicName, bool Required = false)
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