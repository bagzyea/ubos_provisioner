using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public interface IAdbService
{
    /// <summary>
    /// Run a raw ADB command and return the result.
    /// </summary>
    Task<AdbResult> RunAsync(string command, string args = "", CancellationToken ct = default);

    /// <summary>
    /// Get list of connected devices.
    /// </summary>
    Task<List<DeviceInfo>> GetConnectedDevicesAsync(CancellationToken ct = default);

    /// <summary>
    /// Start background polling of connected devices.
    /// </summary>
    void StartDevicePolling(Action<List<DeviceInfo>> onDevicesUpdated, int intervalMs = 5000);

    /// <summary>
    /// Stop background polling.
    /// </summary>
    void StopDevicePolling();
}
