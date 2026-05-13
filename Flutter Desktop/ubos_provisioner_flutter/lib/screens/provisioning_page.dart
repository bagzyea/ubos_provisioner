import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../models/provisioning_config.dart';
import '../widgets/device_table.dart';
import '../widgets/log_panel.dart';
import '../widgets/common.dart';

class ProvisioningPage extends StatefulWidget {
  const ProvisioningPage({super.key});

  @override
  State<ProvisioningPage> createState() => _ProvisioningPageState();
}

class _ProvisioningPageState extends State<ProvisioningPage> {
  final _appDataCtrl = TextEditingController();
  final _tpkCtrl = TextEditingController();
  final _maxParallelCtrl = TextEditingController(text: '3');
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  TpkDistributionMode _tpkMode = TpkDistributionMode.roundRobin;
  final List<String> _apks = [];
  bool _pinVisible = false;

  @override
  void dispose() {
    _appDataCtrl.dispose();
    _tpkCtrl.dispose();
    _maxParallelCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickApks() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    if (result != null) {
      setState(() => _apks.addAll(result.paths.whereType<String>()));
    }
  }

  Future<void> _browseAppData() async {
    final path =
        await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select App Data Folder');
    if (path != null) setState(() => _appDataCtrl.text = path);
  }

  Future<void> _browseTpk() async {
    final path =
        await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select TPK Folder');
    if (path != null) setState(() => _tpkCtrl.text = path);
  }

  void _startProvisioning(AppState state) {
    final pin = _pinCtrl.text.trim();
    final confirm = _pinConfirmCtrl.text.trim();

    if (pin.isNotEmpty && pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Please check and try again.')),
      );
      return;
    }

    if (pin.isNotEmpty && (pin.length < 4 || pin.length > 6)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4–6 digits.')),
      );
      return;
    }

    final config = ProvisioningConfig(
      apkPaths: List.from(_apks),
      appDataFolder: _appDataCtrl.text.trim(),
      tpkFolder: _tpkCtrl.text.trim(),
      tpkMode: _tpkMode,
      maxParallel: int.tryParse(_maxParallelCtrl.text) ?? 3,
      devicePin: pin,
    );
    state.startProvisioning(config);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isRunning = state.status == OperationStatus.provisioning;

    return TwoPaneLayout(
      leftTitle: 'Provisioning Config',
      rightTitle: 'Devices & Progress',
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConfigSection(
            title: 'APKs',
            description: 'Select one or more APKs to install sequentially per device.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: isRunning ? null : _pickApks,
                      icon: const Icon(Icons.add),
                      label: const Text('Add APKs'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isRunning || _apks.isEmpty
                          ? null
                          : () => setState(() => _apks.clear()),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                if (_apks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _apks
                        .map(
                          (apk) => Chip(
                            label: Text(
                              apk.split(RegExp(r'[/\\]')).last,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onDeleted:
                                isRunning ? null : () => setState(() => _apks.remove(apk)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConfigSection(
            title: 'App Data Folder',
            description: 'Push surveys/configuration to app storage on each device.',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _appDataCtrl,
                    enabled: !isRunning,
                    decoration: const InputDecoration(
                      labelText: 'Folder path',
                      hintText: r'C:\data\surveys\',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isRunning ? null : _browseAppData,
                  child: const Text('Browse'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConfigSection(
            title: 'TPK Distribution',
            description: 'Choose how map tiles are distributed across devices.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TpkDistributionMode>(
                        value: _tpkMode,
                        items: const [
                          DropdownMenuItem(
                              value: TpkDistributionMode.sequential, child: Text('Sequential')),
                          DropdownMenuItem(
                              value: TpkDistributionMode.roundRobin, child: Text('Round-robin')),
                          DropdownMenuItem(
                              value: TpkDistributionMode.random, child: Text('Random')),
                        ],
                        onChanged: isRunning ? null : (v) => setState(() => _tpkMode = v!),
                        decoration:
                            const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _maxParallelCtrl,
                        enabled: !isRunning,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max parallel',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tpkCtrl,
                        enabled: !isRunning,
                        decoration: const InputDecoration(
                          labelText: 'TPK folder',
                          hintText: r'C:\tpk\',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: isRunning ? null : _browseTpk,
                      child: const Text('Browse'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConfigSection(
            title: 'Device PIN Lock',
            description:
                'Set a screen PIN on every device after provisioning. Leave blank to skip.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pinCtrl,
                        enabled: !isRunning,
                        obscureText: !_pinVisible,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'PIN (leave blank to skip)',
                          hintText: '4–6 digits',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _pinVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _pinVisible = !_pinVisible),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pinConfirmCtrl,
                        enabled: !isRunning,
                        obscureText: !_pinVisible,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Confirm PIN',
                          hintText: 'Re-enter PIN',
                          border: const OutlineInputBorder(),
                          suffixIcon: ValueListenableBuilder(
                            valueListenable: _pinConfirmCtrl,
                            builder: (_, __, ___) {
                              final match = _pinCtrl.text == _pinConfirmCtrl.text;
                              final bothFilled = _pinCtrl.text.isNotEmpty &&
                                  _pinConfirmCtrl.text.isNotEmpty;
                              if (!bothFilled) return const SizedBox.shrink();
                              return Icon(
                                match ? Icons.check_circle : Icons.cancel,
                                color: match ? Colors.green : Colors.red,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_pinCtrl.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'PIN will be set on all selected devices after provisioning.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: isRunning ? null : () => _startProvisioning(state),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Provisioning'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: isRunning ? state.requestCancel : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
              if (isRunning) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text('Running...'),
              ],
            ],
          ),
        ],
      ),
      right: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeviceTable(),
          SizedBox(height: 12),
          LogPanel(),
        ],
      ),
    );
  }
}
