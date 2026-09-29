using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Sezam.Data;
using Sezam.Web.Api.DTO;

namespace Sezam.Web.Api
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        public StatusController(SezamDbContext context, ILogger<StatusController> logger)
        {
            _context = context;
            _logger = logger;
        }

        private readonly SezamDbContext _context;
        private readonly ILogger<StatusController> _logger;

        // GET: api/status
        [HttpGet]
        [AllowAnonymous]
        public async Task<ActionResult<StatusInfo>> Get()
        {
            var result = new StatusInfo();

            DatabaseStatus db = new DatabaseStatus();
            try
            {
                db.Connected = await _context.Database.CanConnectAsync();
            }
            catch (Exception ex)
            {
                db.Connected = false;
                db.Error = ex.Message;
                _logger.LogWarning(ex, "Status check: database not reachable");
            }

            if (!db.Connected)
            {
                result.Status = "DOWN";
                result.Database = db;
                return StatusCode(StatusCodes.Status503ServiceUnavailable, result);
            }

            result.Database = db;

            try
            {
                result.LastLogin = await _context.Users
                    .OrderByDescending(u => u.LastCall)
                    .Select(u => u.LastCall)
                    .FirstOrDefaultAsync();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Status check: unable to read last login");
                result.Status = "DEGRADED";
            }

            return result.Status == "OK"
                ? Ok(result)
                : StatusCode(StatusCodes.Status503ServiceUnavailable, result);
        }
    }
}
