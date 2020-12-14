using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Linq.Expressions;
using Sezam.Data;

// For more information on enabling Web API for empty projects, visit https://go.microsoft.com/fwlink/?LinkID=397860

namespace Sezam.Web.Api
{
    [Route("api/[controller]")]
    [ApiController]
    public class UsersController : ControllerBase
    {

        public UsersController(Sezam.Data.SezamDbContext context)
        {
            _context = context;
        }

        private readonly SezamDbContext _context;

        private static readonly Expression<Func<Sezam.Data.EF.User, DTO.User>>
          AsUserDto = user => new DTO.User
          {
              Id = user.Id,
              Username = user.Username,
              FullName = user.FullName
          };

        // GET: api/users
        [HttpGet]
        public IEnumerable<DTO.User> Get()
        {
            var users = _context.Users.Select(AsUserDto).AsQueryable();
            return users;
        }

        // GET api/users/5
        [HttpGet("{id}")]
        public async Task<ActionResult<DTO.User>> Get(int id)
        {
            var user = await _context.Users
                .Select(AsUserDto)
                .SingleOrDefaultAsync(b => b.Id == id);
            return user == null ? NotFound() : Ok(user);
        }

        // GET api/users/dzakic
        [HttpGet("{username}")]
        public async Task<ActionResult<DTO.User>> Get(string username)
        {
            var user = await _context.Users
                .Select(AsUserDto)
                .SingleOrDefaultAsync(b => b.Username == username);
            if (user == null)
            {
                return NotFound();
            }
            return Ok(user);
        }

        // POST api/<ValuesController>
        [HttpPost]
        public void Post([FromBody] string value)
        {
        }

        // PUT api/<ValuesController>/5
        [HttpPut("{id}")]
        public void Put(int id, [FromBody] string value)
        {
        }

        // DELETE api/<ValuesController>/5
        [HttpDelete("{id}")]
        public void Delete(int id)
        {
        }
    }
}

