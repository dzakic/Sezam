using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Sezam.Library.EF
{
    public class User
    {

        public User(int Id)
        {
            this.Id = Id;
        }

        public int Id { get; internal set; }

        public string username;
        public string FullName;
        public string StreetAddress;
        public string PostCode;
        public string City;
        public string AreaCode;
        public string Phone;
        public string Company;
        public DateTime DateOfBirth;
        public DateTime MemberSince;
        public DateTime LastCall;
        public DateTime PaidUntil;

    }

}
