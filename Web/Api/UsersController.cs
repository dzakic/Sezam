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
    public class UsersController : ControllerBase
    {

        public UsersController(Sezam.Data.SezamDbContext context, ILogger<UsersController> logger)
        {
            _context = context;
            _logger = logger;
        }

        private readonly SezamDbContext _context;
        private readonly ILogger<UsersController> _logger;

        private static readonly Expression<Func<Sezam.Data.EF.User, DTO.User>>
          AsUserDto = user => new DTO.User
          {
              Id = user.Id,
              Username = user.Username,
              FullName = user.FullName,
              City = user.City,
              LastCall = user.LastCall
          };

        // GET: api/users
        [HttpGet]
        public IEnumerable<DTO.User> Search(string filter = "")
        {
            IQueryable<Data.EF.User> users = _context.Users;
            if (!string.IsNullOrEmpty(filter))
                users = users.Where(u => 
                    u.Username.Contains(filter) ||
                    u.FullName.Contains(filter) ||
                    u.City.Contains(filter)
                );
            return users
                .OrderByDescending(u => u.LastCall)
                .Take(100)
                .Select(AsUserDto); ;
        }

        // GET api/users/5
        [HttpGet("{id:int}")]
        public async Task<ActionResult<DTO.User>> GetById(int id)
        {
            var user = await _context.Users
                .Select(AsUserDto)
                .SingleOrDefaultAsync(u => u.Id == id);
            return user == null ? NotFound() : user;
        }

        // GET api/users/dzakic
        [HttpGet("{username:alpha}")]
        public async Task<ActionResult<DTO.User>> GetByUsername(string username)
        {
            var user = await _context.Users
                .Select(AsUserDto)
                .SingleOrDefaultAsync(u => u.Username == username);
            return user == null ? NotFound() : user;
        }

        // POST api/users
        [HttpPost]
        public IActionResult Post([FromBody] string value)
        {
            return Forbid();
        }

        // PUT api/users/5
        [HttpPut("{id}")]
        public IActionResult Put(int id, [FromBody] string value)
        {
            return Forbid();
        }

        // DELETE api/users/5
        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            return Forbid();
        }
    }
}

