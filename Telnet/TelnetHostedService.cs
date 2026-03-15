using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Sezam
{
    internal class TelnetHostedService : BackgroundService
    {
        private readonly ILoggerFactory loggerFactory;
        private readonly ILogger<TelnetHostedService> logger;

        public TelnetHostedService(IConfiguration configuration, IHostApplicationLifetime lifetime, ILoggerFactory loggerFactory, ILogger<TelnetHostedService> logger)
        {
            this.configuration = configuration as IConfigurationRoot ?? throw new ArgumentException("Configuration must implement IConfigurationRoot", nameof(configuration));
            this.lifetime = lifetime;
            this.loggerFactory = loggerFactory;
            this.logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var serverLogger = loggerFactory.CreateLogger<Server>();
            server = new Server(configuration, serverLogger, loggerFactory);
            await server.InitializeAsync();
            var console = new ConsoleLoop(server);

            lifetime.ApplicationStopping.Register(OnApplicationStopping);

            logger.LogInformation("Telnet server starting");
            server.Start();

            var consoleTask = console.RunAsync();
            var cancelTask = Task.Delay(Timeout.Infinite, stoppingToken);
            await Task.WhenAny(consoleTask, cancelTask).ConfigureAwait(false);

            if (consoleTask.IsCompletedSuccessfully && consoleTask.Result)
            {
                logger.LogInformation("ESC pressed, requesting graceful shutdown");
                lifetime.StopApplication();
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

            logger.LogInformation($"Node entering maintenance mode. Waiting {drainSeconds}s for users to disconnect...");
            server.BeginDrain();

            var drained = server.WaitForDrain(TimeSpan.FromSeconds(drainSeconds));
            if (!drained)
            {
                logger.LogWarning("Drain timeout reached. Continuing shutdown with active sessions: {0}", Data.Store.Sessions.Count);
            }
        }

        private readonly IConfigurationRoot configuration;
        private readonly IHostApplicationLifetime lifetime;
        private Server server;
        private int drainStarted;
    }
}
