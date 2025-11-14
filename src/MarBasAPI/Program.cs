using CraftedSolutions.MarBasAPICore.Auth;
using CraftedSolutions.MarBasAPICore.Extensions;
using CraftedSolutions.MarBasAPICore.Routing;
using NuGet.Configuration;

namespace CraftedSolutions.MarBasAPI
{
    public class Program
    {
        public async static Task Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            builder.Configuration.AddJsonFile("authsettings.json", true, true);
            builder.Configuration.AddJsonFile($"authsettings.{builder.Environment.EnvironmentName}.json", true, true);

            // Add services to the container.
            builder.Services.Configure<RouteOptions>(options =>
            {
                options.ConstraintMap.Add("DownloadDisposition", typeof(DownloadDispositionRouteConstraint));
            });

            builder.ConfigureTraceFileLogging();

            using var loggerFactory = builder.GetBootstrapLoggerFactory();
            var bootstrapLogger = loggerFactory.CreateLogger<Program>();

            builder.Services.ConfigureMarBasTimeouts(builder.Configuration.GetSection("RequestTimeouts"));
            builder.Services.ConfigureMarBasControllers();

            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            DeployAPIDocsIdNeeded(bootstrapLogger);
            builder.Services.ConfigureMarBasSwagger(builder.Configuration, options =>
            {
                options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, $"{nameof(MarBasAPI)}.xml"));
            });
            builder.Services.ConfigureMarBasAuthentication(builder.Configuration.GetSection(builder.Configuration.GetValue(AuthConfig.SectionSwitch, AuthConfig.SectionName)), bootstrapLogger);
            builder.Services.AddHttpContextAccessor();

            var corsEnabled = builder.Services.ConfigureCors(builder.Configuration.GetSection("Cors"), bootstrapLogger);
            var asyncInitServices = builder.Services.RegisterServices(builder.Configuration.GetSection("Services"), bootstrapLogger);
            if (asyncInitServices.Any())
            {
                builder.Services.RegisterAsyncInitService().AddMultipleInitServices(asyncInitServices);
            }
            builder.Services.ConfigureBackgroundQueue();

            using var app = builder.Build();
            app.UseRequestTimeouts();

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.ConfigureMarBasSwaggerUI(builder.Configuration);
            }

            app.ConfigureHttpsRedirection();

            if (corsEnabled)
            {
                app.UseCors();
            }

            if (builder.Configuration.GetValue("StaticFiles:Enabled", false))
            {
                app.UseStaticFiles();
            }
            app.UseAuthentication();
            app.UseAuthorization();

            app.MapControllers();

            await app.RunAsync();
        }

        private static void DeployAPIDocsIdNeeded(ILogger logger)
        {
            var coreDocs = Path.Combine(AppContext.BaseDirectory, $"{nameof(MarBasAPICore)}.xml");
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

            var verParts = new List<int>() { ver.Major, ver.Minor, ver.Build, ver.Revision };
            string pkgPath;
            do
            {
                pkgPath = Path.Combine(nugetPath, pkgDir, string.Join(".", verParts));
                verParts.RemoveAt(verParts.Count - 1);
            }
            while (0 == verParts.Count && !Directory.Exists(pkgPath));
            if (!Directory.Exists(pkgPath))
            {
                logger.LogError("Cannot find package at {pkgPath}", pkgPath);
                return;
            }
            foreach (var xmlPath in Directory.GetFiles(pkgPath, "*.xml", SearchOption.AllDirectories))
            {
                if (logger.IsEnabled(LogLevel.Information))
                {
                    logger.LogInformation("Deploying API docs {xmlPath}", xmlPath);
                }
                File.Copy(xmlPath, Path.Combine(AppContext.BaseDirectory, Path.GetFileName(xmlPath)));
            }
        }
    }
}