# UBOS Device Provisioner — Android Tablet Management Tool

A native **C# .NET 10 WPF** application for provisioning and de-provisioning Android tablets used in census/survey field work. Fully replaces the Python PyQt6 predecessor with zero feature loss.

---

## 🎯 Features

### Provisioning Tab
- **APK Installation**: Install multiple `.apk` files sequentially on multiple devices simultaneously
- **Data Transfer**: Push app data (surveys, configuration, etc.) and TPK map tiles to `/sdcard/Android/data/`
- **TPK Distribution**: Sequential, round-robin, or random distribution modes
- **Device Configuration**: Auto-create user accounts, set screen timeout, capture QC screenshots
- **Concurrent Operations**: Configurable max concurrent devices (default: 3)
- **Real-time Logging**: Live progress tracking for all operations

### De-Provisioning Tab
- **Secure Data Extraction**: Pull sensitive survey/census data off devices to timestamped local folders
- **Factory Reset**: Trigger full device wipe post-extraction
- **FRP Warning**: Alert operators about Factory Reset Protection if a Google/MDM account is signed in
- **Concurrent Execution**: Same parallelized approach as provisioning

### Device Recovery & Audit Tab ⭐ **NEW**
- **Lock Status Detection**: Check if device screen is locked
- **MDM/Device Admin Audit**: Identify enrolled management solutions (Google Workspace, Intune, Samsung Knox)
- **FRP Detection**: Detect if a Google account is signed in
- **PIN-Based Unlock**: Attempt screen lock clearance if you know the PIN
- **Recovery Mode**: Reboot device to manual factory reset
- **Guided Remediation**: In-app instructions for addressing lock/MDM issues
  - ✅ Can unlock via PIN
  - ✅ Can reboot to recovery
  - ❌ Cannot bypass FRP (by design — security limitation)
  - ❌ Cannot remove MDM (only IT admin can do this)

### Settings Tab
- **Concurrent Device Limit**: Control parallelization (1–10 devices)
- **Device Polling Interval**: How often to refresh device list (default: 5000ms)
- **Logs Directory**: Where to save operation reports and audit logs
- **Platform Tools Path**: Location of bundled `adb.exe`

### Logs Tab
- **Operation Log**: Real-time view of all provisioning/de-provisioning steps
- **Export Reports**: Save operation summaries as timestamped CSV files
- **Folder Access**: Quick link to `Logs/` directory

### Device Info Tab
- **Connected Devices**: View all ADB-connected devices with model, battery, and storage info
- **Quick Audit**: One-click refresh of device list

---

## 🚀 Getting Started

### Requirements
- **Windows 10 / 11** with USB drivers for your Android devices
- **.NET 10 Runtime** (or .NET SDK if developing)
- **USB Debugging enabled** on all Android tablets
- **ADB drivers** (bundled in `platform-tools/adb.exe`)

### Launch

```powershell
# Via .NET CLI (dev mode)
dotnet run --project UbosProvisioner/UbosProvisioner.csproj

# Via compiled .exe (release mode, after publishing)
.\UbosProvisioner.exe
```

### Basic Workflow

#### **Provisioning**
1. Connect tablets via USB (ensure USB Debugging is enabled)
2. Click **Refresh Devices** to detect connected devices
3. Select devices in the grid (checkbox)
4. Fill in **Provisioning Config**:
   - **APK Files**: Click "Add APKs" to select one or more `.apk` installers (multi-select supported)
   - **App Data**: Browse to folder with application data (surveys, configuration, etc.)
   - **TPK Folder**: Browse to folder with map tiles
   - **TPK Distribution**: Choose sequential/round-robin/random
5. Click **Start Provisioning** and monitor the log (APKs will install sequentially)

#### **De-Provisioning**
1. Switch to **De-Provisioning** tab
2. Select devices to wipe
3. Set **Extract Data Output** folder (where to save pulled data)
4. Click **Start De-Provisioning**
5. Monitor log — device will extract data, then factory reset

#### **Device Recovery** (Locked Tablets)
1. Switch to **Device Recovery** tab
2. Enter device serial number
3. Click **Audit Device** to get lock/MDM/FRP status
4. **If screen-locked with known PIN**: Enter PIN → **Clear Lock**
5. **If no FRP/MDM**: Click **Reboot to Recovery** → manually complete wipe on device
6. **If MDM enrolled**: Contact IT admin to unenroll via their admin console

