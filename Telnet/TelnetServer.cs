using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Sezam
{
    internal class TelnetServer
    {
        private static async Task Main(string[] args)
        {
            // The generic host honours DOTNET_ENVIRONMENT / the --environment
            // switch, NOT ASPNETCORE_ENVIRONMENT (which the ASP.NET Core host in
            // the Web project reads). Bridge to whichever is set — ASPNETCORE_*
            // first (local dev / make run-telnet), then DOTNET_ENVIRONMENT
            // (systemd, cron, Docker Swarm), then "Production" — so a single
            // variable drives both hosts. No-op if the caller already passed
            // --environment explicitly.
            var resolved = System.Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
                ?? System.Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
                ?? "Production";
            if (args.All(a => !a.StartsWith("--environment=", System.StringComparison.OrdinalIgnoreCase)))
            {
                args = args.Append($"--environment={resolved}").ToArray();
            }

            var builder = Host.CreateApplicationBuilder(args);

            builder.Configuration
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
                .AddKeyPerFile(directoryPath: "/run/secrets", optional: true)
                .AddEnvironmentVariables();

            // Configure logging with console output and colors
            builder.Logging
                .ClearProviders()
                .AddSimpleConsole(options =>
                {
                    // Enable colored output and scopes
                    options.IncludeScopes = true;
                    options.TimestampFormat = "HH:mm:ss ";
                    options.SingleLine = true;
                });

            builder.Services.AddHostedService<TelnetHostedService>();

            using var host = builder.Build();
            await host.RunAsync();
        }
    }
}