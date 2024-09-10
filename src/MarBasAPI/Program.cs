using MarBasAPICore.Extensions;
using MarBasAPICore.Http;
using MarBasAPICore.Routing;
using Microsoft.AspNetCore.Authentication;
using NuGet.Configuration;

namespace MarBasAPI
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.Configure<RouteOptions>(options =>
            {
                options.ConstraintMap.Add("DownloadDisposition", typeof(DownloadDispositionRouteConstraint));
            });
            
            using var loggerFactory = LoggerFactory.Create(loggingBuilder => loggingBuilder.AddConfiguration(
                builder.Configuration.GetSection("Logging")).AddConsole().AddDebug().AddEventSourceLogger()
                );
            var bootstrapLogger = loggerFactory.CreateLogger<Program>();

            builder.Services.ConfigureMarBasControllers();

            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            DeployAPIDocsIdNeeded(bootstrapLogger);
            builder.Services.ConfigureMarBasSwagger(builder.Environment.IsDevelopment(), options =>
            {
                options.IncludeXmlComments(Path.Combine(System.AppContext.BaseDirectory, $"{nameof(MarBasAPI)}.xml"));
            });
            if (builder.Environment.IsDevelopment())
            {
                builder.Services.AddAuthentication("BasicAuthentication").AddScheme<AuthenticationSchemeOptions, DevelBasicAuthHandler>("BasicAuthentication", null);
            }
            builder.Services.AddHttpContextAccessor();

            var corsEnabled = builder.Services.ConfigureCors(builder.Configuration.GetSection("Cors"), bootstrapLogger);
            var asyncInitServices = builder.Services.RegisterServices(builder.Configuration.GetSection("Services"), bootstrapLogger);
            if (asyncInitServices.Any())
            {
                builder.Services.RegisterAsyncInitService().AddMultipleInitServices(asyncInitServices);
            }

            var app = builder.Build();

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI(options =>
                {
                    options.DisplayRequestDuration();
                });
            }

            app.UseHttpsRedirection();
			
            if (corsEnabled)
            {
                app.UseCors();
            }
			app.UseAuthentication();
			app.UseAuthorization();

            app.MapControllers();
			
            app.Run();
        }

        private static void DeployAPIDocsIdNeeded(ILogger logger)
        {
            var coreDocs = Path.Combine(System.AppContext.BaseDirectory, $"{nameof(MarBasAPICore)}.xml");
            if (File.Exists(coreDocs))
            {
                return;
            }

            var asm = System.Reflection.Assembly.GetAssembly(typeof(MarBasAPICore.ControllerPrority));
            if (null == asm)
            {
                logger.LogWarning("{name} assembly not found", nameof(MarBasAPICore));
                return;
            }

            var ver = asm.GetName().Version ?? new Version();
            var nugetPath = SettingsUtility.GetGlobalPackagesFolder(Settings.LoadDefaultSettings(null));
            var pkgDir = nameof(MarBasAPICore).ToLowerInvariant();

            var verParts = new List<int>(){ ver.Major, ver.Minor, ver.Build, ver.Revision };
            string pkgPath;
            do
            {
                pkgPath = Path.Combine(nugetPath, pkgDir, string.Join(".", verParts));
                verParts.RemoveAt(verParts.Count - 1);
            }
            while (verParts.Any() && !Directory.Exists(pkgPath));
            if (!System.IO.Directory.Exists(pkgPath))
            {
                logger.LogError("Cannot find package at {pkgPath}", pkgPath);
                return;
            }
            foreach (var xmlPath in System.IO.Directory.GetFiles(pkgPath, "*.xml", SearchOption.AllDirectories))
            {
                if (logger.IsEnabled(LogLevel.Information))
                {
                    logger.LogInformation("Deploying API docs {xmlPath}", xmlPath);
                }
                System.IO.File.Copy(xmlPath, Path.Combine(System.AppContext.BaseDirectory, Path.GetFileName(xmlPath)));
            }
        }
    }
}