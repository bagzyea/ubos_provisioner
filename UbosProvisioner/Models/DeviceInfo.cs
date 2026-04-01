using CommunityToolkit.Mvvm.ComponentModel;

namespace UbosProvisioner.Models;

public partial class DeviceInfo : ObservableObject
{
    [ObservableProperty]
    private string serial = string.Empty;

    [ObservableProperty]
    private string model = string.Empty;

    [ObservableProperty]
    private int batteryLevel;

    [ObservableProperty]
    private long storageFree; // bytes

    [ObservableProperty]
    private string connectionState = "disconnected"; // connected, offline, unauthorized

    [ObservableProperty]
    private bool isSelected;
}
