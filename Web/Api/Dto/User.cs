using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Sezam.Web.Api.DTO
{
    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; }
        public string FullName { get; set; }
        public string City { get; set; }

        public DateTime? LastCall { get; set; }


    }
}
