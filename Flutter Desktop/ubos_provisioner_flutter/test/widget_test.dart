import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:ubos_provisioner_flutter/main.dart';
import 'package:ubos_provisioner_flutter/providers/app_state.dart';
import 'package:ubos_provisioner_flutter/providers/settings_provider.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settingsProvider = SettingsProvider();
    final appState = AppState(settingsProvider, autoStart: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: appState),
        ],
        child: const UbosProvisionerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });
}
