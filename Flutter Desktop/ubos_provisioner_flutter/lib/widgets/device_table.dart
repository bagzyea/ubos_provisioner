import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/device_info.dart';

class DeviceTable extends StatelessWidget {
  const DeviceTable({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devices = state.devices;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Connected Devices', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (state.isPolling)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Polling'),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: state.refreshDevices,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => state.selectAll(true),
                  child: const Text('All'),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => state.selectAll(false),
                  child: const Text('None'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No devices connected. Click Refresh or enable polling in the sidebar.'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Select')),
                    DataColumn(label: Text('Serial')),
                    DataColumn(label: Text('Model')),
                    DataColumn(label: Text('Google Account')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Progress')),
                  ],
                  rows: devices.map((d) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Checkbox(
                            value: d.isSelected,
                            onChanged: d.status == DeviceStatus.busy
                                ? null
                                : (_) => state.toggleDeviceSelection(d.serial),
                          ),
                        ),
                        DataCell(SelectableText(d.serial)),
                        DataCell(Text(d.model)),
                        DataCell(_GoogleAccountChip(status: d.googleAccountStatus)),
                        DataCell(_StatusChip(status: d.status)),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: d.progress),
                                if (d.currentStep.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      d.currentStep,
                                      style: const TextStyle(fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoogleAccountChip extends StatelessWidget {
  final String status;
  const _GoogleAccountChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (color, label) = switch (normalized) {
      'present' => (Colors.red, 'Present'),
      'not present' => (Colors.green, 'Not present'),
      _ => (Colors.grey, 'Unknown'),
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
