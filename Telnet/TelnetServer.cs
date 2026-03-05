using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Sezam
{
    internal class TelnetServer
    {
        private static async Task Main(string[] args)
        {
            Trace.Listeners.Add(new TextWriterTraceListener(System.Console.Out));

            var builder = Host.CreateApplicationBuilder(args);
            builder.Configuration
                .AddJsonFile("appsettings-secrets.json", optional: true)
                .AddJsonFile("/etc/sezam/appsettings.json", optional: true)
                .AddEnvironmentVariables();

            builder.Services.AddHostedService<TelnetHostedService>();

            using var host = builder.Build();
            await host.RunAsync();
        }
    }
}