using System.Diagnostics;
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
            var builder = Host.CreateApplicationBuilder(args);

            builder.Configuration                
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
                .AddJsonFile("appsettings-secrets.json", optional: true)
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