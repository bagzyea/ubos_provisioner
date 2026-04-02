import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../providers/settings_provider.dart';
import '../widgets/log_panel.dart';

class LogsReportsPage extends StatelessWidget {
  const LogsReportsPage({super.key});

  Future<void> _openLogsFolder(BuildContext context, String logsDir) async {
    final dir = logsDir.isNotEmpty ? logsDir : 'Logs';
    try {
      await Directory(dir).create(recursive: true);
      final uri = Uri.directory(dir);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open folder: $dir')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = context.watch<SettingsProvider>().settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _openLogsFolder(context, settings.logsDirectory),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Logs Folder'),
            ),
            OutlinedButton.icon(
              onPressed: state.logs.isEmpty
                  ? null
                  : () async {
                      final path = await state.exportCsv();
                      if (context.mounted && path.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Exported: $path')),
                        );
                      }
                    },
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
            OutlinedButton.icon(
              onPressed: state.logs.isEmpty ? null : state.clearLogs,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Logs'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const LogPanel(height: 520),
      ],
    );
  }
}
