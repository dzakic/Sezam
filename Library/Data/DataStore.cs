namespace Sezam.Library
{
    using System;
    using System.Collections.Generic;
    using System.Data.Common;
    using System.Data.Entity;
    using System.Data.Entity.Migrations;
    using System.Data.Entity.Migrations.History;
    using System.Data.SqlTypes;
    using MySql.Data.EntityFramework;

    internal sealed class SezamDbConfiguration :
       DbMigrationsConfiguration<SezamDbContext>
   {
      public SezamDbConfiguration()
      {
         AutomaticMigrationsEnabled = true;
         AutomaticMigrationDataLossAllowed = true;

         // register mysql code generator
         SetSqlGenerator("MySql.Data.MySqlClient", new MySql.Data.EntityFramework.MySqlMigrationSqlGenerator());
      }
   }

   public class MySqlHistoryContext : HistoryContext
   {
      public MySqlHistoryContext(
        DbConnection existingConnection,
        string defaultSchema)
      : base(existingConnection, defaultSchema)
      {
      }

      protected override void OnModelCreating(DbModelBuilder modelBuilder)
      {
         base.OnModelCreating(modelBuilder);
         modelBuilder.Entity<HistoryRow>().Property(h => h.MigrationId).HasMaxLength(100).IsRequired();
         modelBuilder.Entity<HistoryRow>().Property(h => h.ContextKey).HasMaxLength(200).IsRequired();
      }
   }

   // Database context, per session
   public class SezamDbContext : DbContext
   {
      public SezamDbContext()
      : base("Sezam")
      {
         Database.Log = Console.Write;
         Database.SetInitializer<SezamDbContext>(new MigrateDatabaseToLatestVersion<SezamDbContext, SezamDbConfiguration>());
      }

      public override int SaveChanges()
      {

         CheckDates();
         return base.SaveChanges();
      }

      private void CheckDates()
      {

         // On ConfMessage save, update Conf oldest and newest message
         var msgs = ChangeTracker.Entries<Sezam.Library.EF.ConfMessage>();
         foreach (var msg in msgs)
         {
            if (msg.Entity.Topic.Conference.FromDate == null || msg.Entity.Time < msg.Entity.Topic.Conference.FromDate)
               msg.Entity.Topic.Conference.FromDate = msg.Entity.Time;
            if (msg.Entity.Topic.Conference.ToDate == null || msg.Entity.Time > msg.Entity.Topic.Conference.ToDate)
               msg.Entity.Topic.Conference.ToDate = msg.Entity.Time;
         }

         foreach (var change in ChangeTracker.Entries())
         {
            var values = change.CurrentValues;
            foreach (var name in values.PropertyNames)
            {
               var value = values[name];
               if (value is DateTime)
               {
                  var date = (DateTime)value;
                  if (date < SqlDateTime.MinValue.Value)
                  {
                     System.Diagnostics.Debug.WriteLine("Fix {0} {1} to min", name, value);
                     values[name] = SqlDateTime.MinValue.Value;
                  }
                  else if (date > SqlDateTime.MaxValue.Value)
                  {
                     System.Diagnostics.Debug.WriteLine("Fix {0} {1} to max", name, value);
                     values[name] = SqlDateTime.MaxValue.Value;
                  }
               }
            }
         }
      }

      public DbSet<EF.User> Users { get; set; }
      public DbSet<EF.Conference> Conferences { get; set; }
      public DbSet<EF.ConfTopic> Topics { get; set; }
      public DbSet<EF.ConfMessage> ConfMessages { get; set; }
   }

   // A global object accessible to all sessions
   public class DataStore
   {
      public DataStore()
      {
      }

      public IEnumerable<ISession> sessions;
   }
}