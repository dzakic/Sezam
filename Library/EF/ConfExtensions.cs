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

        public static IQueryable<ConfTopic> ActiveFor(this IQueryable<ConfTopic> topics, User u)
        {
            return topics
                .Where(t => !string.IsNullOrEmpty(t.Name)
                    && !t.Status.HasFlag(ConfTopic.TopicStatus.Deleted)
                    && !t.Status.HasFlag(ConfTopic.TopicStatus.Private)
                // or allowed and not denied
                );
        }

        public static IQueryable<Conference> DisplayOrder(this IQueryable<Conference> conferences)
        {
            return conferences
                .OrderBy(c => c.Name)
                .ThenBy(c => c.VolumeNo);
        }

    }
}