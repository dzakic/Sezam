using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System;
using System.Diagnostics;
using System.IO;
using Sezam;

namespace ZBB
{
    internal class MainClass
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("ZBB Importer");

            Trace.Listeners.Add(new DebugListener());

            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);


            var builder = new ConfigurationBuilder();
            builder
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings-secrets.json", optional: true);
            var configuration = builder.Build();
            Sezam.Data.Store.ServerName = configuration.GetConnectionString("ServerName");
            Sezam.Data.Store.Password = configuration.GetConnectionString("Password");

            string dataFolder = configuration["Data:Folder"]
                ?? Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data"));

            var importer = new Importer(dataFolder);

            using (var dbx = Sezam.Data.Store.GetNewContext())
            {
                _ = dbx.Database.EnsureCreated();
                dbx.Database.Migrate();
            }

            try
            {
                // Users
                importer.ImportUsers();

                // Conferences
                importer.ImportConferences();
            }
            //catch (DbEntityValidationException valEx)
            //{
            //    foreach (var err in valEx.EntityValidationErrors)
            //    {
            //        Console.WriteLine(err);
            //    }
            //}
            catch (Exception e)
            {
                ErrorHandling.PrintException(e);
                return;
            }
        }
    }
}