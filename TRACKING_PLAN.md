# UBOS Device Provisioner — Master Tracking Plan
> Living document. Update status as milestones are completed.
> Tech Stack: C# .NET 8 · WinUI 3 (Windows App SDK) · MVVM · ADB

---

## Token-Saving Workflow
- Use `/model haiku` during active code generation (boilerplate, scaffolding, XAML templates)
- Use `/model default` (Sonnet) for architecture, debugging, planning

---

## Milestone Overview

| # | Milestone | Status | Est. Days |
|---|-----------|--------|-----------|
| 1 | Foundation & Project Scaffolding | ⬜ Not Started | 1–3 |
| 2 | ADB Service Layer | ⬜ Not Started | 4–6 |
| 3 | Provisioning Engine | ⬜ Not Started | 7–9 |
| 4 | De-Provisioning Engine | ⬜ Not Started | 10–11 |
| 5 | UI Layer (All Tabs) | ⬜ Not Started | 12–14 |
| 6 | Device Recovery & Audit Tab | ⬜ Not Started | 15–16 |
| 7 | Reporting, Polish & Build | ⬜ Not Started | 17–18 |

Status legend: ⬜ Not Started · 🔄 In Progress · ✅ Complete · 🚫 Blocked

---

## Milestone 1 — Foundation & Project Scaffolding
**Goal:** Runnable blank WinUI 3 shell, embedded tools, config system.

| Task | Status | Notes |
|------|--------|-------|
| 1.1 Create WinUI 3 solution (MVVM structure) | ⬜ | `UbosProvisioner.sln` with `App`, `ViewModels`, `Services`, `Models` folders |
| 1.2 Add NuGet packages | ⬜ | `Microsoft.WindowsAppSDK`, `CommunityToolkit.Mvvm`, `Microsoft.Extensions.Configuration.Json` |
| 1.3 Bundle `platform-tools/adb.exe` | ⬜ | Add as "Copy to Output Directory: Copy if Newer" |
| 1.4 Implement `appsettings.json` + `AppConfig` model | ⬜ | Mirror Python `config_loader.py`; keys: `MaxConcurrentDevices`, `LogsDirectory`, `PlatformToolsPath` |
| 1.5 Verify app launches with blank window | ⬜ | Smoke test |

---

## Milestone 2 — ADB Service Layer
**Goal:** All ADB interactions go through one typed service; no raw strings in the UI.

| Task | Status | Notes |
|------|--------|-------|
| 2.1 `AdbService` class — process wrapper | ⬜ | `System.Diagnostics.Process`, capture stdout/stderr via events |
| 2.2 `AdbService.RunAsync()` — generic command runner | ⬜ | Returns `AdbResult { ExitCode, Output, Error }` |
| 2.3 `GetConnectedDevicesAsync()` | ⬜ | Parses `adb devices` output into `List<DeviceInfo>` |
| 2.4 Background device polling (every 5s) | ⬜ | `PeriodicTimer` → updates `ObservableCollection<DeviceInfo>` |
| 2.5 `DeviceInfo` model | ⬜ | Properties: `Serial`, `Model`, `BatteryLevel`, `StorageFree`, `ConnectionState` |
| 2.6 Unit-testable: mock ADB responses | ⬜ | Extract `IAdbService` interface for testability |

---

## Milestone 3 — Provisioning Engine
**Goal:** Full provisioning pipeline matching Python `provision_engine.py` behavior exactly.

| Task | Status | Notes |
|------|--------|-------|
| 3.1 `ProvisioningService` — orchestrator | ⬜ | `SemaphoreSlim` + `Task.WhenAll` enforcing `MaxConcurrentDevices` |
| 3.2 `InstallApkAsync()` | ⬜ | Validates `.apk` exists → `adb install -r` |
| 3.3 `PushFolderAsync()` — NPHC data | ⬜ | `adb push` to `/sdcard/Android/data/...` |
| 3.4 TPK distribution logic | ⬜ | `random`, `sequential`, `round-robin` modes; matches Python math exactly |
| 3.5 `CreateUserAsync()` | ⬜ | `adb shell pm create-user Enumerator` |
| 3.6 `SetScreenTimeoutAsync()` | ⬜ | `adb shell settings put system screen_off_timeout` |
| 3.7 `CaptureScreenshotAsync()` | ⬜ | `adb shell screencap` → `adb pull` to local QC folder |
| 3.8 Pre-flight checks (battery, storage, APK validity) | ⬜ | NEW: warn if battery <30% or storage <500MB |
| 3.9 Progress event stream | ⬜ | `IProgress<ProvisioningUpdate>` fed to UI in real-time |

---

## Milestone 4 — De-Provisioning Engine
**Goal:** Secure data extraction and device wipe pipeline.

| Task | Status | Notes |
|------|--------|-------|
| 4.1 `DeProvisioningService` — orchestrator | ⬜ | Same `SemaphoreSlim` concurrency pattern as Milestone 3 |
| 4.2 `PullDataAsync()` | ⬜ | `adb pull` sensitive survey/census data to timestamped local folder |
| 4.3 `FactoryResetAsync()` | ⬜ | `adb shell recovery --wipe_data` post-extraction; surface FRP warning to operator |
| 4.4 FRP warning dialog | ⬜ | Before reset, warn: "If a Google/MDM account is signed in, FRP will activate after reset." |

