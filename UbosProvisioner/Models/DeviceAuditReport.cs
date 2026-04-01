using System;

namespace UbosProvisioner.Models;

public class DeviceAuditReport
{
    public string Serial { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public bool IsScreenLocked { get; set; }
    public bool HasDeviceAdmin { get; set; }
    public string DeviceAdminPackages { get; set; } = string.Empty;
    public bool IsFrpActive { get; set; }
    public int BatteryLevel { get; set; }
    public long StorageFree { get; set; }
    public DateTime AuditTime { get; set; } = DateTime.Now;
    public string RemediationInstructions { get; set; } = string.Empty;
}
