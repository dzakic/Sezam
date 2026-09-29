using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace Sezam.Web.Pages
{
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    [IgnoreAntiforgeryToken]
    public class ErrorModel : PageModel
    {
        public string RequestId { get; set; } = null!;

        public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);

        /// <summary>
        /// Original request path, captured from the exception middleware so the
        /// error page can offer a "retry" link back to where the user was.
        /// </summary>
        public string? OriginalPath { get; set; }

        private readonly ILogger<ErrorModel> _logger;

        public ErrorModel(ILogger<ErrorModel> logger)
        {
            _logger = logger;
        }

        public void OnGet()
        {
            RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier;
            OriginalPath = HttpContext.Features.Get<IExceptionHandlerPathFeature>()?.Path;
        }
    }
}
