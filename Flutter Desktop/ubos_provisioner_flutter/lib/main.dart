import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'providers/settings_provider.dart';
import 'screens/provisioning_page.dart';
import 'screens/deprovisioning_page.dart';
import 'screens/audit_recovery_page.dart';
import 'screens/logs_reports_page.dart';
import 'screens/device_info_page.dart';
import 'screens/settings_page.dart';
import 'widgets/log_panel.dart';
import 'widgets/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProxyProvider<SettingsProvider, AppState>(
          create: (_) => AppState(settingsProvider),
          update: (_, sp, prev) {
            prev?.updateSettings(sp);
            return prev!;
          },
        ),
      ],
      child: const UbosProvisionerApp(),
    ),
  );
}

class UbosProvisionerApp extends StatelessWidget {
  const UbosProvisionerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;
    return MaterialApp(
      title: 'UBOS Device Provisioner',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  static const _destinations = <_NavDestination>[
    _NavDestination(label: 'Home', icon: Icons.home_outlined),
    _NavDestination(label: 'Provision', icon: Icons.playlist_add_check),
    _NavDestination(label: 'De-provision', icon: Icons.delete_sweep),
    _NavDestination(label: 'Audit/Recovery', icon: Icons.health_and_safety),
    _NavDestination(label: 'Logs/Reports', icon: Icons.receipt_long),
    _NavDestination(label: 'Device Info', icon: Icons.devices),
    _NavDestination(label: 'Settings', icon: Icons.settings),
  ];

  Widget _buildPage(int index) {
    return switch (index) {
      0 => const _HomePage(),
      1 => const ProvisioningPage(),
      2 => const DeProvisioningPage(),
      3 => const AuditRecoveryPage(),
      4 => const LogsReportsPage(),
      5 => const DeviceInfoPage(),
      6 => const SettingsPage(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopLayout = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<AppState>();
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      body: Column(
        children: [
          _GlobalTopBar(isRunning: state.isRunning),
          Expanded(
            child: Row(
              children: [
                if (isDesktopLayout)
                  _Sidebar(
                    selectedIndex: _selectedIndex,
                    onSelectedIndexChanged: (i) =>
                        setState(() => _selectedIndex = i),
                    searchController: _searchController,
                    deviceCount: state.devices.length,
                    isPolling: state.isPolling,
                  ),
                Expanded(
                  child: _PageScaffold(
                    title: destination.label,
                    onRefresh: state.refreshDevices,
                    child: _buildPage(_selectedIndex),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktopLayout
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;

  const _NavDestination({required this.label, required this.icon});
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onRefresh;

  const _PageScaffold({
    required this.title,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Refresh devices',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _GlobalTopBar extends StatelessWidget {
  final bool isRunning;

  const _GlobalTopBar({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 3,
            child: isRunning
                ? const LinearProgressIndicator()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withAlpha(90),
                    ),
                  ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const _BrandLogo(size: 16),
                const SizedBox(width: 8),
                const Text(
                  'UBOS Provisioner',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (isRunning)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Running',
                          style: TextStyle(
                              fontSize: 12, color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final double size;
  const _BrandLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    // Try common logo filenames under /lib/favicon first.
    const candidates = [
      'lib/favicon/logo.png',
      'lib/favicon/icon.png',
      'lib/favicon/favicon.png',
      'lib/favicon/android-chrome-192x192.png',
      'lib/favicon/android-chrome-512x512.png',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Icon(Icons.usb, size: size, color: Theme.of(context).colorScheme.primary);
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final TextEditingController searchController;
  final int deviceCount;
  final bool isPolling;

  const _Sidebar({
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    required this.searchController,
    required this.deviceCount,
    required this.isPolling,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHighest.withAlpha(140);

    Widget navTile({
      required int index,
      required IconData icon,
      required String label,
      Widget? trailing,
    }) {
      final selected = selectedIndex == index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: selected ? scheme.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelectedIndexChanged(index),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget sectionLabel(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  navTile(
                      index: 0, icon: Icons.home_outlined, label: 'Home'),
                  navTile(
                      index: 1,
                      icon: Icons.playlist_add_check,
                      label: 'Provision'),
                  navTile(
                      index: 2,
                      icon: Icons.delete_sweep,
                      label: 'De-provision'),
                  navTile(
                      index: 3,
                      icon: Icons.health_and_safety,
                      label: 'Audit/Recovery'),
                  sectionLabel('Operations'),
                  navTile(
                      index: 4,
                      icon: Icons.receipt_long,
                      label: 'Logs/Reports'),
                  navTile(
                    index: 5,
                    icon: Icons.devices,
                    label: 'Device Info',
                    trailing: deviceCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$deviceCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          )
                        : null,
                  ),
                  sectionLabel('Admin'),
                  navTile(
                      index: 6, icon: Icons.settings, label: 'Settings'),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.usb, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'USB / ADB',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPolling
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPolling) ...[
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isPolling ? 'Polling' : 'Idle',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: isPolling
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Page ───────────────────────────────────────────────────────────────

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              title: 'Connected Devices',
              value: '${state.devices.length}',
              icon: Icons.devices,
              color: Colors.blue,
            ),
            _StatCard(
              title: 'Ready',
              value:
                  '${state.devices.where((d) => d.statusLabel == 'Ready').length}',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _StatCard(
              title: 'Log Entries',
              value: '${state.logs.length}',
              icon: Icons.receipt_long,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionCard(
              title: 'Refresh Devices',
              subtitle: 'Scan USB for connected Android tablets',
              icon: Icons.refresh,
              onTap: state.refreshDevices,
            ),
            _QuickActionCard(
              title: 'Start Provisioning',
              subtitle: 'Install APKs and push data to selected devices',
              icon: Icons.playlist_add_check,
              onTap: null,
            ),
            _QuickActionCard(
              title: 'Audit a Device',
              subtitle: 'Check lock/MDM/FRP signals and recover',
              icon: Icons.health_and_safety,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const LogPanel(height: 320),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 300),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
