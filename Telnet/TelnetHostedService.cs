using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Sezam
{
    internal class TelnetHostedService : BackgroundService
    {
        public TelnetHostedService(IConfiguration configuration, IHostApplicationLifetime lifetime)
        {
            this.configuration = configuration as IConfigurationRoot ?? throw new ArgumentException("Configuration must implement IConfigurationRoot", nameof(configuration));
            this.lifetime = lifetime;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            server = new Server(configuration);
            await server.InitializeAsync();
            console = new ConsoleLoop(server);

            lifetime.ApplicationStopping.Register(OnApplicationStopping);

            console.Start();
            server.Start();

            while (!stoppingToken.IsCancellationRequested)
            {
                if (console.EscPressed.WaitOne(1000))
                {
                    Trace.TraceInformation("ESC pressed. Requesting graceful shutdown.");
                    lifetime.StopApplication();
                    break;
                }

                await Task.Delay(250, stoppingToken).ConfigureAwait(false);
            }
        }

        public override Task StopAsync(CancellationToken cancellationToken)
        {
            try
            {
                OnApplicationStopping();
            }
            finally
            {
                try { server?.Stop(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                try { console?.Stop(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
                try { server?.Dispose(); } catch (Exception ex) { ErrorHandling.Handle(ex); }
            }

            return Task.CompletedTask;
        }

        private void OnApplicationStopping()
        {
            if (Interlocked.Exchange(ref drainStarted, 1) == 1)
                return;

            if (server is null)
                return;

            var drainSeconds = 60;
            var configuredDrainSeconds = configuration["DrainTimeoutSeconds"];
            if (int.TryParse(configuredDrainSeconds, out var configuredSeconds) && configuredSeconds > 0)
                drainSeconds = configuredSeconds;

            Trace.TraceInformation($"Node entering maintenance mode. Waiting {drainSeconds}s for users to disconnect...");
            server.BeginDrain();

            var drained = server.WaitForDrain(TimeSpan.FromSeconds(drainSeconds));
            if (!drained)
            {
                Trace.TraceWarning("Drain timeout reached. Continuing shutdown with active sessions: {0}", Data.Store.Sessions.Count);
            }
        }

        private readonly IConfigurationRoot configuration;
        private readonly IHostApplicationLifetime lifetime;
        private Server server;
        private ConsoleLoop console;
        private int drainStarted;
    }
}
