# UBOS Provisioner: Native .NET Implementation & Feature Parity Plan

The goal of this migration is to transition the Android Device Provisioner from a Python-scripted PyQt6 GUI into a fully compiled **Standard Microsoft Desktop Application** (C# .NET 8), **without deviating from or losing any existing functionality.**

---

## 🔍 Section 1: Current Application Functionality & Tooling

To guarantee 100% feature parity, we must directly map the following Python behaviors into native C# tools:

### Existing Tech Stack & Tools Used
1. **Core Runtime**: Python 3.x, currently leveraging the PyQt6 framework for the modern graphic interface (`styles/modern_theme.qss`).
2. **Device Interface**: The Android Debug Bridge (`adb.exe` bundled in `platform-tools`). All functional requirements are achieved by spawning headless sub-processes (via Python's `subprocess.run()`) to pass sequential shell commands to target devices.
3. **Concurrency Engine**: `concurrent.futures.ThreadPoolExecutor` handles provisioning operations across multiple devices simultaneously (configurable, e.g., max 3 at a time) to save time while ensuring the UI doesn't freeze.
4. **Data Management**: Python's native `os`, `csv`, and `json` manipulate local log dumping and execute file transfers.
5. **Scripting Extensions**: Occasional PowerShell (`.ps1`) utilization if configuring advanced networking (APN settings) or merging logs.

### Core Feature Parity Requirements

#### 1. Provisioning Capabilities
* **APK Management**: Validating `.apk` archives locally, and asynchronously installing multiple apps simultaneously (`adb install -r`).
* **Data Transfer (NPHC & TPK)**: 
  * Pushing massive structured directories to `/sdcard/Android/data/...` securely (`adb push`). 
  * Mapping specific Map Tiles (TPK) utilizing `random`, `sequential`, or `round-robin` distribution logic inside the loop.
* **Device Configuration**:
  * Silently establishing user accounts (`adb shell pm create-user Enumerator`).
  * Forcing specific UI rules, such as screen timeouts.
  * Capturing and pulling QC screenshots locally to verify install integrity post-execution.

#### 2. De-Provisioning Capabilities
* **Data Extraction**: Pulling highly sensitive census/survey user data and logs off the devices securely securely (`adb pull`).
* **Device Wipe**: Automatically triggering factory resets post-extraction to prepare hardware for the next deployment.

#### 3. Reporting & UX
* **Live Progress**: Capturing `stdout` from the ADB shells and streaming it line-by-line into a graphical scrolling text view. 
* **Session Summaries**: Hooking the return statuses into a `csv` writer post-execution to generate a mapped `Serial`, `Status`, `Message`, and `Errors` readout into a timestamped file within the `Logs/` directory.

---

## 📅 Section 2: Migration Action Plan & Timelines

Below is the definitive step-by-step implementation timeline for porting the Python architecture to .NET 8 cleanly. **Total Estimated Time: 2 Weeks (14 Days).**

### Phase 1: Foundation & Project Scaffolding
**Timeline: Week 1 (Days 1 - 3)**
* **Task 1.1: Solution Initialization**
  * Create the C# .NET 8 WinUI 3 (or WPF) base project implementing the **MVVM (Model-View-ViewModel)** architectural pattern.
* **Task 1.2: Resource Bundling**
  * Replicate the `platform-tools` structure within the new C# project directory as "Copy If Newer" embedded resources. The C# app will dynamically point to this relative path.
* **Task 1.3: Settings State Configuration**
  * Implement `appsettings.json` natively using `Microsoft.Extensions.Configuration` to perfectly mirror your Python `config_loader.py` capabilities.

### Phase 2: Translation of The Execution Engine (`device_utils.py` & `provision_engine.py`)
**Timeline: Week 1 (Days 4 - 7)**
* **Task 2.1: Target ADB Process Wrapper**
  * Build a robust C# `AdbService` class utilizing `System.Diagnostics.Process`.
  * Ensure Standard Output (`stdout`) and Standard Error (`stderr`) are bound safely to C# event handlers so the UI can capture real-time logs cleanly.
* **Task 2.2: Parallel Device Processing**
  * Convert the Python `ThreadPoolExecutor` into native .NET concurrency (`System.Threading.Tasks`).
  * Use `Task.WhenAll` wrapped in a `SemaphoreSlim` limit so the system strictly enforces the maximum concurrent device bounds without throttling USB hardware.
* **Task 2.3: Invocation Pipelines**
  * Map Python functions `install_apk()`, `push_folder()`, `create_user()`, and `take_screenshot()` strictly into identical sequential native C# `async/await` structures sending identical string arguments to the ADB shell.

### Phase 3: The Presentation Layer (XAML UI)
**Timeline: Week 2 (Days 8 - 10)**
* **Task 3.1: XAML Layouts Mapping**
  * Translate the `PyQt` window bounds and layouts directly into native XAML `Grid` and `DataGrid` schemas.
  * Faithfully recreate the **Provisioning Tab**, **De-Provisioning Tab**, **Logs Tab**, and **Settings Tab** matching the current `#F8FAFC` light-theme UI you established.
* **Task 3.2: Console Real-time Dashboards**
  * Implement a `RichTextBox` for the live terminal log, utilizing `.NET` `Dispatcher.Invoke` to guarantee stream updates happen without blocking rendering calls.
* **Task 3.3: Port Distribution Logic**
  * Port over the critical Map Tile (TPK) `round-robin`, `sequential`, and `random` balancing math logic so identical behavior persists when selecting device folders.

### Phase 4: State Management & Device Discovery
**Timeline: Week 2 (Days 11 - 12)**
* **Task 4.1: Reactive Device State Polling**
  * Replicate the manual "Refresh Devices" action sequence. 
  * *Upgrade feature:* Map an internal polling background thread scanning `adb devices` every 5 seconds to automatically bind dynamic connections into an `ObservableCollection<T>` directly wired to the front-end Checkbox grid.

### Phase 5: Refinement, Logging, & Final Build
**Timeline: Week 2 (Days 13 - 14)**
* **Task 5.1: File System I/O Mapping**
  * Faithfully reconstruct the end-of-session `provisioning_summary_[timestamp].csv` creation utilizing `System.IO.StreamWriter`.
* **Task 5.2: Operating System Integration**
  * Switch the fallback Python Toast logic toward native `Microsoft.Toolkit.Uwp.Notifications` libraries.
* **Task 5.3: Build & Distribution Pipeline**
  * Publish the application natively using `.pubxml` configurations yielding a "Self-Contained Deployment" `.exe`. This strips all requirement for users to install Python, pip dependencies, or even .NET Core manually—giving you a 1-click deployment application.
