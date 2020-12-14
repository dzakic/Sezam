using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Sezam.Data;
using Sezam.Data.EF;

namespace Sezam.Web.Pages.Conference
{
    public class IndexModel : PageModel
    {
        private readonly SezamDbContext _context;
        private readonly ILogger<PrivacyModel> _logger;

        public class ConfSet
        {
            public string Name;
            public readonly ICollection<Data.EF.Conference> Conferences = new List<Data.EF.Conference>();
        }

        public IList<ConfSet> ConfSets;

        [Parameter]
        public string ConfName { get; set; }

        public IndexModel(SezamDbContext context, ILogger<PrivacyModel> logger)
        {
            _logger = logger;
            _context = context;
        }

        // Group Conference Volumes into Sets for more eye-pleasing view
        public IList<ConfSet> GetConfSets(IEnumerable<Sezam.Data.EF.Conference> conferences)
        {
            var confSets = new List<ConfSet>();

            string prevConf = string.Empty;
            ConfSet currentSet = null;
            foreach (var conf in conferences)
            {
                if (conf.Name != prevConf)
                {
                    if (currentSet != null)
                        confSets.Add(currentSet);
                    currentSet = new ConfSet()
                    {
                        Name = conf.Name
                    };
                }
                currentSet.Conferences.Add(conf);
                prevConf = conf.Name;
            }
            if (currentSet != null)
                confSets.Add(currentSet);

            return confSets;
        }

        public async Task OnGetAsync()
        {
            var conferences = await _context.Conferences
                .Where(c => c.FromDate.HasValue && !c.Status.HasFlag(ConfStatus.Private))
                .OrderBy(c => c.Name)
                .ThenBy(c => c.VolumeNo)
                .ToListAsync();

            ConfSets = GetConfSets(conferences);
            _logger.LogInformation("Got {0} conference sets", ConfSets.Count);
        }
    }
}
