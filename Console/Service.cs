using System;
using System.Configuration.Install;
using System.ComponentModel;
using System.ServiceProcess;
using System.Diagnostics;

namespace Sezam
{
   public class Service : ServiceBase
   {
      private Sezam.Server server;

      // The main entry point for the process
      private static void Main()
      {
         // More than one user service may run in the same process. To add
         // another service to this process, change the following line to
         // create a second service object. For example,
         //
         //   ServicesToRun = New System.ServiceProcess.ServiceBase[] {new Service1(), new MySecondUserService()};
         //
         var ServicesToRun = new ServiceBase[] { new Sezam.Service() };
         ServiceBase.Run(ServicesToRun);
      }

      protected override void OnStart(string[] args)
      {
         base.OnStart(args);
         server = new Sezam.Server();
         server.Start();
      }

      protected override void OnStop()
      {
         server.Stop();
         base.OnStop();
      }

      protected override void OnPause()
      {
         base.OnPause();
      }

      protected override void OnContinue()
      {
         base.OnContinue();
      }

      protected override void OnSessionChange(SessionChangeDescription changeDescription)
      {
         Debug.WriteLine("Power status: " + changeDescription);
         base.OnSessionChange(changeDescription);
      }

      protected override bool OnPowerEvent(PowerBroadcastStatus powerStatus)
      {
         Debug.WriteLine("Power status: " + powerStatus);
         return base.OnPowerEvent(powerStatus);
      }

      protected override void OnShutdown()
      {
         server.Stop();
         base.OnShutdown();
      }

      protected override void OnCustomCommand(int command)
      {
         base.OnCustomCommand(command);
      }
   }

   [RunInstaller(true)]
   public class ProjectInstaller : Installer
   {
      public ProjectInstaller()
      {
         ServiceProcessInstaller processInstaller = new ServiceProcessInstaller();
         processInstaller.Account = ServiceAccount.LocalSystem;

         ServiceInstaller installer = new ServiceInstaller();
         installer.ServiceName = "Sezam.Net";
         installer.StartType = ServiceStartMode.Automatic;
         Installers.AddRange(new Installer[] { processInstaller, installer });
      }
   }
}

