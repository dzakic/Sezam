using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Linq.Expressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Sezam.Data;

namespace Sezam.Web.Api
{
    [Route("api/[controller]")]
    [ApiController]
    public class ConfController : ControllerBase
    {

        public ConfController(Sezam.Data.SezamDbContext context, ILogger<ConfController> logger)
        {
            _context = context;
            _logger = logger;
        }

        private readonly SezamDbContext _context;
        private readonly ILogger<ConfController> _logger;

        private static readonly Expression<Func<Data.EF.Conference, DTO.Conf>>
          AsConfDto = conf => new DTO.Conf
          {
              Id = conf.Id,
              Name = conf.VolumeName
          };

        // GET: api/conf
        [HttpGet]
        public IEnumerable<DTO.Conf> Search(string filter = "")
        {
            IQueryable<Data.EF.Conference> confs = _context.Conferences;
            if (!string.IsNullOrEmpty(filter))
                confs = confs.Where(c => 
                    c.Name.Contains(filter)
                );
            return confs
                .OrderBy(c => c.Name)                
                .ThenBy(c => c.VolumeNo)
                .Take(100)
                .Select(AsConfDto); ;
        }

        // GET api/conf/5
        [HttpGet("{id:int}")]
        public async Task<ActionResult<DTO.Conf>> GetById(int id)
        {
            var conf = await _context.Conferences
                .Select(AsConfDto)
                .SingleOrDefaultAsync(c => c.Id == id);
            return conf == null ? NotFound() : conf;
        }

        // GET api/conf/SEZAMNET
        [HttpGet("{name:alpha}")]
        public async Task<ActionResult<DTO.Conf>> GetByUsername(string name)
        {
            var conf = await _context.Conferences
                .Select(AsConfDto)
                .SingleOrDefaultAsync(c => c.Name == name);
            return conf == null ? NotFound() : conf;
        }

        // POST api/conf
        [HttpPost]
        public IActionResult Post([FromBody] string value)
        {
            return Forbid();
        }

        // PUT api/conf/5
        [HttpPut("{id}")]
        public IActionResult Put(int id, [FromBody] string value)
        {
            return Forbid();
        }

        // DELETE api/conf/5
        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            return Forbid();
        }
    }
}

