using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using Microsoft.EntityFrameworkCore;

namespace Sezam.Data.CB
{
    public class User
    {
        public User()
        { }

        public User(int Id)
        {
            this.Id = Id;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; private set; }

        [StringLength(15)]
        [MinLength(2)]
        public string Username { get; set; }

        [StringLength(32)]
        public string FullName { get; set; }

        [StringLength(36)]
        public string StreetAddress { get; set; }

        [StringLength(6)]
        public string PostCode { get; set; }

        [StringLength(16)]
        public string City { get; set; }

        [StringLength(6)]
        public string AreaCode { get; set; }

        [StringLength(15)]
        public string Phone { get; set; }

        [StringLength(15)]
        public string Company { get; set; }

        public DateTime? DateOfBirth { get; set; }

        // MemberSince should not be nullable, but we do load empty users during import
        public DateTime? MemberSince { get; set; }

        public DateTime? LastCall { get; set; }

        public DateTime? PaidUntil { get; set; }

        public string Password { get; set; }

    }

    public class UserComparer : IEqualityComparer<User>
    {
        #region IEqualityComparer<Contact> Members

        public bool Equals(User x, User y)
        {
            return x.Username.Equals(y.Username);
        }

        public int GetHashCode(User obj)
        {
            return obj.Username.GetHashCode();
        }

        #endregion IEqualityComparer<Contact> Members
    }
}