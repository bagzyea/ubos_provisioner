# PRD — UBOS Device Provisioner (Flutter Desktop Rewrite)

## Overview
UBOS Device Provisioner is a Windows desktop application used by field operations teams to **provision**, **de-provision**, and **audit/recover** Android tablets used in census/survey field work.

This document defines the Product Requirements for a **Flutter Windows desktop** rewrite of the existing WPF application. The Flutter version must deliver a **modern, polished UI** while maintaining **excellent performance and reliability** for multi-device, ADB-driven workflows.

## Goals
- Provide a **fast, operator-friendly** Windows desktop experience for managing many Android tablets via USB (ADB).
- Achieve **feature parity** with the existing WPF tool (no loss of critical workflows).
- Support **safe, repeatable** operations with strong logging, reporting, and recoverability.
- Deliver a UI that feels **modern and professional**, with clear status, progress, and error guidance.

## Non-Goals
- Bypassing Android security controls (e.g., **FRP bypass**, unlocking without credentials).
- Replacing enterprise MDM solutions (Intune, Google Workspace, Knox). The app may detect/diagnose but cannot unenroll.
- Wireless provisioning (ADB over Wi‑Fi) unless explicitly added later.
- macOS/Linux desktop support in the initial release (architecture should not block future expansion).

## Target Users
- **Provisioning operators**: set up devices quickly and consistently.
- **Supervisors / QC staff**: review results, export reports, investigate failures.
- **IT support**: diagnose device lock/MDM/FRP issues and guide remediation.

## Key Use Cases (Workflows)
### 1) Provision Devices
- Detect connected devices and display device inventory.
- Select multiple devices.
- Configure provisioning inputs:
  - One or more APKs to install (sequential per device).
  - App data folder to push to device app storage (e.g., `/sdcard/Android/data/...`).
  - TPK (map tiles) folder and distribution mode (sequential / round‑robin / random).
  - Device configuration steps (e.g., account/user creation, screen timeout).
- Execute with a configurable concurrency limit (e.g., 1–10, default 3).
- Show per-device progress and a consolidated live log.
- Produce a run summary report (CSV).

### 2) De‑Provision Devices
- Select devices.
- Pull sensitive survey/census data to a timestamped local folder per device/run.
- After successful extraction, optionally trigger factory reset.
- Warn operators about FRP/MDM conditions before wiping.
- Export a de-provisioning report (CSV).

### 3) Device Audit & Recovery
- Audit device state:
  - Screen lock status (locked/unlocked)
  - FRP indicators (Google account present)
  - Device admin / MDM signals (where detectable)
- If PIN is known, attempt lock clearance via supported ADB commands.
- Support reboot to recovery for manual remediation.
- Provide guided instructions for operators based on audit results.

### 4) Settings & Administration
- Configure:
  - Max concurrent devices
  - Device polling interval
  - Logs/reports directory
  - Path to bundled `platform-tools` (adb)
  - Theme (light/dark)
- Save/load “profiles” (repeatable configs) for provisioning.

## Success Metrics
- **Operator throughput**: reduced time to provision a device batch vs baseline.
- **Reliability**: high completion rate for common runs (install APKs + push data) under typical device counts.
- **UI responsiveness**: UI remains responsive under heavy logging and multiple concurrent devices.
- **Observability**: every operation yields actionable logs and an exportable summary.

## Functional Requirements
### Device Discovery & Inventory
- Show a list/grid of ADB-connected devices with:
  - Serial
  - Model / manufacturer (when available)
  - Android version (when available)
  - Battery/state (optional)
  - Storage (optional)
  - Connection/authorization status (unauthorized/offline/ready)
- Manual refresh and periodic polling (configurable).

### Job Execution Engine
- Per-device execution pipeline with:
  - Deterministic step ordering
  - Per-step status (pending/running/success/fail/skipped)
  - Timeouts + retry policy (configurable, with sane defaults)
  - Cancellation per device and “stop all”
