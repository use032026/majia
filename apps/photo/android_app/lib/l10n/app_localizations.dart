import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ug.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale('en'),
    Locale('ug'),
    Locale('zh'),
  ];

  /// 应用标题
  ///
  /// In zh_Hans, this message translates to:
  /// **'聚福 Lite'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In zh_Hans, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @market.
  ///
  /// In zh_Hans, this message translates to:
  /// **'行情'**
  String get market;

  /// No description provided for @trade.
  ///
  /// In zh_Hans, this message translates to:
  /// **'交易'**
  String get trade;

  /// No description provided for @assets.
  ///
  /// In zh_Hans, this message translates to:
  /// **'资产'**
  String get assets;

  /// No description provided for @mine.
  ///
  /// In zh_Hans, this message translates to:
  /// **'我的'**
  String get mine;

  /// No description provided for @welcome.
  ///
  /// In zh_Hans, this message translates to:
  /// **'欢迎回来'**
  String get welcome;

  /// No description provided for @todayProfit.
  ///
  /// In zh_Hans, this message translates to:
  /// **'今日收益'**
  String get todayProfit;

  /// No description provided for @totalAssets.
  ///
  /// In zh_Hans, this message translates to:
  /// **'总资产'**
  String get totalAssets;

  /// No description provided for @available.
  ///
  /// In zh_Hans, this message translates to:
  /// **'可用'**
  String get available;

  /// No description provided for @marketTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'行情'**
  String get marketTitle;

  /// No description provided for @viewMoreMarket.
  ///
  /// In zh_Hans, this message translates to:
  /// **'查看更多行情'**
  String get viewMoreMarket;

  /// No description provided for @bannerAd.
  ///
  /// In zh_Hans, this message translates to:
  /// **'Banner 广告位'**
  String get bannerAd;

  /// No description provided for @accountOverview.
  ///
  /// In zh_Hans, this message translates to:
  /// **'账户总览'**
  String get accountOverview;

  /// No description provided for @balanceTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'余额'**
  String get balanceTitle;

  /// No description provided for @listTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'列表'**
  String get listTitle;

  /// No description provided for @close.
  ///
  /// In zh_Hans, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In zh_Hans, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh_Hans, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In zh_Hans, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In zh_Hans, this message translates to:
  /// **'出错了'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @account_manage.
  ///
  /// In zh_Hans, this message translates to:
  /// **'账户管理'**
  String get account_manage;

  /// No description provided for @account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @balance.
  ///
  /// In zh_Hans, this message translates to:
  /// **'余额'**
  String get balance;

  /// No description provided for @account_equity.
  ///
  /// In zh_Hans, this message translates to:
  /// **'净值'**
  String get account_equity;

  /// No description provided for @currency_type.
  ///
  /// In zh_Hans, this message translates to:
  /// **'货币类型'**
  String get currency_type;

  /// No description provided for @status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'状态'**
  String get status;

  /// No description provided for @current_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前账户'**
  String get current_account;

  /// No description provided for @switch_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'切换'**
  String get switch_account;

  /// No description provided for @deposit.
  ///
  /// In zh_Hans, this message translates to:
  /// **'入金'**
  String get deposit;

  /// No description provided for @active_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'激活账户'**
  String get active_account;

  /// No description provided for @reset_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重置模拟账户'**
  String get reset_account;

  /// No description provided for @go_to_the_exam.
  ///
  /// In zh_Hans, this message translates to:
  /// **'去考试'**
  String get go_to_the_exam;

  /// No description provided for @promotion_level.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提升等级'**
  String get promotion_level;

  /// No description provided for @to_trade.
  ///
  /// In zh_Hans, this message translates to:
  /// **'去交易'**
  String get to_trade;

  /// No description provided for @retest.
  ///
  /// In zh_Hans, this message translates to:
  /// **'再次挑战'**
  String get retest;

  /// No description provided for @replicating_success.
  ///
  /// In zh_Hans, this message translates to:
  /// **'已复制'**
  String get replicating_success;

  /// No description provided for @load_failed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'加载失败'**
  String get load_failed;

  /// No description provided for @switch_success.
  ///
  /// In zh_Hans, this message translates to:
  /// **'切换账户成功'**
  String get switch_success;

  /// No description provided for @switch_failed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'切换失败'**
  String get switch_failed;

  /// No description provided for @reset_account_success.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重置模拟账户成功'**
  String get reset_account_success;

  /// No description provided for @reset_account_failed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重置模拟账户失败'**
  String get reset_account_failed;

  /// No description provided for @real_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'实盘账户'**
  String get real_account;

  /// No description provided for @trial_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'真实账户'**
  String get trial_account;

  /// No description provided for @demo_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'模拟账号'**
  String get demo_account;

  /// No description provided for @trader_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'交易员'**
  String get trader_account;

  /// No description provided for @option_account.
  ///
  /// In zh_Hans, this message translates to:
  /// **'二元期权'**
  String get option_account;

  /// No description provided for @normal_status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'正常'**
  String get normal_status;

  /// No description provided for @disabled_status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'禁用'**
  String get disabled_status;

  /// No description provided for @cancelled_status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'已注销'**
  String get cancelled_status;

  /// No description provided for @blacklist_status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'黑名单'**
  String get blacklist_status;

  /// No description provided for @unknown_status.
  ///
  /// In zh_Hans, this message translates to:
  /// **'未知'**
  String get unknown_status;

  /// No description provided for @to_be_activated.
  ///
  /// In zh_Hans, this message translates to:
  /// **'待激活'**
  String get to_be_activated;

  /// No description provided for @not_started.
  ///
  /// In zh_Hans, this message translates to:
  /// **'未开始'**
  String get not_started;

  /// No description provided for @in_progress.
  ///
  /// In zh_Hans, this message translates to:
  /// **'进行中'**
  String get in_progress;

  /// No description provided for @passed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'通过'**
  String get passed;

  /// No description provided for @failed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'未通过'**
  String get failed;

  /// No description provided for @fail_the_exam.
  ///
  /// In zh_Hans, this message translates to:
  /// **'未通过考试'**
  String get fail_the_exam;

  /// No description provided for @fail_the_exam_sec.
  ///
  /// In zh_Hans, this message translates to:
  /// **'失败原因'**
  String get fail_the_exam_sec;

  /// No description provided for @reason.
  ///
  /// In zh_Hans, this message translates to:
  /// **'原因'**
  String get reason;

  /// No description provided for @i_know.
  ///
  /// In zh_Hans, this message translates to:
  /// **'知道了'**
  String get i_know;

  /// No description provided for @restart_exam.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重新考试'**
  String get restart_exam;

  /// No description provided for @warning.
  ///
  /// In zh_Hans, this message translates to:
  /// **'警告'**
  String get warning;

  /// No description provided for @reset_account_warning.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重置账户功能将对账户恢复到初始状态，清空交易记录并重置账户初始资金，确定继续吗？'**
  String get reset_account_warning;

  /// No description provided for @operation_switch_trader.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前操作需要切换至交易员账号，是否继续'**
  String get operation_switch_trader;

  /// No description provided for @switch_now.
  ///
  /// In zh_Hans, this message translates to:
  /// **'立即切换'**
  String get switch_now;

  /// No description provided for @not_switch_now.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暂不切换'**
  String get not_switch_now;

  /// No description provided for @languageSet.
  ///
  /// In zh_Hans, this message translates to:
  /// **'语言设置'**
  String get languageSet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ug', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ug':
      return AppLocalizationsUg();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
