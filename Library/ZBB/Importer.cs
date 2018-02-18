using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Sezam.Model;

namespace ZBB
{
    public class Importer
    {
        public Importer(string dataPath)
        {
            this.rootPath = new DirectoryInfo(Path.GetFullPath(dataPath));
            var ConfDirInfo = new DirectoryInfo(ConfPath);
            ConfNames = ConfDirInfo.EnumerateDirectories().Select(dir => dir.Name);
        }

        public string ConfPath { get { return Path.Combine(this.rootPath.FullName, "Conf"); } }

        public ConferenceVolume ReadConf(string confName)
        {
            var conf = new ConferenceVolume(confName);
            string confDir = Path.Combine(ConfPath, confName);
            conf.Import(confDir);
            return conf;
        }

        public void ImportUsers()
        {
            Dbx.Users.AddRange(ReadUsers());
            Dbx.SaveChanges();
        }

        public IEnumerable<User> ReadUsers()
        {
            string userFile = Path.Combine(rootPath.FullName, "user.dat");
            using (BinaryReader r = new BinaryReader(File.Open(userFile, FileMode.Open)))
            {
                int id = 0;
                // int deletedCount = 0;
                int inactiveCount = 0;
                
                while (r.PeekChar() != -1)
                {
                    var user = new User(id++);
                    user.Read(r);
                    // Console.WriteLine(user.ToString());
                    yield return user;
                    if (user.LastCall == DateTime.MinValue)
                        inactiveCount++;
                }
                System.Diagnostics.Debug.WriteLine("Read {0} users, {1} inactive.", id, inactiveCount);
            }
        }

        Sezam.Library.SezamDbContext Dbx = new Sezam.Library.SezamDbContext();
        private DirectoryInfo rootPath;
        public IEnumerable<string> ConfNames;
    }
}