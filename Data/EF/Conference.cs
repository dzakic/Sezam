using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.EF
{
    [Flags]
    public enum ConfStatus
    {
        Private = 1,
        AnonymousAllowed = 2,
        ReadOnly = 4,
        Closed = 8
    }

    [Index("Name", "VolumeNo", IsUnique = true)]
    public class Conference
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; private set; }

        [StringLength(15)]
        public string Name { get; set; }

        public int VolumeNo { get; set; }

        public ConfStatus Status { get; set; }

        public virtual DateTime? FromDate { get; set; }

        public virtual DateTime? ToDate { get; set; }

        // TODO public virtual MessageText WelcomeText { get; set; }

        public virtual UserConf UserConf { get; set; }

        public virtual ICollection<ConfTopic> ConfTopics { get; set; } = new List<ConfTopic>();

        // Name [ + VolumeNo ] = VolumeName
        public string VolumeName => VolumeNo > 0 ? string.Format("{0}.{1}", Name, VolumeNo) : Name;

        public bool IsClosed => Status.HasFlag(ConfStatus.Closed);

        public bool IsPrivate => Status.HasFlag(ConfStatus.Private);

        public bool IsReadOnly => Status.HasFlag(ConfStatus.ReadOnly);

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