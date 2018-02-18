using Newtonsoft.Json;
using Sezam.Library;
using System;
using System.Data.Entity.Validation;
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

            var dataFolder = Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data");

            var importer = new Importer(dataFolder);

            try
            {
                // Users
                importer.ImportUsers();

                // Conferences
                importer.ImportConferences();
            }
            catch (DbEntityValidationException valEx)
            {
                foreach (var err in valEx.EntityValidationErrors)
                {
                    Console.WriteLine(JsonConvert.SerializeObject(err,
                        new JsonSerializerSettings() { ReferenceLoopHandling = ReferenceLoopHandling.Ignore }));
                }
            }
            catch (Exception e)
            {
                ErrorHandling.PrintException(e);
                return;
            }
        }
    }
}