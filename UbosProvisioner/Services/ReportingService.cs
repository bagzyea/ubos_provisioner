using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using CsvHelper;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class ReportingService
{
    private readonly AppSettings _config;

    public ReportingService(AppSettings config)
    {
        _config = config;
    }

    /// <summary>
    /// Generate a provisioning summary CSV from operation logs.
    /// </summary>
    public async Task<string> GenerateProvisioningSummaryAsync(List<ProvisioningUpdate> logs)
    {
        try
        {
            Directory.CreateDirectory(_config.LogsDirectory);

            string filename = $"provisioning_summary_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            string filepath = Path.Combine(_config.LogsDirectory, filename);

            using (var writer = new StreamWriter(filepath, false, Encoding.UTF8))
            using (var csv = new CsvWriter(writer, System.Globalization.CultureInfo.InvariantCulture))
            {
                // Write headers
                csv.WriteField("Timestamp");
                csv.WriteField("Device Serial");
                csv.WriteField("Operation");
                csv.WriteField("Status");
                csv.WriteField("Message");
                await csv.NextRecordAsync();

                // Write records
                foreach (var log in logs)
                {
                    csv.WriteField(log.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"));
                    csv.WriteField(log.DeviceSerial);
                    csv.WriteField(log.Operation);
                    csv.WriteField(log.Status);
                    csv.WriteField(log.Message);
                    await csv.NextRecordAsync();
                }
            }

            return filepath;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to generate report: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Generate device audit report CSV.
    /// </summary>
    public async Task<string> GenerateAuditReportAsync(List<DeviceAuditReport> reports)
    {
        try
        {
            Directory.CreateDirectory(_config.LogsDirectory);

            string filename = $"device_audit_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            string filepath = Path.Combine(_config.LogsDirectory, filename);

            using (var writer = new StreamWriter(filepath, false, Encoding.UTF8))
            using (var csv = new CsvWriter(writer, System.Globalization.CultureInfo.InvariantCulture))
            {
                // Write headers
                csv.WriteField("Serial");
                csv.WriteField("Model");
                csv.WriteField("Screen Locked");
                csv.WriteField("Has Device Admin");
                csv.WriteField("FRP Active");
                csv.WriteField("Battery %");
                csv.WriteField("Storage Free (KB)");
                csv.WriteField("Audit Time");
                await csv.NextRecordAsync();

                // Write records
                foreach (var report in reports)
                {
                    csv.WriteField(report.Serial);
                    csv.WriteField(report.Model);
                    csv.WriteField(report.IsScreenLocked ? "Yes" : "No");
                    csv.WriteField(report.HasDeviceAdmin ? "Yes" : "No");
                    csv.WriteField(report.IsFrpActive ? "Yes" : "No");
                    csv.WriteField(report.BatteryLevel);
                    csv.WriteField(report.StorageFree);
                    csv.WriteField(report.AuditTime.ToString("yyyy-MM-dd HH:mm:ss"));
                    await csv.NextRecordAsync();
                }
            }

            return filepath;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to generate audit report: {ex.Message}", ex);
        }
    }
}
