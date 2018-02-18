using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace Sezam.Library.EF
{
    [Flags]
    public enum ConfStatus
    {
        Private = 1,
        AnonymousAllowed = 2,
        ReadOnly = 4,
        Closed = 8
    }

    public class Conference
    {
        public Conference()
        {
            Topics = new HashSet<Sezam.Library.EF.ConfTopic>();
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; private set; }

        [Index("ixName", 1, IsUnique = true)]
        [StringLength(15)]
        public string Name { get; set; }

        [Index("ixName", 2, IsUnique = true)]
        public int VolumeNo { get; set; }

        public ConfStatus Status { get; set; }

        public virtual DateTime? FromDate { get; set; }

        public virtual DateTime? ToDate { get; set; }

        public virtual ICollection<ConfTopic> Topics { get; set; }

        public virtual ICollection<UserConf> UserConfs { get; set; }

        public UserConf getUserConf(int userId)
        {
            return UserConfs.Where(u => u.UserId == userId).FirstOrDefault();
        }

        public string VolumeName { get { return VolumeNo > 0 ? string.Format("{0}.{1}", Name, VolumeNo) : Name; } }

        public bool isClosed()
        {
            return Status.HasFlag(ConfStatus.Closed);
        }

        public bool isPrivate()
        {
            return Status.HasFlag(ConfStatus.Private);
        }

        public bool isReadOnly()
        {
            return Status.HasFlag(ConfStatus.ReadOnly);
        }

    }

    public class ConferenceComparer : IEqualityComparer<Conference>
    {
        public bool Equals(Conference x, Conference y)
        {
            return x.Name.Equals(y.Name);
        }

        public int GetHashCode(Conference obj)
        {
            return obj.Name.GetHashCode();
        }
    }
}