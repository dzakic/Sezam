using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Sezam;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

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
                    .SetMinimumLevel(LogLevel.Debug);
            });

            var serviceProvider = services.BuildServiceProvider();
            var logger = serviceProvider.GetRequiredService<ILogger<MainClass>>();

            Sezam.Data.Store.logger = logger;
            Sezam.Data.Store.ConfigureFrom(configuration);

            string dataFolder = configuration["Data:Folder"]
                ?? Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data"));

            var importer = new Importer(dataFolder);

            // Parse command-line arguments
            var options = ParseArguments(args);

            if (options.ShowHelp)
            {
                ShowHelp();
                return;
            }

            try
            {
                // Database reset and migration
                using (var dbx = Sezam.Data.Store.GetNewContext())
                {
                    if (options.Reset)
                    {
                        logger.LogWarning("Deleting database (--reset)...");
                        dbx.Database.EnsureDeleted();
                    }

                    logger.LogInformation("Applying database migrations...");
                    dbx.Database.Migrate();
                    logger.LogInformation("Database is up to date.");
                }

                // Import Users
                logger.LogInformation("Importing Users...");
                importer.ImportUsers();

                // Import Conferences
                if (options.ImportAllConferences)
                {
                    logger.LogInformation("Importing all conferences...");
                    importer.ImportConferences();
                }
                else if (options.ConferenceNames.Any())
                {
                    logger.LogInformation("Importing {0} conference(s)...", options.ConferenceNames.Count);
                    importer.ImportConferences(options.ConferenceNames);
                }

                logger.LogInformation("Import completed successfully.");
            }
            catch (Exception e)
            {
                ErrorHandling.PrintException(e);
                return;
            }
        }

        private static ImportOptions ParseArguments(string[] args)
        {
            var options = new ImportOptions();

            foreach (var arg in args)
            {
                var argLower = arg.ToLowerInvariant();

                if (argLower == "/reset" || argLower == "--reset")
                {
                    options.Reset = true;
                }
                else if (argLower.StartsWith("/conf:") || argLower.StartsWith("--conf:"))
                {
                    var confValue = arg.Substring(arg.IndexOf(':') + 1);
                    if (confValue == "*")
                    {
                        options.ImportAllConferences = true;
                    }
                    else
                    {
                        options.ConferenceNames.Add(confValue);
                    }
                }
                else if (argLower == "/help" || argLower == "--help" || argLower == "-h" || argLower == "/?")
                {
                    options.ShowHelp = true;
                }
            }

            return options;
        }

        private static void ShowHelp()
        {
            Console.WriteLine();
            Console.WriteLine("ZBB Import Tool - Imports legacy ZBB data into Sezam database");
            Console.WriteLine();
            Console.WriteLine("Usage: ZBB.Import [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  /reset, --reset         Delete and recreate the database before import");
            Console.WriteLine("  /conf:*, --conf:*       Import all conferences");
            Console.WriteLine("  /conf:<name>            Import specific conference by name");
            Console.WriteLine("  /help, --help, -h, /?   Show this help message");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  ZBB.Import /reset /users /conf:*          Reset DB and import everything");
            Console.WriteLine("  ZBB.Import /users                         Import users only");
            Console.WriteLine("  ZBB.Import /conf:CET /conf:Sezam          Import specific conferences");
            Console.WriteLine("  ZBB.Import /conf:*                        Import all conferences");
            Console.WriteLine();
        }
    }

    internal class ImportOptions
    {
        public bool Reset { get; set; }
        public bool ImportAllConferences { get; set; }
        public List<string> ConferenceNames { get; set; } = new List<string>();
        public bool ShowHelp { get; set; }
    }
}