---

## Milestone 5 — UI Layer (All Tabs)
**Goal:** Full XAML UI matching the current Python `#F8FAFC` light-theme layout.

| Task | Status | Notes |
|------|--------|-------|
| 5.1 Main shell (NavigationView + TabView) | ⬜ | Tabs: Provision · De-Provision · Device Audit · Logs · Settings |
| 5.2 Provisioning Tab | ⬜ | Device checkbox grid, APK picker, NPHC/TPK folder pickers, Run button |
| 5.3 De-Provisioning Tab | ⬜ | Device checkbox grid, output path picker, Run button |
| 5.4 Logs Tab | ⬜ | `RichTextBox` real-time console; `Dispatcher` for thread-safe updates |
| 5.5 Settings Tab | ⬜ | `MaxConcurrentDevices`, paths, theme toggle; persists to `appsettings.json` |
| 5.6 Device grid — `ObservableCollection` binding | ⬜ | Auto-refreshes from Milestone 2 polling |
| 5.7 Global progress bar + status bar | ⬜ | Shows active operation + device count |

---

## Milestone 6 — Device Recovery & Audit Tab *(New Feature)*
**Goal:** Help IT staff diagnose and recover locked/repurposing-blocked tablets.

> **Hard limits (do not attempt to implement):**
> - FRP bypass — not possible without original Google account credentials
> - Screen lock bypass without credentials (Android 6+)
> - MDM force-removal (Intune, Google Workspace, Knox)

| Task | Status | Notes |
|------|--------|-------|
| 6.1 Lock status detection | ⬜ | `adb shell locksettings get-disabled` → display to operator |
| 6.2 Device admin / MDM audit | ⬜ | `adb shell dumpsys device_policy` → list enrolled admins |
| 6.3 FRP status check | ⬜ | `adb shell settings get secure user_setup_complete` → flag if account signed in |
| 6.4 Battery + storage quick-audit | ⬜ | `adb shell dumpsys battery` + `adb shell df /sdcard` |
| 6.5 Credential-based lock clear | ⬜ | If operator knows PIN: `adb shell locksettings clear --old <pin>` |
| 6.6 Reboot to recovery (manual wipe path) | ⬜ | `adb reboot recovery` — operator completes wipe manually on device |
| 6.7 Guided MDM remediation instructions | ⬜ | Based on audit results, show actionable steps: "Go to admin.google.com → Devices → Wipe" etc. |
| 6.8 Audit report export | ⬜ | Save per-device audit results to CSV |

---

## Milestone 7 — Reporting, Polish & Build
**Goal:** Shippable single `.exe` with full logging and notifications.

| Task | Status | Notes |
|------|--------|-------|
| 7.1 Session summary CSV writer | ⬜ | `provisioning_summary_[timestamp].csv` → `Serial`, `Status`, `Message`, `Errors` |
| 7.2 Toast notifications | ⬜ | `Microsoft.Windows.AppNotifications` (WinAppSDK) replacing Python fallback |
| 7.3 APN / network config UI | ⬜ | NEW: Form-based APN settings replacing raw `.ps1` scripts |
| 7.4 Device profile templates | ⬜ | NEW: Save/load named provisioning configs as JSON |
| 7.5 Batch serial number import | ⬜ | NEW: Import expected device list from CSV; flag missing/unexpected devices |
| 7.6 Self-contained publish profile | ⬜ | `.pubxml` → single `.exe`, no .NET runtime required on target machine |
| 7.7 Final smoke test — full provision + de-provision cycle | ⬜ | End-to-end validation |

---

## Architecture Notes

```
UbosProvisioner/
├── App.xaml / App.xaml.cs
├── MainWindow.xaml
├── appsettings.json
├── platform-tools/          ← adb.exe bundled here
├── Models/
│   ├── DeviceInfo.cs
│   ├── AdbResult.cs
│   ├── ProvisioningConfig.cs
│   └── DeviceAuditReport.cs
├── Services/
│   ├── IAdbService.cs
│   ├── AdbService.cs
│   ├── ProvisioningService.cs
│   ├── DeProvisioningService.cs
│   └── DeviceAuditService.cs
├── ViewModels/
│   ├── MainViewModel.cs
│   ├── ProvisioningViewModel.cs
│   ├── DeProvisioningViewModel.cs
│   ├── DeviceAuditViewModel.cs
│   ├── LogsViewModel.cs
│   └── SettingsViewModel.cs
└── Views/
    ├── ProvisioningPage.xaml
    ├── DeProvisioningPage.xaml
    ├── DeviceAuditPage.xaml
    ├── LogsPage.xaml
    └── SettingsPage.xaml
```

---

## NuGet Dependencies

| Package | Purpose |
|---------|---------|
| `Microsoft.WindowsAppSDK` | WinUI 3 runtime |
| `CommunityToolkit.Mvvm` | MVVM source generators (`[ObservableProperty]`, `[RelayCommand]`) |
| `Microsoft.Extensions.Configuration.Json` | `appsettings.json` config |
| `Microsoft.Extensions.DependencyInjection` | DI container |
| `CsvHelper` | CSV report generation |

---

*Last updated: 2026-03-31*
