namespace Sezam.Commands
{

   using System;
   using System.Collections.Generic;
   using System.Diagnostics;
   using System.Linq;

   [Command]
   public class Conference : CommandProcessor
   {
      public Conference(Session session)
         : base(session)
      {
         currentConference = null;
      }

      public override string GetPrompt()
      {
         return currentConference != null ?
            string.Format("Conf:{0}", currentConference.Name) : "Conference";
      }

      [Command(Aliases = "Show")]
      public void View()
      {
         lock (session.dataStore.confManager.conferences)
         {
            IEnumerable<ZBB.ConferenceVolume> selection = session.dataStore.confManager.conferences.Where(c => c.Messages.Count() > 0);
            string confPattern = session.cmdLine.getParam();
            if (!string.IsNullOrWhiteSpace(confPattern))
               selection = selection.Where(c => c.Name.IndexOf(confPattern, StringComparison.OrdinalIgnoreCase) >= 0);

            foreach (var conf in selection)
            {
               session.terminal.Line("{0,-16} {1,5} {2:MMM yyyy} - {3:MMM yyyy}",
                  conf.Name, conf.GetMessageCount(),
                  conf.GetOldestMessage().Time, conf.GetNewestMessage().Time);
            }
         }
      }

      [Command(Aliases = "Open")]
      public void Join()
      {
         string confName = session.cmdLine.getParam();
         IEnumerable<ZBB.ConferenceVolume> selection = session.dataStore.confManager.conferences;
         if (selection.Count(c => c.Name.StartsWith(confName, true, System.Globalization.CultureInfo.CurrentCulture)) > 0)
         {
            currentConference = selection.First(c => c.Name.StartsWith(confName, true, System.Globalization.CultureInfo.CurrentCulture));
            Debug.WriteLine(string.Format("Joined conf {0}", currentConference.Name));
         }
      }

      [Command]
      public void Close()
      {
         currentConference = null;  
      }

      private IEnumerable<ZBB.ConfMessage> getConfMsgSelection()
      {

         IEnumerable<ZBB.ConfMessage> msgs;
         if (currentConference == null)
            msgs = session.dataStore.confManager.conferences.SelectMany(c => c.Messages.Where(m => !m.isDeleted()));
         else
            msgs = currentConference.Messages.Where(m => !m.isDeleted());         


         // Filter TO (topic)
         string to = session.cmdLine.getParam(1);
         if (!string.IsNullOrWhiteSpace(to))
         {
            int topicNo = currentConference.GetTopicIdFromStr(to, true);
            if (topicNo != 0)
               msgs = msgs.Where(m => m.TopicNo == topicNo);
         }

         string thisUser = session.getUsername();

         // Filter FROM (user)
         string from = session.cmdLine.getParam(2);
         if (!string.IsNullOrWhiteSpace(from))
         {
            if (from == "$")
               from = thisUser;

            if (from != "*")
               msgs = msgs.Where(m => m.author == from);
         }

         // Filter Files only
         bool filesOnly = session.cmdLine.Switch("f");
         if (filesOnly)
         {
            msgs = msgs.Where(m => (m.status & ZBB.ConfMessage.MsgStatus.FileAttached) != 0);
         }
            
         // Replies to my messages only
         bool myRepliesOnly = session.cmdLine.Switch("r");
         if (myRepliesOnly)
         {
            msgs = msgs.Where(m => (m.ParentMsg.author == thisUser));
         }

         return msgs;
      }

      private void confDir(ZBB.ConferenceVolume conf)
      {
         var selTopics = conf.Topics.Where(t => !string.IsNullOrWhiteSpace(t.Name) && !t.isDeleted());
         foreach (var topic in selTopics)
            session.terminal.Line(topic.ToString());
      }


      [Command(Aliases = "Topics")]
      public void Directory()
      {
         if (currentConference != null)
            confDir(currentConference);
         else
            session.dataStore.confManager.conferences.ForEach(c => confDir(c));
      }

      [Command]
      public void List()
      {
         var selection = getConfMsgSelection();
         foreach (ZBB.ConfMessage msg in selection)
            session.terminal.Line(msg.ToString());
      }

      [Command]
      public void Read()
      {
         var selection = getConfMsgSelection();
         using (var msgReader = currentConference.MessageReader())
         {
            foreach (var msg in selection)
               session.terminal.Text(msg.ReadStr(msgReader));
         }
      }

      public ZBB.ConferenceVolume currentConference;
   }


   public static class ConfHelper
   {
      /// <summary>
      /// Gets the topic identifier from string.
      /// </summary>
      /// <returns>The topic identifier from string. Returns zero if all topics. Throws Argument Exception if bad topic number/string provided.</returns>
      /// <param name="conf">Conf.</param>
      /// <param name="topicName">Topic name.</param>
      /// <param name="Required">If set to <c>true</c> required.</param>
      public static int GetTopicIdFromStr(this ZBB.ConferenceVolume conf, string topicName, bool Required = false)
      {
         // All?
         if (topicName == "*")
            return 0;

         // Numeric?
         int topicNo;
         if (int.TryParse(topicName, out topicNo))
         {
            // check the number is valid
            if (topicNo > 0 && topicNo <= conf.Topics.Count())
               return topicNo;
            throw new ArgumentException(string.Format(strings.Conf_UnknownTopic, topicNo));
         }

         if (conf.Topics.Count(t => t.Name.StartsWith(topicName)) == 1)
         {
            var topic = conf.Topics.First(t => t.Name.StartsWith(topicName, true, System.Globalization.CultureInfo.CurrentCulture));
            return topic.TopicNo;
         }

         if (Required)
            throw new ArgumentException(strings.Conf_UnknownTopic, topicName);

         return 0;
      }
   }


}