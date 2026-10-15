import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jufu/photo/app_settings.dart';

void main() {
  testWidgets('version row hides the entry and opens after five seconds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController(
      await SharedPreferences.getInstance(),
    );
    var activations = 0;
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: SettingsPage(onOpenTrade: () async => activations++),
        ),
      ),
    );

    expect(find.text('Trading mode'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final version = find.text('1.0.0');
    var hold = await tester.startGesture(tester.getCenter(version));
    await tester.pump(const Duration(seconds: 4));
    expect(activations, 0);
    await hold.up();
    await tester.pump(const Duration(seconds: 2));
    expect(activations, 0);

    hold = await tester.startGesture(tester.getCenter(version));
    await tester.pump(const Duration(seconds: 5));
    expect(activations, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(activations, 1);
    await hold.up();
    settings.dispose();
  });

  testWidgets('moving the finger cancels the version hold', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController(
      await SharedPreferences.getInstance(),
    );
    var activations = 0;
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: SettingsPage(onOpenTrade: () async => activations++),
        ),
      ),
    );

    final center = tester.getCenter(find.text('1.0.0'));
    final hold = await tester.startGesture(center);
    await hold.moveTo(center + const Offset(30, 0));
    await tester.pump(const Duration(seconds: 5));
    expect(activations, 0);
    await hold.up();

    settings.dispose();
  });
}
