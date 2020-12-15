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
        private readonly SezamDbContext _context;

        public IndexModel(SezamDbContext context)
        {
            _context = context;
        }

        [BindProperty(SupportsGet = true)]
        public string q { get; set; }

        public IList<User> Users { get;set; }

        public async Task OnGetAsync()
        {
                Users = await _context.Users
                    .Where(u => u.Username.Contains(q) || u.City.Contains(q))
                    .OrderByDescending(u => u.LastCall)
                    .Take(10)
                    .ToListAsync();
        }
    }
}
