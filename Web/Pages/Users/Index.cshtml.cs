using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using Sezam.Data;
using Sezam.Data.EF;

namespace Sezam.Web.Pages.Users
{
    public class IndexModel : PageModel
    {
        private readonly Sezam.Data.SezamDbContext _context;

        public IndexModel(Sezam.Data.SezamDbContext context)
        {
            _context = context;
        }

        [BindProperty(SupportsGet = true)]
        public string q { get; set; }

        public IList<User> User { get;set; }

        public async Task OnGetAsync()
        {
                User = await _context.Users
                    .Where(u => u.Username.Contains(q) || u.City.Contains(q))
                    .OrderByDescending(u => u.LastCall)
                    .Take(10)
                    .ToListAsync();
        }
    }
}
