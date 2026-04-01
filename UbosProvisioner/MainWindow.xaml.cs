using System;
using System.IO;
using System.Windows;
using UbosProvisioner.ViewModels;

namespace UbosProvisioner;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        try
        {
            InitializeComponent();

            // Set DataContext to MainViewModel (injected from App.Services)
            var app = (App)Application.Current;
            this.DataContext = new MainViewModel(
                app.Services.GetService(typeof(UbosProvisioner.Services.IAdbService)) as UbosProvisioner.Services.IAdbService
                    ?? throw new InvalidOperationException("IAdbService not registered"),
                app.Services.GetService(typeof(UbosProvisioner.Services.IProvisioningService)) as UbosProvisioner.Services.IProvisioningService
                    ?? throw new InvalidOperationException("IProvisioningService not registered"),
                app.Services.GetService(typeof(UbosProvisioner.Services.IDeProvisioningService)) as UbosProvisioner.Services.IDeProvisioningService
                    ?? throw new InvalidOperationException("IDeProvisioningService not registered"),
                app.Services.GetService(typeof(UbosProvisioner.Models.AppSettings)) as UbosProvisioner.Models.AppSettings
                    ?? throw new InvalidOperationException("AppSettings not registered"),
                app.Services.GetService(typeof(UbosProvisioner.Services.IDeviceAuditService)) as UbosProvisioner.Services.IDeviceAuditService
                    ?? throw new InvalidOperationException("IDeviceAuditService not registered"),
                app.Services.GetService(typeof(UbosProvisioner.Services.ReportingService)) as UbosProvisioner.Services.ReportingService
                    ?? throw new InvalidOperationException("ReportingService not registered")
            );
        }
        catch (Exception ex)
        {
            string errorLog = $"MainWindow initialization error: {DateTime.Now:yyyy-MM-dd HH:mm:ss}\n\n{ex.Message}\n\n{ex.StackTrace}";

            // Write to error log file
            try
            {
                string errorPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mainwindow_error.log");
                File.WriteAllText(errorPath, errorLog);
                MessageBox.Show($"MainWindow initialization error. Details saved to:\n{errorPath}\n\nError: {ex.Message}", "Initialization Error");
            }
            catch
            {
                MessageBox.Show($"MainWindow initialization error: {ex.Message}\n\n{ex.StackTrace}", "Initialization Error");
            }

            throw;
        }
    }

    private bool _isDarkTheme = false;

    private void ToggleTheme_Click(object sender, RoutedEventArgs e)
    {
        _isDarkTheme = !_isDarkTheme;
        var app = (App)Application.Current;
        var dict = new ResourceDictionary { Source = new Uri(_isDarkTheme ? "Themes/DarkTheme.xaml" : "Themes/LightTheme.xaml", UriKind.Relative) };
        app.Resources.MergedDictionaries.Clear();
        app.Resources.MergedDictionaries.Add(dict);
    }

    private void MinBtn_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void MaxBtn_Click(object sender, RoutedEventArgs e) => WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    private void CloseBtn_Click(object sender, RoutedEventArgs e) => Close();
}
