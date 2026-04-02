import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/device_info.dart';
import '../widgets/common.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  String? _selectedSerial;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devices = state.devices;

    final selected = _selectedSerial != null
        ? devices.cast<DeviceInfo?>().firstWhere(
            (d) => d?.serial == _selectedSerial,
            orElse: () => null,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Connected Devices',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (state.isPolling)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text('Polling'),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: state.refreshDevices,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('No devices connected. Click Refresh.')),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Serial')),
                        DataColumn(label: Text('Model')),
                        DataColumn(label: Text('Android')),
                        DataColumn(label: Text('Battery')),
                        DataColumn(label: Text('Storage Free')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: devices.map((d) {
                        final isSelected = d.serial == _selectedSerial;
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (_) =>
                              setState(() => _selectedSerial = d.serial),
                          cells: [
                            DataCell(SelectableText(d.serial)),
                            DataCell(Text(d.model)),
                            DataCell(Text(d.androidVersion)),
                            DataCell(Text(d.batteryLevel)),
                            DataCell(Text(d.storageFree)),
                            DataCell(_StatusChip(status: d.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: selected == null
                ? Text(
                    'Select a device above to view detailed properties.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device Details',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      KeyValueRow(label: 'Serial', value: selected.serial),
                      KeyValueRow(label: 'Model', value: selected.model),
                      KeyValueRow(
                          label: 'Android', value: selected.androidVersion),
                      KeyValueRow(
                          label: 'Battery', value: selected.batteryLevel),
                      KeyValueRow(
                          label: 'Storage Free', value: selected.storageFree),
                      KeyValueRow(
                          label: 'Status', value: selected.statusLabel),
                      if (selected.currentStep.isNotEmpty)
                        KeyValueRow(
                            label: 'Current Step',
                            value: selected.currentStep),
                      if (selected.progress > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(
                              value: selected.progress),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DeviceStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      DeviceStatus.ready => (Colors.green, 'Ready'),
      DeviceStatus.unauthorized => (Colors.orange, 'Unauthorized'),
      DeviceStatus.offline => (Colors.grey, 'Offline'),
      DeviceStatus.busy => (Colors.blue, 'Busy'),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withAlpha(40),
      side: BorderSide(color: color.withAlpha(80)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
