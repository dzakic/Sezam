using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc.Rendering;
using Sezam.Data;
using Sezam.Data.EF;

namespace Sezam.Web.Pages.Users
{
    public class CreateModel : PageModel
    {
        private readonly SezamDbContext _context;

        public CreateModel(SezamDbContext context)
        {
            _context = context;
        }

        public IActionResult OnGet()
        {
            return Page();
        }

        [BindProperty]
        public User CreateUser { get; set; }

        // To protect from overposting attacks, see https://aka.ms/RazorPagesCRUD
        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
            {
                return Page();
            }

            _context.Users.Add(CreateUser);
            await _context.SaveChangesAsync();

            return RedirectToPage("./Index");
        }
    }
}
