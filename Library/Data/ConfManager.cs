using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Linq;
using ZBB;

namespace Sezam.Library
{
   public class ConfManager
   {
      public ConfManager(DataStore dataStore)
      {
         this.dataStore = dataStore;

         var importer = new Importer(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "Data"));

         conferences = new List<ConferenceVolume>();

         // Parallel.ForEach(importer.ConfNames, dir => conferences.Add(importer.ReadConf(dir)));
         // foreach (var dir in importer.ConfNames) conferences.Add(importer.ReadConf(dir));
         Action importConfs = () =>
            {
                Parallel.ForEach(importer.ConfNames,
                dir =>
                {
                    var conf = importer.ReadConf(dir);
                    lock (conferences)
                        conferences.Add(conf);
                });
            };

         Task.Factory.StartNew(importConfs);
      }

      public List<ConferenceVolume> conferences;
      private DataStore dataStore;
   }
}