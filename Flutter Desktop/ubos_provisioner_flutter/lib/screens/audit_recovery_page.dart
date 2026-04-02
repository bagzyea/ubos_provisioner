import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/log_panel.dart';
import '../widgets/common.dart';

class AuditRecoveryPage extends StatefulWidget {
  const AuditRecoveryPage({super.key});

  @override
  State<AuditRecoveryPage> createState() => _AuditRecoveryPageState();
}

class _AuditRecoveryPageState extends State<AuditRecoveryPage> {
  final _serialCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _serialCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAuditing = state.status == OperationStatus.auditing;
    final audit = state.lastAudit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 420,
              child: TextField(
                controller: _serialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Device serial',
                  hintText: 'e.g. R5CTxxxxxxx',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed:
                  isAuditing ? null : () => state.auditDevice(_serialCtrl.text.trim()),
              icon: isAuditing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: const Text('Audit Device'),
            ),
            OutlinedButton.icon(
              onPressed: isAuditing
                  ? null
                  : () => state.rebootToRecovery(_serialCtrl.text.trim()),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reboot to Recovery'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audit Result',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (audit == null)
                        Text(
                          'Run audit to populate.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else ...[
                        KeyValueRow(label: 'Device', value: audit.deviceSerial),
                        KeyValueRow(label: 'Screen lock', value: audit.screenLock),
                        KeyValueRow(label: 'FRP', value: audit.frpStatus),
                        KeyValueRow(label: 'MDM', value: audit.mdmStatus),
                        KeyValueRow(label: 'Battery', value: audit.batteryLevel),
                        KeyValueRow(label: 'Storage', value: audit.storageFree),
                        const SizedBox(height: 8),
                        Text('Notes',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(audit.notes),
                        if (audit.remediationSteps.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Remediation Steps',
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          for (final step in audit.remediationSteps)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.arrow_right,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(step)),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unlock (PIN)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          final serial = _serialCtrl.text.trim();
                          final pin = _pinCtrl.text;
                          state.clearDeviceLock(serial, pin);
                          _pinCtrl.clear();
                        },
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Clear Lock'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PIN is treated as sensitive and is not stored.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const LogPanel(height: 240),
      ],
    );
  }
}
