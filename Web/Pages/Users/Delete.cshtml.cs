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
    public class DeleteModel : PageModel
    {
        private readonly SezamDbContext _context;

        public DeleteModel(SezamDbContext context)
        {
            _context = context;
        }

        [BindProperty]
        public User DeleteUser { get; set; }

        public async Task<IActionResult> OnGetAsync(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            DeleteUser = await _context.Users.FirstOrDefaultAsync(m => m.Id == id);

            if (DeleteUser == null)
            {
                return NotFound();
            }
            return Page();
        }

        public async Task<IActionResult> OnPostAsync(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            DeleteUser = await _context.Users.FindAsync(id);

            if (DeleteUser != null)
            {
                _context.Users.Remove(DeleteUser);
                // await _context.SaveChangesAsync();
            }

            return RedirectToPage("./Index");
        }
    }
}
