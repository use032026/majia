import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/features/settings/presentation/settings_page.dart';
import 'package:trip_cost/l10n/app_localizations.dart';

import '../../../helpers/isolated_test_database.dart';
import '../../../helpers/m4_fakes.dart';

void main() {
  testWidgets('secondary categories cover the persistent bottom navigation', (
    tester,
  ) async {
    final database = createIsolatedTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Column(
            children: <Widget>[
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => CupertinoPageRoute<void>(
                    builder: (_) => const SettingsPage(),
                  ),
                ),
              ),
              const Text('persistent-bottom-navigation'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('persistent-bottom-navigation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-category-currency-rates')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('currency-rates-settings-list')),
      findsOneWidget,
    );
    expect(find.text('persistent-bottom-navigation'), findsNothing);
  });

  testWidgets('currency details move to a secondary page and stay aligned', (
    tester,
  ) async {
    final database = createIsolatedTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('货币与汇率'), findsOneWidget);
    expect(find.text('默认本位币'), findsNothing);
    expect(find.text('仅在 Wi-Fi 下刷新汇率'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-currency-rates')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('currency-rates-settings-list')),
      findsOneWidget,
    );
    expect(find.text('默认本位币'), findsOneWidget);
    expect(find.text('仅在 Wi-Fi 下刷新汇率'), findsOneWidget);

    double trailingChevronX(String value) {
      final button = find.ancestor(
        of: find.text(value),
        matching: find.byType(CupertinoButton),
      );
      final chevron = find.descendant(
        of: button,
        matching: find.byIcon(CupertinoIcons.chevron_forward),
      );
      return tester.getCenter(chevron).dx;
    }

    final defaultCurrencyChevronX = trailingChevronX('CNY');
    expect(trailingChevronX('每 6 小时'), closeTo(defaultCurrencyChevronX, 0.1));
  });

  testWidgets('settings remain navigable at large text with button semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final database = createIsolatedTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CupertinoApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-category-data')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('settings-category-list')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Data, backup, and export')),
      findsWidgets,
    );
    expect(find.text('Export expenses as CSV'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data-settings-list')), findsOneWidget);
    expect(find.bySemanticsLabel('Export expenses as CSV'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('favorite setting is removed and default uses shared picker', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.padding = const FakeViewPadding(bottom: 102);
    final database = createIsolatedTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorite currencies'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-category-currency-rates')));
    await tester.pumpAndSettle();

    final defaultCurrency = find.text('Default home currency');
    await tester.ensureVisible(defaultCurrency);
    await tester.tap(defaultCurrency);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPopupSurface), findsNothing);
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.text('Common trading currencies'), findsOneWidget);
    expect(find.text('All trading currencies'), findsOneWidget);
    expect(find.byKey(const Key('currency-option-CNY')), findsOneWidget);
    final list = tester.widget<ListView>(
      find.byKey(const Key('currency-directory-list')),
    );
    final padding = (list.padding! as EdgeInsetsDirectional).resolve(
      TextDirection.ltr,
    );
    expect(padding.bottom, 50);
    expect(padding.right, 28);
  });
}
