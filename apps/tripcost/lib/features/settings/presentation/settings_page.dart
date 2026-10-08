import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/features/payment_method/presentation/payment_methods_page.dart';
import 'package:trip_cost/features/settings/application/general_settings_controller.dart';
import 'package:trip_cost/features/settings/application/sync_settings_controller.dart';
import 'package:trip_cost/features/settings/presentation/settings_detail_pages.dart';
import 'package:trip_cost/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final settingsState = ref.watch(generalSettingsControllerProvider);
    final syncState = ref.watch(syncSettingsControllerProvider);
    final settings = settingsState.value;
    final sync = syncState.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(localizations.settingsTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('settings-category-list'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.large,
            AppSpacing.medium,
            AppSpacing.large,
          ),
          children: <Widget>[
            _SettingsCategoryGroup(
              title: localizations.settingsSectionCommon,
              children: <Widget>[
                _SettingsCategoryRow(
                  key: const Key('settings-category-payment-methods'),
                  icon: CupertinoIcons.creditcard,
                  title: localizations.paymentMethodsTitle,
                  subtitle: localizations.settingsPaymentMethodsSummary,
                  onPressed: () =>
                      _pushRoot(context, const PaymentMethodsPage()),
                ),
                _SettingsCategoryRow(
                  key: const Key('settings-category-currency-rates'),
                  icon: CupertinoIcons.money_dollar_circle,
                  title: localizations.rateSettingsTitle,
                  subtitle: settings == null
                      ? '—'
                      : '${settings.defaultCurrency.code} · '
                            '${localizations.refreshEveryHours(settings.refreshInterval.inHours)}',
                  onPressed: () =>
                      _pushRoot(context, const CurrencyAndRatesSettingsPage()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _SettingsCategoryGroup(
              title: localizations.settingsSectionDataDevices,
              children: <Widget>[
                _SettingsCategoryRow(
                  key: const Key('settings-category-icloud-sync'),
                  icon: CupertinoIcons.cloud,
                  title: localizations.syncTitle,
                  subtitle: sync == null
                      ? '—'
                      : sync.enabled
                      ? localizations.syncStatusEnabledShort
                      : localizations.syncStatusDisabledShort,
                  onPressed: () =>
                      _pushRoot(context, const CloudSyncSettingsPage()),
                ),
                _SettingsCategoryRow(
                  key: const Key('settings-category-data'),
                  icon: CupertinoIcons.archivebox,
                  title: localizations.dataTitle,
                  subtitle: localizations.settingsDataSummary,
                  onPressed: () => _pushRoot(context, const DataSettingsPage()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _SettingsCategoryGroup(
              title: localizations.settingsSectionGeneral,
              children: <Widget>[
                _SettingsCategoryRow(
                  key: const Key('settings-category-language'),
                  icon: CupertinoIcons.globe,
                  title: localizations.languageTitle,
                  subtitle: _languageLabel(
                    localizations,
                    settings?.languageMode,
                  ),
                  onPressed: () =>
                      _pushRoot(context, const LanguageSettingsPage()),
                ),
                _SettingsCategoryRow(
                  key: const Key('settings-category-privacy'),
                  icon: CupertinoIcons.lock_shield,
                  title: localizations.privacyTitle,
                  subtitle: localizations.settingsPrivacySummary,
                  onPressed: () =>
                      _pushRoot(context, const PrivacySettingsPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _pushRoot(BuildContext context, Widget page) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(CupertinoPageRoute<void>(builder: (context) => page));
  }

  static String _languageLabel(
    AppLocalizations localizations,
    AppLanguageMode? mode,
  ) {
    return switch (mode) {
      AppLanguageMode.system => localizations.systemLanguage,
      AppLanguageMode.simplifiedChinese => localizations.simplifiedChinese,
      AppLanguageMode.english => localizations.english,
      null => '—',
    };
  }
}

class _SettingsCategoryGroup extends StatelessWidget {
  const _SettingsCategoryGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 10),
          child: Text(
            title,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 70),
                      child: SizedBox(
                        height: 0.5,
                        child: ColoredBox(color: separator),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCategoryRow extends StatelessWidget {
  const _SettingsCategoryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '$title, $subtitle',
      child: ExcludeSemantics(
        child: CupertinoButton(
          minimumSize: const Size.fromHeight(78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          onPressed: onPressed,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 42,
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
