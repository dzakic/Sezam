using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
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
    public class ConfModel : PageModel
    {
        private readonly Sezam.Data.SezamDbContext _context;
        private readonly ILogger<PrivacyModel> _logger;

        [BindProperty(SupportsGet = true)]
        public string ConfName { get; set; }

        [BindProperty(SupportsGet = true)]
        public string TopicName { get; set; }

        public ConfModel(Sezam.Data.SezamDbContext context, ILogger<PrivacyModel> logger)
        {
            _logger = logger;
            _context = context;
        }

        public Sezam.Data.EF.Conference Conference;

        public async Task OnGetAsync()
        {
            string NameOnly;
            int VolumeNumber;
            var regex = new Regex(@"([A-Z]+)\.?(\d*)");
            var match = regex.Match(ConfName);
            if (match.Success && match.Groups.Count > 2)
            {
                NameOnly = match.Groups[1].Value;
                if (int.TryParse(match.Groups[2].Value, out int volNo))
                    VolumeNumber = volNo;
                else
                    VolumeNumber = 0;
            }
            else
            {
                NameOnly = ConfName;
                VolumeNumber = 0;
            }
            this.ConfName = ConfName;

            Conference = await _context.Conferences
                .Include(c => c.ConfTopics)
                .Where(c => c.Name == NameOnly && c.VolumeNo == VolumeNumber && !c.Status.HasFlag(ConfStatus.Private))
                .OrderBy(c => c.Name)
                .ThenBy(c => c.VolumeNo)
                .FirstOrDefaultAsync();

            _logger.LogInformation("Got conference" + Conference + " ConfName=" + ConfName + ", TopicName=" + TopicName);
        }
    }
}
