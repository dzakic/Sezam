
namespace Sezam.Library
{

    using System.Collections.Generic;
    using System.Data.Entity;

    public class SezamDbContext : DbContext
    {

        public SezamDbContext() 
        : base("Sezam") 
        {
        }

        public DbSet<EF.User> Users { get; set; }

    }

    public class DataStore
    {
        public DataStore()
        {

            confManager = new ConfManager(this);
        }


        public ConfManager confManager;
        public IEnumerable<ISession> sessions;
    }
}