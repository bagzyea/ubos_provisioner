import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/log_entry.dart';

class LogPanel extends StatefulWidget {
  final double height;
  const LogPanel({super.key, this.height = 320});

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final _scrollCtrl = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Color _severityColor(LogSeverity s, ColorScheme cs) => switch (s) {
        LogSeverity.info => cs.onSurface,
        LogSeverity.ok => Colors.green,
        LogSeverity.warn => Colors.orange,
        LogSeverity.error => cs.error,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final logs = state.logs;
    final cs = Theme.of(context).colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Live Log', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Text('(${logs.length})', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Tooltip(
                  message: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
                  child: IconButton(
                    icon: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _autoScroll = !_autoScroll),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: logs.isEmpty
                      ? null
                      : () {
                          final text = logs
                              .map((e) =>
                                  '${e.formattedTime} [${e.severityLabel}] ${e.deviceSerial}: ${e.message}')
                              .join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard.')),
                          );
                        },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: logs.isEmpty ? null : state.clearLogs,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          'No log entries yet.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final entry = logs[index];
                          final color = _severityColor(entry.severity, cs);
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: SizedBox(
                              width: 36,
                              child: Text(
                                entry.severityLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              '${entry.deviceSerial}: ${entry.message}',
                              style: TextStyle(fontSize: 13, color: color),
                            ),
                            subtitle: Text(
                              entry.formattedTime,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
