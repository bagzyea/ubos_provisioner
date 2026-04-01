using System;

namespace UbosProvisioner.Models;

public enum ProvisioningStatus
{
    Pending,
    InProgress,
    Success,
    Failed,
    Skipped
}

public class ProvisioningUpdate
{
    public string DeviceSerial { get; set; } = string.Empty;
    public string Operation { get; set; } = string.Empty;
    public ProvisioningStatus Status { get; set; } = ProvisioningStatus.Pending;
    public string Message { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.Now;
}
