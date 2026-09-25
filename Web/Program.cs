using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Sezam.Data;

namespace Sezam.Web
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            builder.Configuration.AddKeyPerFile(directoryPath: "/run/secrets", optional: true);

            builder.Logging.AddSimpleConsole(options =>
            {
                options.SingleLine = true;
                options.TimestampFormat = "HH:mm:ss ";
            });

            Data.Store.ConfigureFrom(builder.Configuration);

            builder.Services
                .AddDbContext<SezamDbContext>(options => Data.Store.GetOptionsBuilder(options))
                .AddRazorPages();

            if (Data.Store.RedisEnabled)
            {
                builder.Services.AddSingleton<MessageBroadcaster>(sp =>
                {
                    Data.Store.MessageBroadcaster = new MessageBroadcaster();
                    Data.Store.MessageBroadcaster.InitializeAsync(Data.Store.RedisConnectionString).GetAwaiter().GetResult();
                    return Data.Store.MessageBroadcaster;
                });
            }

            var app = builder.Build();

            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            // app.UseHttpsRedirection();
            app.UseStaticFiles(new StaticFileOptions
            {
                OnPrepareResponse = ctx =>
                {
                    ctx.Context.Response.Headers.Append(
                         "Cache-Control", $"public, max-age=3600, stale-while-revalidate=86400");
                }
            });

            app.UseRouting();

            app.UseAuthorization();

            app.MapRazorPages();
            app.MapControllers();

            app.Run();
        }
    }
}
