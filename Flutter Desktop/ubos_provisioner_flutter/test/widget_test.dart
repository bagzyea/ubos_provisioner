import 'package:flutter_test/flutter_test.dart';

import 'package:ubos_provisioner_flutter/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UbosProvisionerApp());
    expect(find.text('Provision'), findsWidgets);
  });
}