- Global concurrency control (max parallel devices).
- Clear separation between:
  - **Plan** (what will run)
  - **Run** (execution state)
  - **Report** (result artifacts)

### Logging & Reporting
- Live log stream view (filterable by device and severity).
- Persist logs to disk in a per-run directory.
- Export run summaries to CSV with:
  - Timestamp, device serial, operation/step, status, message, duration
- Ensure reports are written even on partial failures/cancellation.

### Files & Payloads
- Validate selected files/folders exist and are readable.
- Provide size estimates (optional) and expected duration hints.
- Support large file transfers without UI blocking.
- Ensure the app does not load multi‑GB files into memory.

### UX Requirements
- Primary navigation via tabs/pages:
  - Provisioning
  - De‑Provisioning
  - Device Audit/Recovery
  - Settings
  - Logs/Reports
  - Device Info
- Strong visual hierarchy:
  - Device selection is always clear.
  - Per-device progress is visible during runs.
  - Errors are actionable with suggested remediation.
- Keyboard friendly for operators (tabbing, shortcuts for common actions).
- Theme support (Light/Dark).

## Non-Functional Requirements
### Performance
- UI must stay responsive while:
  - polling devices
  - running concurrent ADB operations
  - streaming logs
- Log UI must be virtualized/bounded (avoid rendering unbounded lines).
- Use asynchronous process I/O; do not block the UI thread.

### Reliability & Safety
- Guardrails for destructive actions (factory reset):
  - confirmation prompts
  - FRP/MDM warning banners when detected
- Clear failure states; never silently ignore errors.
- Robust handling for disconnects during runs.

### Packaging & Deployment (Windows)
- Windows desktop build produced by Flutter.
- Bundle `platform-tools` (`adb.exe` + DLLs) with the app or require a configured path.
- Runs on Windows 10/11.
- Avoid complex install steps; ideally a simple installer or portable folder.

### Security & Compliance
- Do not store sensitive data beyond intended extraction outputs.
- Avoid logging secrets (PINs, account details). If a PIN is entered, treat it as sensitive and do not persist it.
- Ensure extracted data is written to the operator-selected folder with clear naming and timestamps.

## Constraints & Assumptions
- Device communication is via **ADB over USB**.
- Device-side permissions and security policies vary across deployments.
- FRP/MDM limitations are expected and must be communicated in-product.
- Initial scope targets **Windows-only** Flutter desktop.

## Dependencies
- Flutter SDK (Windows desktop enabled)
- Windows build tooling (Visual Studio Build Tools)
- ADB platform tools (`adb.exe`, required DLLs)

## Open Questions (to resolve during implementation)
- Exact list of device configuration steps required for provisioning in your environment (accounts, timeouts, screenshots, etc.).
- Standard target application package names/paths for pushing data (varies by app).
- Which MDM/FRP signals are reliable for your device models/Android versions.
- Preferred Windows look: Material 3 vs Fluent UI (can support both via theming).

## Phased Delivery Plan
### Phase 1 — Foundation
- Flutter Windows app scaffold
- App shell (tabs/pages), theming, routing
- Settings storage (local config) and logs directory management

### Phase 2 — ADB Core
- Bundled `adb` path resolution
- Device discovery + inventory UI
- Command runner with streamed output, timeouts, cancellation

### Phase 3 — Provisioning MVP
- APK install pipeline (per device)
- Push app data folder
- Basic reporting (CSV)

### Phase 4 — De‑Provisioning + Safety
- Pull data
- Factory reset with FRP/MDM warnings
- Reporting + run artifacts

### Phase 5 — Audit/Recovery + Polish
- Audit signals + guided remediation UI
- Per-device progress UX, log filtering, performance hardening

## Acceptance Criteria (high level)
- Can detect multiple connected devices and show their readiness.
- Can provision a selected batch with configurable concurrency, with clear per-device progress and logs.
- Can de-provision (extract + optional wipe) with safety prompts and exported reports.
- UI remains responsive and stable during multi-device runs with heavy logging.
- App can run on a clean Windows machine with documented prerequisites and packaged ADB.