---

## 📊 Reports

Operation logs are saved to the `Logs/` directory as CSV files:

- `provisioning_summary_YYYYMMDD_HHMMSS.csv` — Full audit trail of provisioning run
- `device_audit_YYYYMMDD_HHMMSS.csv` — Device recovery audit results

Each row contains: **Timestamp, Device Serial, Operation, Status, Message**

---

## ⚙️ Architecture

### Project Structure
```
UbosProvisioner/
├── Models/                 # Data models (DeviceInfo, ProvisioningConfig, etc.)
├── Services/               # Core business logic
│   ├── AdbService          # ADB process wrapper + device polling
│   ├── ProvisioningService # APK install, data push, user creation
│   ├── DeProvisioningService # Data pull, factory reset
│   ├── DeviceAuditService  # Lock detection, MDM audit, FRP check
│   ├── ReportingService    # CSV export
│   └── ProvisioningProfileService # Save/load configs
├── ViewModels/             # MVVM view models
├── Views/                  # XAML UI pages
├── Converters/             # Value converters (InverseBoolConverter)
├── platform-tools/         # Bundled adb.exe (not included in this repo)
├── Logs/                   # Operation reports (auto-created)
├── appsettings.json        # App configuration
└── App.xaml.cs             # DI container setup
```

### Tech Stack
- **Framework**: .NET 10 (net10.0-windows)
- **UI**: WPF + MVVM
- **Concurrency**: `Task.WhenAll` + `SemaphoreSlim`
- **DI**: Microsoft.Extensions.DependencyInjection
- **Config**: Microsoft.Extensions.Configuration
- **Reporting**: CsvHelper
- **MVVM Toolkit**: CommunityToolkit.Mvvm (source generators for `[ObservableProperty]`)

---

## 🔒 Security Notes

### What This Tool CANNOT Do
- **Bypass FRP (Factory Reset Protection)**: Android 6+ requires original Google account after reset
- **Remove MDM/Device Admin unilaterally**: Only IT admin console can unenroll
- **Unlock screen without credentials**: Encrypted storage prevents ADB access to lock files on Android 6+

### What This Tool CAN Do
- **Clear screen lock if PIN is known**: Via `adb shell locksettings clear --old <pin>`
- **Reboot to manual recovery**: Operator completes wipe manually on device
- **Detect and diagnose**: Tell you exactly WHY a device can't be recovered

---

## 📝 Troubleshooting

### Devices Not Showing Up
- Ensure **USB Debugging is enabled** on Android device
- Check **Developer Options** → enable **USB Debugging**
- Verify USB cable is data-capable (not charge-only)
- Run `Refresh Devices` button

### APK Install Fails
- Verify `.apk` file path exists
- Check device has sufficient storage
- Ensure APK is signed correctly

### FRP / MDM Lock
- **Google Workspace**: Contact IT → `admin.google.com` → Devices → Wipe
- **Microsoft Intune**: Contact IT → `portal.azure.com` → Device Management
- **Samsung Knox**: Contact IT → Knox Matrix console

---

## 🛠️ Development

### Build from Source
```powershell
cd UbosProvisioner
dotnet build
dotnet run
```

### Publish Self-Contained Executable
```powershell
dotnet publish -c Release -r win-x64 --self-contained
```
Output: `bin\Release\net10.0-windows\win-x64\publish\UbosProvisioner.exe`
- Single `.exe` file
- No .NET runtime required on target machine

---

## 📞 Support

For issues with:
- **ADB connectivity**: Check USB drivers and Developer Options
- **Device lock**: Use Device Recovery tab for diagnosis
- **App crashes**: Check the error message dialog and logs

---

## ✅ Implementation Status

| Milestone | Feature | Status |
|---|---|---|
| 1 | Foundation & Scaffolding | ✅ Complete |
| 2 | ADB Service Layer | ✅ Complete |
| 3 | Provisioning Engine | ✅ Complete |
| 4 | De-Provisioning Engine | ✅ Complete |
| 5 | Settings/Logs/Info Tabs | ✅ Complete |
| 6 | Device Recovery & Audit | ✅ Complete |
| 7 | Reporting & Polish | ✅ Complete |

---

**Last Updated**: April 1, 2026  
**Built With**: Claude Code + Claude Sonnet 4.6
