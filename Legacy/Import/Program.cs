using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Sezam;
using System;
using System.Diagnostics;
using System.IO;

namespace ZBB
{
    internal class MainClass
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("ZBB Importer");

            Trace.Listeners.Add(new DebugListener());

            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);


            var configuration = new ConfigurationBuilder()
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings-secrets.json", optional: true)
                .AddEnvironmentVariables()
                .Build();

            // Configure logging
            var services = new ServiceCollection();
            services.AddLogging(logging =>
            {
                logging.ClearProviders()
                    .AddSimpleConsole(options =>
                    {
                        options.IncludeScopes = true;
                        options.TimestampFormat = "HH:mm:ss ";
                    })
                    .SetMinimumLevel(LogLevel.Debug);  // Capture Debug and above; set to Information for production
            });

            var serviceProvider = services.BuildServiceProvider();
            var logger = serviceProvider.GetRequiredService<ILogger<MainClass>>();

            Sezam.Data.Store.logger = logger;
            Sezam.Data.Store.ConfigureFrom(configuration);

            string dataFolder = configuration["Data:Folder"]
                ?? Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data"));

            var importer = new Importer(dataFolder);

            logger.LogInformation("EntityFramework checking integrity...");
            using (var dbx = Sezam.Data.Store.GetNewContext())
            {
                _ = dbx.Database.EnsureCreated();
                logger.LogInformation("EntityFramework Migrate...");
                dbx.Database.Migrate();
            }

            try
            {
                // Users
                logger.LogInformation("Importing Users...");
                importer.ImportUsers();

                // Conferences
                logger.LogInformation("Importing Conferences...");

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