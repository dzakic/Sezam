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
    public class DetailsModel : PageModel
    {
        private readonly SezamDbContext _context;

        public DetailsModel(SezamDbContext context)
        {
            _context = context;
        }

        public User ViewUser { get; set; }

        public async Task<IActionResult> OnGetAsync(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            ViewUser = await _context.Users.FirstOrDefaultAsync(m => m.Id == id);

            if (ViewUser == null)
            {
                return NotFound();
            }
            return Page();
        }
    }
}
