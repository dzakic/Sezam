using System.Collections.Generic;
using System.Linq;

namespace Sezam.Library.EF
{
    public static class ConfExtensions
    {
        public static IQueryable<ConfTopic> VisibleTo(this IQueryable<ConfTopic> topics, User u)
        {
            return topics
                .Where(t => !t.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                // && (!t.isPrivate() or allowed) and not denied
                );
        }

        public static IEnumerable<ConfTopic> VisibleTo(this IEnumerable<ConfTopic> topics, User u)
        {
            return topics
                .Where(t => !t.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                    && !t.Status.HasFlag(ConfTopic.TopicStatus.Private)
                // or allowed and not denied
                );
        }

        public static IEnumerable<ConfTopic> ActiveFor(this IEnumerable<ConfTopic> topics, User u)
        {
            return topics
                .Where(t => !string.IsNullOrEmpty(t.Name)
                    && !t.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                    && !t.Status.HasFlag(ConfTopic.TopicStatus.Private)
                // or allowed and not denied
                );
        }


        public static IQueryable<Conference> VisibleTo(this IQueryable<Conference> conferences, User u)
        {
            var deniedConfIds = u.UserConfs.AsQueryable()
                .Where(uc => uc.Status.HasFlag(UserConf.UserConfStat.Denied))
                .Select(uc => uc.ConferenceId);

            return
                from c in conferences
                where !string.IsNullOrEmpty(c.Name)
                    && !deniedConfIds.Contains(c.Id)
                    && !c.Status.HasFlag(ConfStatus.Private)
                    && !c.Status.HasFlag(ConfStatus.Closed)
                select c;
        }

        public static IQueryable<Conference> ActiveFor(this IQueryable<Conference> conferences, User u)
        {
            var resignedConfIds = u.UserConfs.AsQueryable()
                .Where(uc => uc.Status.HasFlag(UserConf.UserConfStat.Resigned))
                .Select(uc => uc.ConferenceId);

            return
                from c in conferences
                where !resignedConfIds.Contains(c.Id)
                    && !c.Status.HasFlag(ConfStatus.Closed)
                orderby c.Name, c.VolumeNo
                select c;
        }

        /// <summary>
        /// TODO
        /// </summary>
        /// <param name="conferences"></param>
        /// <param name="u"></param>
        /// <returns></returns>
        public static IEnumerable<Conference> Current(this IQueryable<Conference> conferences, User u)
        {
            // todo if currentConf then return currentConf, else all Active
            return conferences.ActiveFor(u);
        }
    }
}