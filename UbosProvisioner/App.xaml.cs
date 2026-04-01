using System;
using System.IO;
using System.Windows;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using UbosProvisioner.Models;
using UbosProvisioner.Services;

namespace UbosProvisioner;

public partial class App : Application
{
    public IServiceProvider Services { get; }
    public AppConfig Config { get; }

    public App()
    {
        try
        {
            // Build configuration from appsettings.json
            var config = new ConfigurationBuilder()
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .Build();

            Config = config.Get<AppConfig>() ?? new AppConfig();

            // Setup dependency injection
            var services = new ServiceCollection();
            services.AddSingleton(Config.AppSettings);
            services.AddSingleton<IAdbService, AdbService>();
            services.AddSingleton<IProvisioningService, ProvisioningService>();
            services.AddSingleton<IDeProvisioningService, DeProvisioningService>();
            services.AddSingleton<IDeviceAuditService, DeviceAuditService>();
            services.AddSingleton<ReportingService>();
            services.AddSingleton<ProvisioningProfileService>();
            Services = services.BuildServiceProvider();
        }
        catch (Exception ex)
        {
            string errorLog = $"App initialization error: {DateTime.Now:yyyy-MM-dd HH:mm:ss}\n\n{ex.Message}\n\n{ex.StackTrace}";

            // Write to error log file
            try
            {
                string errorPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "app_error.log");
                File.WriteAllText(errorPath, errorLog);
                System.Windows.MessageBox.Show($"App initialization error. Details saved to:\n{errorPath}\n\nError: {ex.Message}", "Error");
            }
            catch
            {
                System.Windows.MessageBox.Show($"App initialization error: {ex.Message}\n\n{ex.StackTrace}", "Error");
            }

            throw;
        }
    }
}
