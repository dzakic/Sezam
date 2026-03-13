using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace ZBB
{
    public class Importer
    {
        public Importer(string dataPath)
        {
            this.rootPath = new DirectoryInfo(Path.GetFullPath(dataPath));
        }

        public string ConfPath { get { return Path.Combine(this.rootPath.FullName, "Conf"); } }


        private void ImportConference(string confName)
        {
            var logger = Sezam.Data.Store.LoggerFactory.CreateLogger("ImportConf");
            using (var Dbx = Sezam.Data.Store.GetNewContext())
            { 
                using ConferenceVolume zbbConf = new ConferenceVolume(confName);
                try
                {

                    if (Dbx
                        .Conferences
                        .Where(c => c.Name == zbbConf.NameOnly && c.VolumeNo == zbbConf.VolumeNumber)
                        .Any())
                    {
                        logger.LogInformation("Conf {0} is already imported.", confName);
                        return;
                    }

                    logger.LogInformation("Importing {0}.{1}", ConfPath, zbbConf.Name);
                    string confDir = Path.Combine(ConfPath, confName);
                    zbbConf.Import(confDir);

                    // Any missing users?
                    var msgAuthors = zbbConf.Messages
                        .Select(m => m.author)
                        .Where(u => !string.IsNullOrWhiteSpace(u))
                        .Distinct();
                    var existingUsers = Dbx.Users.Select(u => u.Username);
                    var usersToAdd = msgAuthors.Except(existingUsers)
                        .Select(u => new Sezam.Data.EF.User() { Username = u });

                    if (usersToAdd.Any())
                    {
                        logger.LogInformation("Adding users: {0}", string.Join(", ", usersToAdd.Select(u => u.Username)));
                        Dbx.Users.AddRange(usersToAdd);
                        Dbx.SaveChanges();
                    }

                    var conf = zbbConf.ToEFConf();
                    Dbx.Conferences.Add(conf);

                    var userDict = Dbx.Users.Select(u => new { u.Username, u.Id })
                        .ToDictionary(u => u.Username, u => u.Id);

                    foreach (var zbbMsg in zbbConf.Messages)
                    {
                        var efMsg = zbbMsg.EFConfMessage;
                        if (userDict.ContainsKey(zbbMsg.author))
                            efMsg.AuthorId = userDict[zbbMsg.author];
                        else
                            logger.LogWarning("Unknown ConfMsg Author: {0}", zbbMsg.author);
                    }

                    logger.LogInformation($"Finished importing {confName}");
                    Dbx.SaveChanges();
                    logger.LogInformation($"Conf {confName} saved to database");
                }
                catch (Exception e)
                {
                    logger.LogError($"Error importing conf {confName}");
                    Sezam.ErrorHandling.PrintException(e);
                }
            }
        }

        public void ImportConferences()
        {
            var confDirInfo = new DirectoryInfo(ConfPath);
            var confNames = confDirInfo.EnumerateDirectories().Select(dir => dir.Name);
            ImportConferences(confNames);
        }

        public void ImportConferences(IEnumerable<string> conferenceNames)
        {
            var options = new ParallelOptions() { MaxDegreeOfParallelism = 1 };
            Parallel.ForEach(conferenceNames, options, conf => ImportConference(conf));
        }

        public void ImportUsers()
        {
            var logger = Sezam.Data.Store.LoggerFactory.CreateLogger("ImportUsers");
            using (var Dbx = Sezam.Data.Store.GetNewContext())
            {
                int userCount = Dbx.Users.Count();
                if (userCount == 0)
                {
                    var users = ReadUsers(logger)
                        .Where(u => !string.IsNullOrWhiteSpace(u.Username))
                        // .Where(u => u.Id > 0)
                        // .Where(u => u.LastCall.HasValue)
                        .Distinct(new Sezam.Data.EF.UserComparer());

                    Dbx.Users.AddRange(users);
                    Dbx.SaveChanges();
                    logger.LogInformation($"Saved {Dbx.Users.Count()} users");
                }
                else
                    logger.LogInformation("Users already loaded, count = {0}", userCount);
            }
        }

        private IEnumerable<Sezam.Data.EF.User> ReadUsers(ILogger logger)
        {
            int count = 0;
            int inactiveCount = 0;
            string userFile = Path.Combine(rootPath.FullName, "user.dat");
            using (BinaryReader r = new BinaryReader(File.Open(userFile, FileMode.Open)))
            {
                while (r.PeekChar() != -1)
                {
                    var user = new Sezam.Data.EF.User(count > 0 ? count : 99999);
                    user.Read(r);
                    logger.LogDebug($"{user.Username,-16} {user.FullName,-28} {user.City,-16} {user.LastCall:dd MMM yyyy HH:mm}");
                    count++;
                    if (!user.LastCall.HasValue)
                        inactiveCount++;

                    yield return user;
                }
            }
            logger.LogInformation("Read {0} users, {1} inactive.", count, inactiveCount);
        }

        private readonly DirectoryInfo rootPath;

        public IEnumerable<string> ConfNames;
    }
}