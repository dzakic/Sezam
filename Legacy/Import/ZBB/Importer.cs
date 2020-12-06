using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Diagnostics;

namespace ZBB
{
    public class Importer
    {
        public Importer(string dataPath)
        {
            this.rootPath = new DirectoryInfo(Path.GetFullPath(dataPath));
        }

        public string ConfPath { get { return Path.Combine(this.rootPath.FullName, "Conf"); } }

        public void ImportConferences()
        {
            var confDirInfo = new DirectoryInfo(ConfPath);
            var confNames = confDirInfo.EnumerateDirectories().Select(dir => dir.Name);

            foreach (var confName in confNames)
            {

                using (var Dbx = new Sezam.Library.SezamDbContext())
                {
                    Dbx.Database.Log = null;
                    using (ConferenceVolume zbbConf = new ConferenceVolume(confName))
                        try
                        {

                            var conf = Dbx.Conferences.Where(c => c.Name == zbbConf.NameOnly && c.VolumeNo == zbbConf.VolumeNumber).FirstOrDefault();
                            if (conf != null)
                            {
                                Console.WriteLine("Conf {0} is already imported.", confName);
                                continue;
                            }

                            Console.WriteLine("Importing {0}.{1}", ConfPath, confName);
                            string confDir = Path.Combine(ConfPath, confName);
                            zbbConf.Import(confDir);

                            // Any missing users?
                            var msgAuthors = zbbConf.Messages
                                .Select(m => m.author)
                                .Where(u => !string.IsNullOrWhiteSpace(u))
                                .Distinct();
                            var existingUsers = Dbx.Users.Select(u => u.username);
                            var usersToAdd = msgAuthors.Except(existingUsers)
                                .Select(u => new Sezam.Library.EF.User() { username = u });

                            Console.WriteLine("Adding users: {0}", string.Join(", ", usersToAdd.Select(u => u.username)));
                            Dbx.Users.AddRange(usersToAdd);
                            Dbx.SaveChanges();

                            conf = new Sezam.Library.EF.Conference();
                            Dbx.Conferences.Add(conf);
                            zbbConf.ToEFConf(conf);

                            var userDict = Dbx.Users.Select(u => new { u.username, u.Id })
                                .ToDictionary(u => u.username, u => u.Id);

                            foreach (var zbbMsg in zbbConf.Messages)
                            {
                                var efMsg = zbbMsg.EFConfMessage;
                                if (userDict.ContainsKey(zbbMsg.author))
                                    efMsg.AuthorId = userDict[zbbMsg.author];
                                else
                                    Console.WriteLine("Unknown ConfMsg Author: {0}", zbbMsg.author);
                            }

                            Console.Write("Saving...");
                            Dbx.SaveChanges();
                            Console.WriteLine("Done");
                        }
                        catch (Exception e)
                        {
                            Console.WriteLine("Error importing conf");
                            Sezam.Library.ErrorHandling.PrintException(e);
                        }
                }
            }
        }

        public void ImportUsers()
        {
            using (var Dbx = new Sezam.Library.SezamDbContext())
            {
                Dbx.Database.Log = null; // Console.Write;

                var userCount = Dbx.Users.Count();
                if (userCount == 0)
                {
                    var users = ReadUsers()
                        .Where(u => !string.IsNullOrWhiteSpace(u.username))
                        .Distinct(new Sezam.Library.EF.UserComparer());

                    Dbx.Users.AddRange(users);
                    Dbx.SaveChanges();
                }
                else
                    Console.WriteLine("Users already loaded, count = {0}", userCount);
            }
        }

        private IEnumerable<Sezam.Library.EF.User> ReadUsers()
        {
            int id = 0;
            int inactiveCount = 0;
            string userFile = Path.Combine(rootPath.FullName, "user.dat");
            using (BinaryReader r = new BinaryReader(File.Open(userFile, FileMode.Open)))
            {
                // int deletedCount = 0;
                while (r.PeekChar() != -1)
                {
                    var user = new Sezam.Library.EF.User(id++);
                    user.Read(r);
                    //Console.WriteLine(JsonConvert.SerializeObject(user));
                    Console.Write(user.username + " ");
                    if (user.LastCall == DateTime.MinValue)
                        inactiveCount++;
                    yield return user;
                }
            }
            Debug.WriteLine("Read {0} users, {1} inactive.", id, inactiveCount);
        }

        // Sezam.Library.SezamDbContext Dbx = new Sezam.Library.SezamDbContext();
        private DirectoryInfo rootPath;

        public IEnumerable<string> ConfNames;
    }
}