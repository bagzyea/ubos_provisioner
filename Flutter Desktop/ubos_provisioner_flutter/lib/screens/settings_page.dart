import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/app_state.dart';
import '../models/app_settings.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _maxCtrl = TextEditingController();
  final _pollCtrl = TextEditingController();
  final _logsDirCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _maxCtrl.dispose();
    _pollCtrl.dispose();
    _logsDirCtrl.dispose();
    _platformCtrl.dispose();
    super.dispose();
  }

  void _initFromSettings(AppSettings s) {
    if (_initialized) return;
    _maxCtrl.text = s.maxConcurrentDevices.toString();
    _pollCtrl.text = s.devicePollIntervalMs.toString();
    _logsDirCtrl.text = s.logsDirectory;
    _platformCtrl.text = s.platformToolsPath;
    _initialized = true;
  }

  Future<void> _save(SettingsProvider sp) async {
    final updated = AppSettings(
      maxConcurrentDevices: int.tryParse(_maxCtrl.text) ?? 3,
      devicePollIntervalMs: int.tryParse(_pollCtrl.text) ?? 5000,
      logsDirectory: _logsDirCtrl.text.trim(),
      platformToolsPath: _platformCtrl.text.trim(),
      themeMode: sp.themeMode,
    );
    await sp.update(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final state = context.watch<AppState>();
    _initFromSettings(sp.settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Runtime Settings',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Max concurrent devices',
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(border: OutlineInputBorder()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledField(
                        label: 'Device poll interval (ms)',
                        child: TextField(
                          controller: _pollCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(border: OutlineInputBorder()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Logs directory',
                        child: TextField(
                          controller: _logsDirCtrl,
                          decoration: const InputDecoration(
                            hintText: r'.\Logs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath(
                            dialogTitle: 'Select Logs Directory');
                        if (path != null) setState(() => _logsDirCtrl.text = path);
                      },
                      child: const Text('Browse'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Platform-tools path (adb)',
                        child: TextField(
                          controller: _platformCtrl,
                          decoration: const InputDecoration(
                            hintText: r'.\platform-tools',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath(
                            dialogTitle: 'Select Platform-Tools Directory');
                        if (path != null) setState(() => _platformCtrl.text = path);
                      },
                      child: const Text('Browse'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _save(sp),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest),
                      label: Text('System'),
                    ),
                  ],
                  selected: {sp.themeMode},
                  onSelectionChanged: (modes) => sp.setThemeMode(modes.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device Polling',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: state.isPolling ? null : state.startPolling,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Start Polling'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: state.isPolling ? state.stopPolling : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Stop Polling'),
                    ),
                    const SizedBox(width: 12),
                    if (state.isPolling)
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Polling active'),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
