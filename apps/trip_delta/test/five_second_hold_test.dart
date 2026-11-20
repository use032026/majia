import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/five_second_hold.dart';

void main() {
  Future<void> render(WidgetTester tester, VoidCallback onHold) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FiveSecondHold(
              onHold: onHold,
              child: const SizedBox(
                key: Key('hold_area'),
                width: 100,
                height: 50,
              ),
            ),
          ),
        ),
      );
  Offset point(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('hold_area')));

  testWidgets('precise 4999ms/5000ms boundary and one trigger per hold', (
    tester,
  ) async {
    var count = 0;
    await render(tester, () => count++);
    final gesture = await tester.startGesture(point(tester));
    await tester.pump(const Duration(milliseconds: 4999));
    expect(count, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(count, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(count, 1);
    await gesture.up();
  });

  for (final kind in [
    'release',
    'cancel',
    'outside',
    'slop',
    'background',
    'dispose',
    'second_pointer',
  ]) {
    testWidgets('$kind cancels the five-second title hold', (tester) async {
      var count = 0;
      await render(tester, () => count++);
      final gesture = await tester.startGesture(point(tester), pointer: 1);
      await tester.pump(const Duration(seconds: 4));
      switch (kind) {
        case 'release':
          await gesture.up();
        case 'cancel':
          await gesture.cancel();
        case 'outside':
          await gesture.moveTo(point(tester) + const Offset(60, 0));
        case 'slop':
          await gesture.moveBy(const Offset(20, 0));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
        case 'second_pointer':
          final second = await tester.startGesture(
            point(tester) + const Offset(150, 0),
            pointer: 2,
          );
          await second.up();
      }
      await tester.pump(const Duration(seconds: 2));
      expect(count, 0);
      if (kind != 'release' && kind != 'cancel') await gesture.up();
    });
  }
}
