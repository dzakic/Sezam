using System;
using System.Collections.Generic;
using System.IO;

namespace ZBB
{
    internal class MainClass
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("ZBB Importer");

            var dataFolder = Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data");

            var importer = new Importer(dataFolder);

            // Users
            importer.ImportUsers();

            // Conferences
            var conferences = new List<ConferenceVolume>();
            foreach (var dir in importer.ConfNames)
                conferences.Add(importer.ReadConf(dir));

        }
    }
}