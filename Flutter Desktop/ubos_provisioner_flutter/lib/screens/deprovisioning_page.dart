import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../widgets/device_table.dart';
import '../widgets/log_panel.dart';
import '../widgets/common.dart';

class DeProvisioningPage extends StatefulWidget {
  const DeProvisioningPage({super.key});

  @override
  State<DeProvisioningPage> createState() => _DeProvisioningPageState();
}

class _DeProvisioningPageState extends State<DeProvisioningPage> {
  final _outputCtrl = TextEditingController();
  bool _factoryReset = false;

  @override
  void dispose() {
    _outputCtrl.dispose();
    super.dispose();
  }

  Future<void> _browseOutput() async {
    final path =
        await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Output Folder');
    if (path != null) setState(() => _outputCtrl.text = path);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isRunning = state.status == OperationStatus.deprovisioning;

    return TwoPaneLayout(
      leftTitle: 'De-provision Config',
      rightTitle: 'Devices & Progress',
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConfigSection(
            title: 'Extract Data Output',
            description: 'Where extracted survey/census data will be saved.',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _outputCtrl,
                    enabled: !isRunning,
                    decoration: const InputDecoration(
                      labelText: 'Output folder',
                      hintText: r'D:\exports\',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isRunning ? null : _browseOutput,
                  child: const Text('Browse'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_factoryReset)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Factory reset is destructive and irreversible. '
                        'The app will check for FRP/MDM conditions. '
                        'Ensure data extraction succeeds before wiping.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_factoryReset) const SizedBox(height: 12),
          SwitchListTile(
            value: _factoryReset,
            onChanged: isRunning ? null : (v) => setState(() => _factoryReset = v),
            title: const Text('Factory reset after extraction'),
            subtitle: const Text('Only if extraction succeeds and device is eligible.'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: isRunning
                    ? null
                    : () {
                        final output = _outputCtrl.text.trim();
                        if (output.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please select an output folder first.')),
                          );
                          return;
                        }
                        state.startDeProvisioning(output, _factoryReset);
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start De-provisioning'),
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
