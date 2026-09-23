import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RoamSum'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @tripsTab.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsTab;

  /// No description provided for @ledgerTab.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @scanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanAction;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Understand the real cost'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert a local price and compare payment methods.'**
  String get homeSubtitle;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsTitle;

  /// No description provided for @tripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trip budgets and offline packs will appear here.'**
  String get tripsSubtitle;

  /// No description provided for @ledgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerTitle;

  /// No description provided for @ledgerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved expenses and actual charges will appear here.'**
  String get ledgerSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Currency, rates, payments, sync, and privacy.'**
  String get settingsSubtitle;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanTitle;

  /// No description provided for @scanPurposeCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get scanPurposeCompare;

  /// No description provided for @scanPurposeRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get scanPurposeRecord;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photograph a price tag or bill, then confirm the price before comparing payment methods.'**
  String get scanSubtitle;

  /// No description provided for @scanRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt or bill to prefill an expense.'**
  String get scanRecordSubtitle;

  /// No description provided for @scanCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get scanCamera;

  /// No description provided for @scanPhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get scanPhotoLibrary;

  /// No description provided for @scanPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Recognition runs on this device. The original image is not uploaded.'**
  String get scanPrivacy;

  /// No description provided for @scanRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing text on this device…'**
  String get scanRecognizing;

  /// No description provided for @scanPreparingExpense.
  ///
  /// In en, this message translates to:
  /// **'Recognizing and preparing the expense…'**
  String get scanPreparingExpense;

  /// No description provided for @scanDetectedPrices.
  ///
  /// In en, this message translates to:
  /// **'Detected prices'**
  String get scanDetectedPrices;

  /// No description provided for @scanDetectedPriceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 price detected} other{{count} prices detected}}'**
  String scanDetectedPriceCount(int count);

  /// No description provided for @scanSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select one price, or select several to add them together.'**
  String get scanSelectHint;

  /// No description provided for @scanLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Low confidence · review this value'**
  String get scanLowConfidence;

  /// No description provided for @scanManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount manually'**
  String get scanManualEntry;

  /// No description provided for @scanManualEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Continue even without an image'**
  String get scanManualEntryHint;

  /// No description provided for @scanRecordManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Add an expense manually'**
  String get scanRecordManualEntry;

  /// No description provided for @scanRecordManualEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Continue without scanning'**
  String get scanRecordManualEntryHint;

  /// No description provided for @scanCameraAction.
  ///
  /// In en, this message translates to:
  /// **'Scan a photo'**
  String get scanCameraAction;

  /// No description provided for @scanRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get scanRetake;

  /// No description provided for @scanPhotoLibraryAction.
  ///
  /// In en, this message translates to:
  /// **'Choose from Photos'**
  String get scanPhotoLibraryAction;

  /// No description provided for @scanManualSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get scanManualSheetTitle;

  /// No description provided for @scanManualSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type the listed price directly'**
  String get scanManualSheetSubtitle;

  /// No description provided for @scanEditSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm price'**
  String get scanEditSheetTitle;

  /// No description provided for @scanEditSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit the recognized result'**
  String get scanEditSheetSubtitle;

  /// No description provided for @scanAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get scanAmount;

  /// No description provided for @scanTransactionCurrency.
  ///
  /// In en, this message translates to:
  /// **'Transaction currency'**
  String get scanTransactionCurrency;

  /// No description provided for @scanChooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose currency'**
  String get scanChooseCurrency;

  /// No description provided for @scanInvalidEdit.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount and choose a currency.'**
  String get scanInvalidEdit;

  /// No description provided for @scanReviewBeforeContinue.
  ///
  /// In en, this message translates to:
  /// **'Check the amount and currency before continuing.'**
  String get scanReviewBeforeContinue;

  /// No description provided for @scanSaveAndUse.
  ///
  /// In en, this message translates to:
  /// **'Save and use'**
  String get scanSaveAndUse;

  /// No description provided for @scanCurrencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a currency for every selected price.'**
  String get scanCurrencyRequired;

  /// No description provided for @scanMixedCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Selected prices use different currencies. Edit them before continuing.'**
  String get scanMixedCurrencies;

  /// No description provided for @scanSelectedTotal.
  ///
  /// In en, this message translates to:
  /// **'Selected total · {currency} {amount}'**
  String scanSelectedTotal(String currency, String amount);

  /// No description provided for @scanContinue.
  ///
  /// In en, this message translates to:
  /// **'Compare payment methods'**
  String get scanContinue;

  /// No description provided for @scanPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access was not granted. Choose the other image source or enter the amount manually.'**
  String get scanPermissionDenied;

  /// No description provided for @permissionCameraUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is unavailable'**
  String get permissionCameraUnavailableTitle;

  /// No description provided for @permissionCameraUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Allow RoamSum to use the camera in Settings, then try again. If access is restricted by Screen Time or device management, change that restriction first.'**
  String get permissionCameraUnavailableBody;

  /// No description provided for @permissionPhotoLibraryUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo access is unavailable'**
  String get permissionPhotoLibraryUnavailableTitle;

  /// No description provided for @permissionPhotoLibraryUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Allow RoamSum to access photos in Settings, then try again. If access is restricted by Screen Time or device management, change that restriction first.'**
  String get permissionPhotoLibraryUnavailableBody;

  /// No description provided for @permissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permissionOpenSettings;

  /// No description provided for @scanImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This image is no longer available. Choose it again or enter the amount manually.'**
  String get scanImageUnavailable;

  /// No description provided for @scanRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be recognized. Try another image or enter the amount manually.'**
  String get scanRecognitionFailed;

  /// No description provided for @scanNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'No prices were found. Try another image or enter the amount manually.'**
  String get scanNoCandidates;

  /// No description provided for @scanRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No reference rate is available for this currency. Enter a manual rate on Home, then try again.'**
  String get scanRateUnavailable;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemLanguage;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @scaffoldNotice.
  ///
  /// In en, this message translates to:
  /// **'Project scaffold ready'**
  String get scaffoldNotice;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get onboardingStart;

  /// No description provided for @onboardingScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Understand prices instantly'**
  String get onboardingScanTitle;

  /// No description provided for @onboardingScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan price tags, menus, and receipts to make foreign prices easier to understand.'**
  String get onboardingScanSubtitle;

  /// No description provided for @onboardingCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare the cost to pay'**
  String get onboardingCompareTitle;

  /// No description provided for @onboardingCompareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include fees and rewards to compare the estimated cost of each payment method.'**
  String get onboardingCompareSubtitle;

  /// No description provided for @onboardingBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep every trip on budget'**
  String get onboardingBudgetTitle;

  /// No description provided for @onboardingBudgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add expenses to a trip and see how much of your travel budget remains.'**
  String get onboardingBudgetSubtitle;

  /// No description provided for @onboardingSetupStart.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get onboardingSetupStart;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Takes about a minute. You can add a trip and payment methods later.'**
  String get onboardingSetupSubtitle;

  /// No description provided for @onboardingSetupProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} complete'**
  String onboardingSetupProgress(int completed, int total);

  /// No description provided for @onboardingSetupEnterHome.
  ///
  /// In en, this message translates to:
  /// **'Enter home'**
  String get onboardingSetupEnterHome;

  /// No description provided for @onboardingSetupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue setup'**
  String get onboardingSetupContinue;

  /// No description provided for @onboardingSetupDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardingSetupDismiss;

  /// No description provided for @onboardingSetupTripNotCreated.
  ///
  /// In en, this message translates to:
  /// **'Not created'**
  String get onboardingSetupTripNotCreated;

  /// No description provided for @onboardingSetupTripCount.
  ///
  /// In en, this message translates to:
  /// **'{count} trips created'**
  String onboardingSetupTripCount(int count);

  /// No description provided for @onboardingSetupPaymentNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get onboardingSetupPaymentNotAdded;

  /// No description provided for @onboardingSetupPaymentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} methods added'**
  String onboardingSetupPaymentCount(int count);

  /// No description provided for @onboardingSetupCurrencySelected.
  ///
  /// In en, this message translates to:
  /// **'{code} · Selected'**
  String onboardingSetupCurrencySelected(String code);

  /// No description provided for @converterInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Local price or expression'**
  String get converterInputLabel;

  /// No description provided for @converterInputHint.
  ///
  /// In en, this message translates to:
  /// **'For example: 1200 * 3 + 500'**
  String get converterInputHint;

  /// No description provided for @converterResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference conversion'**
  String get converterResultLabel;

  /// No description provided for @converterInvalidExpression.
  ///
  /// In en, this message translates to:
  /// **'Check the expression and edit it in place.'**
  String get converterInvalidExpression;

  /// No description provided for @converterPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get converterPositiveAmount;

  /// No description provided for @converterRateLoading.
  ///
  /// In en, this message translates to:
  /// **'Finding the latest reference rate…'**
  String get converterRateLoading;

  /// No description provided for @converterRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No reference rate is available. Add a manual rate to continue.'**
  String get converterRateUnavailable;

  /// No description provided for @converterRateLive.
  ///
  /// In en, this message translates to:
  /// **'Latest reference rate · {source} · {time}'**
  String converterRateLive(String source, String time);

  /// No description provided for @converterRateCached.
  ///
  /// In en, this message translates to:
  /// **'Cached at {time} · {source}'**
  String converterRateCached(String time, String source);

  /// No description provided for @converterRateStale.
  ///
  /// In en, this message translates to:
  /// **'Older cache from {time} · review before paying'**
  String converterRateStale(String time);

  /// No description provided for @converterRateManual.
  ///
  /// In en, this message translates to:
  /// **'Using your manual reference rate'**
  String get converterRateManual;

  /// No description provided for @converterRateCard.
  ///
  /// In en, this message translates to:
  /// **'Card-network reference · {source} · {time}'**
  String converterRateCard(String source, String time);

  /// No description provided for @converterRateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Same currency · rate 1'**
  String get converterRateIdentity;

  /// No description provided for @converterManualRate.
  ///
  /// In en, this message translates to:
  /// **'Enter manual rate'**
  String get converterManualRate;

  /// No description provided for @converterManualRateHint.
  ///
  /// In en, this message translates to:
  /// **'1 local currency = how much home currency'**
  String get converterManualRateHint;

  /// No description provided for @converterAdjustRate.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get converterAdjustRate;

  /// No description provided for @converterRateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose exchange rate'**
  String get converterRateSheetTitle;

  /// No description provided for @converterMarketReference.
  ///
  /// In en, this message translates to:
  /// **'API reference rate'**
  String get converterMarketReference;

  /// No description provided for @converterMarketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No API reference rate available'**
  String get converterMarketUnavailable;

  /// No description provided for @converterManualReference.
  ///
  /// In en, this message translates to:
  /// **'Manual rate'**
  String get converterManualReference;

  /// No description provided for @converterRateSourceDetail.
  ///
  /// In en, this message translates to:
  /// **'{source} · {time}'**
  String converterRateSourceDetail(String source, String time);

  /// No description provided for @converterRateUnit.
  ///
  /// In en, this message translates to:
  /// **'{quote} / {base}'**
  String converterRateUnit(String quote, String base);

  /// No description provided for @converterUseMarketRate.
  ///
  /// In en, this message translates to:
  /// **'Use API reference rate'**
  String get converterUseMarketRate;

  /// No description provided for @converterSaveAndUse.
  ///
  /// In en, this message translates to:
  /// **'Save and use'**
  String get converterSaveAndUse;

  /// No description provided for @converterRateDifferenceLower.
  ///
  /// In en, this message translates to:
  /// **'{percent}% below the API reference rate'**
  String converterRateDifferenceLower(String percent);

  /// No description provided for @converterRateDifferenceHigher.
  ///
  /// In en, this message translates to:
  /// **'{percent}% above the API reference rate'**
  String converterRateDifferenceHigher(String percent);

  /// No description provided for @converterRateDifferenceSame.
  ///
  /// In en, this message translates to:
  /// **'Matches the API reference rate'**
  String get converterRateDifferenceSame;

  /// No description provided for @converterRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh rate'**
  String get converterRefresh;

  /// No description provided for @converterCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare payment methods'**
  String get converterCompare;

  /// No description provided for @converterDcc.
  ///
  /// In en, this message translates to:
  /// **'Check DCC'**
  String get converterDcc;

  /// No description provided for @converterRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent expenses'**
  String get converterRecentTitle;

  /// No description provided for @converterRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Saved expenses will appear here.'**
  String get converterRecentEmpty;

  /// No description provided for @currencyLocal.
  ///
  /// In en, this message translates to:
  /// **'Transaction currency'**
  String get currencyLocal;

  /// No description provided for @currencyHome.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get currencyHome;

  /// No description provided for @currencyCommonTrading.
  ///
  /// In en, this message translates to:
  /// **'Common trading currencies'**
  String get currencyCommonTrading;

  /// No description provided for @currencyAllTrading.
  ///
  /// In en, this message translates to:
  /// **'All trading currencies'**
  String get currencyAllTrading;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get commonManage;

  /// No description provided for @commonEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get commonEstimated;

  /// No description provided for @paymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethodsTitle;

  /// No description provided for @paymentMethodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store fee rules only. Never enter card numbers, expiry dates, CVV, identity, or banking credentials.'**
  String get paymentMethodsSubtitle;

  /// No description provided for @paymentMethodsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add cash or a card to compare estimated costs.'**
  String get paymentMethodsEmpty;

  /// No description provided for @paymentAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get paymentAddTitle;

  /// No description provided for @paymentEditorQuickStart.
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get paymentEditorQuickStart;

  /// No description provided for @paymentEditorTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Start with a common rule, then fine-tune it below'**
  String get paymentEditorTemplateHint;

  /// No description provided for @paymentEditorBasics.
  ///
  /// In en, this message translates to:
  /// **'Basic details'**
  String get paymentEditorBasics;

  /// No description provided for @paymentEditorFees.
  ///
  /// In en, this message translates to:
  /// **'Fee rules'**
  String get paymentEditorFees;

  /// No description provided for @paymentEditorOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get paymentEditorOptional;

  /// No description provided for @paymentEditName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get paymentEditName;

  /// No description provided for @paymentNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter a payment method name'**
  String get paymentNamePlaceholder;

  /// No description provided for @paymentOptionalPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get paymentOptionalPlaceholder;

  /// No description provided for @paymentNotesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional, such as usage conditions or notes'**
  String get paymentNotesPlaceholder;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get paymentType;

  /// No description provided for @paymentNetwork.
  ///
  /// In en, this message translates to:
  /// **'Card network'**
  String get paymentNetwork;

  /// No description provided for @paymentBillingCurrency.
  ///
  /// In en, this message translates to:
  /// **'Billing currency'**
  String get paymentBillingCurrency;

  /// No description provided for @paymentTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get paymentTemplate;

  /// No description provided for @paymentForeignFee.
  ///
  /// In en, this message translates to:
  /// **'Foreign conversion fee %'**
  String get paymentForeignFee;

  /// No description provided for @paymentCrossBorderFee.
  ///
  /// In en, this message translates to:
  /// **'Cross-border fee %'**
  String get paymentCrossBorderFee;

  /// No description provided for @paymentRateMarkup.
  ///
  /// In en, this message translates to:
  /// **'Exchange-rate markup %'**
  String get paymentRateMarkup;

  /// No description provided for @paymentFixedFee.
  ///
  /// In en, this message translates to:
  /// **'Fixed fee'**
  String get paymentFixedFee;

  /// No description provided for @paymentCashback.
  ///
  /// In en, this message translates to:
  /// **'Cashback %'**
  String get paymentCashback;

  /// No description provided for @paymentMinimumFee.
  ///
  /// In en, this message translates to:
  /// **'Minimum variable fee (optional)'**
  String get paymentMinimumFee;

  /// No description provided for @paymentMaximumFee.
  ///
  /// In en, this message translates to:
  /// **'Maximum variable fee (optional)'**
  String get paymentMaximumFee;

  /// No description provided for @paymentCashRate.
  ///
  /// In en, this message translates to:
  /// **'Actual cash exchange rate (optional)'**
  String get paymentCashRate;

  /// No description provided for @paymentNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get paymentNotes;

  /// No description provided for @paymentTransactionScope.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get paymentTransactionScope;

  /// No description provided for @paymentPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get paymentPurchase;

  /// No description provided for @paymentAtm.
  ///
  /// In en, this message translates to:
  /// **'ATM'**
  String get paymentAtm;

  /// No description provided for @paymentAll.
  ///
  /// In en, this message translates to:
  /// **'Purchases and ATM'**
  String get paymentAll;

  /// No description provided for @paymentTypeCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get paymentTypeCredit;

  /// No description provided for @paymentTypeDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get paymentTypeDebit;

  /// No description provided for @paymentTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentTypeCash;

  /// No description provided for @paymentTypeWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get paymentTypeWallet;

  /// No description provided for @paymentTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get paymentTypeCustom;

  /// No description provided for @paymentNetworkUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get paymentNetworkUnknown;

  /// No description provided for @paymentNetworkOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentNetworkOther;

  /// No description provided for @paymentInvalidForm.
  ///
  /// In en, this message translates to:
  /// **'Check the name, non-negative rates and fee limits.'**
  String get paymentInvalidForm;

  /// No description provided for @paymentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this payment method?'**
  String get paymentDeleteTitle;

  /// No description provided for @paymentDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Historical expense snapshots remain unchanged.'**
  String get paymentDeleteMessage;

  /// No description provided for @paymentPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'Generic estimate only. Bank and card-network policies may change.'**
  String get paymentPolicyNotice;

  /// No description provided for @paymentComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated payment costs'**
  String get paymentComparisonTitle;

  /// No description provided for @paymentComparisonMissing.
  ///
  /// In en, this message translates to:
  /// **'Start from a valid conversion to compare costs.'**
  String get paymentComparisonMissing;

  /// No description provided for @paymentComparisonNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add at least two applicable methods for a useful comparison.'**
  String get paymentComparisonNeedTwo;

  /// No description provided for @paymentComparisonNoApplicable.
  ///
  /// In en, this message translates to:
  /// **'You have payment methods, but none apply to purchases billed in {currency}. Check their billing currency and transaction type.'**
  String paymentComparisonNoApplicable(String currency);

  /// No description provided for @paymentComparisonOnlyOne.
  ///
  /// In en, this message translates to:
  /// **'Only one payment method applies to purchases billed in {currency}. Manage your existing rules to compare another.'**
  String paymentComparisonOnlyOne(String currency);

  /// No description provided for @paymentComparisonConfiguredButUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your payment methods are still saved; they just cannot be used for this conversion.'**
  String get paymentComparisonConfiguredButUnavailable;

  /// No description provided for @paymentRecommended.
  ///
  /// In en, this message translates to:
  /// **'Lowest estimated cost'**
  String get paymentRecommended;

  /// No description provided for @paymentDifference.
  ///
  /// In en, this message translates to:
  /// **'+{amount} vs lowest'**
  String paymentDifference(String amount);

  /// No description provided for @paymentBaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Base conversion'**
  String get paymentBaseAmount;

  /// No description provided for @paymentRateMarkupAmount.
  ///
  /// In en, this message translates to:
  /// **'Rate markup'**
  String get paymentRateMarkupAmount;

  /// No description provided for @paymentForeignFeeAmount.
  ///
  /// In en, this message translates to:
  /// **'Foreign conversion fee'**
  String get paymentForeignFeeAmount;

  /// No description provided for @paymentCrossBorderFeeAmount.
  ///
  /// In en, this message translates to:
  /// **'Cross-border fee'**
  String get paymentCrossBorderFeeAmount;

  /// No description provided for @paymentVariableFee.
  ///
  /// In en, this message translates to:
  /// **'Variable fee after limits'**
  String get paymentVariableFee;

  /// No description provided for @paymentFixedFeeAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed fee'**
  String get paymentFixedFeeAmount;

  /// No description provided for @paymentCashbackAmount.
  ///
  /// In en, this message translates to:
  /// **'Estimated cashback'**
  String get paymentCashbackAmount;

  /// No description provided for @paymentEstimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get paymentEstimatedTotal;

  /// No description provided for @paymentCashRateUsed.
  ///
  /// In en, this message translates to:
  /// **'Uses your actual cash exchange rate'**
  String get paymentCashRateUsed;

  /// No description provided for @paymentEstimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'All figures are estimates. Final charges depend on the merchant, card network, issuer and posting date.'**
  String get paymentEstimateDisclaimer;

  /// No description provided for @dccTitle.
  ///
  /// In en, this message translates to:
  /// **'DCC check'**
  String get dccTitle;

  /// No description provided for @dccLocalAmount.
  ///
  /// In en, this message translates to:
  /// **'Local-currency amount'**
  String get dccLocalAmount;

  /// No description provided for @dccMerchantQuote.
  ///
  /// In en, this message translates to:
  /// **'Merchant home-currency quote'**
  String get dccMerchantQuote;

  /// No description provided for @dccOptionalPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment method (optional)'**
  String get dccOptionalPayment;

  /// No description provided for @dccNoPayment.
  ///
  /// In en, this message translates to:
  /// **'No payment method'**
  String get dccNoPayment;

  /// No description provided for @dccImpliedRate.
  ///
  /// In en, this message translates to:
  /// **'Merchant implied rate'**
  String get dccImpliedRate;

  /// No description provided for @dccReferenceRate.
  ///
  /// In en, this message translates to:
  /// **'Reference rate'**
  String get dccReferenceRate;

  /// No description provided for @dccReferenceAmount.
  ///
  /// In en, this message translates to:
  /// **'Reference conversion'**
  String get dccReferenceAmount;

  /// No description provided for @dccExtraAmount.
  ///
  /// In en, this message translates to:
  /// **'DCC extra amount'**
  String get dccExtraAmount;

  /// No description provided for @dccExtraPercent.
  ///
  /// In en, this message translates to:
  /// **'DCC extra percentage'**
  String get dccExtraPercent;

  /// No description provided for @dccLocalPaymentEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost if paying in local currency'**
  String get dccLocalPaymentEstimate;

  /// No description provided for @dccGuidanceHigher.
  ///
  /// In en, this message translates to:
  /// **'The merchant quote is about {percent}% above the current reference conversion. Paying in local currency is usually more transparent, but the final charge still depends on the issuer.'**
  String dccGuidanceHigher(String percent);

  /// No description provided for @dccGuidanceLower.
  ///
  /// In en, this message translates to:
  /// **'The merchant quote is not above the current reference conversion. This is still only a comparison; verify the currency and final amount on the terminal.'**
  String get dccGuidanceLower;

  /// No description provided for @dccInvalidLocal.
  ///
  /// In en, this message translates to:
  /// **'Enter a local amount greater than zero.'**
  String get dccInvalidLocal;

  /// No description provided for @dccInvalidQuote.
  ///
  /// In en, this message translates to:
  /// **'Enter a merchant quote greater than zero.'**
  String get dccInvalidQuote;

  /// No description provided for @dccSameCurrency.
  ///
  /// In en, this message translates to:
  /// **'DCC requires two different currencies.'**
  String get dccSameCurrency;

  /// No description provided for @dccMissingRate.
  ///
  /// In en, this message translates to:
  /// **'A reference rate is required before checking DCC.'**
  String get dccMissingRate;

  /// No description provided for @templateNoForeignFee.
  ///
  /// In en, this message translates to:
  /// **'No foreign-fee card'**
  String get templateNoForeignFee;

  /// No description provided for @templateOnePercent.
  ///
  /// In en, this message translates to:
  /// **'1% fee card'**
  String get templateOnePercent;

  /// No description provided for @templateOnePointFivePercent.
  ///
  /// In en, this message translates to:
  /// **'1.5% fee card'**
  String get templateOnePointFivePercent;

  /// No description provided for @templateTwoPercent.
  ///
  /// In en, this message translates to:
  /// **'2% fee card'**
  String get templateTwoPercent;

  /// No description provided for @templateUnionPayCny.
  ///
  /// In en, this message translates to:
  /// **'UnionPay CNY billing card'**
  String get templateUnionPayCny;

  /// No description provided for @templateCash.
  ///
  /// In en, this message translates to:
  /// **'Cash exchange'**
  String get templateCash;

  /// No description provided for @templateCustom.
  ///
  /// In en, this message translates to:
  /// **'Fully custom'**
  String get templateCustom;

  /// No description provided for @onboardingHomeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Suggested home currency'**
  String get onboardingHomeCurrency;

  /// No description provided for @onboardingCreateTrip.
  ///
  /// In en, this message translates to:
  /// **'Create a trip'**
  String get onboardingCreateTrip;

  /// No description provided for @onboardingAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get onboardingAddPayment;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @tripCreate.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get tripCreate;

  /// No description provided for @tripEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripEdit;

  /// No description provided for @tripCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy configuration'**
  String get tripCopy;

  /// No description provided for @tripArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tripArchive;

  /// No description provided for @tripDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this trip?'**
  String get tripDeleteTitle;

  /// No description provided for @tripDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Expenses stay in the ledger without this trip. Choose whether their local receipt images should also be removed. This cannot be undone.'**
  String get tripDeleteMessage;

  /// No description provided for @tripExport.
  ///
  /// In en, this message translates to:
  /// **'Export this trip'**
  String get tripExport;

  /// No description provided for @tripDeleteKeepReceipts.
  ///
  /// In en, this message translates to:
  /// **'Delete trip, keep receipts'**
  String get tripDeleteKeepReceipts;

  /// No description provided for @tripDeleteWithReceipts.
  ///
  /// In en, this message translates to:
  /// **'Delete trip and receipts'**
  String get tripDeleteWithReceipts;

  /// No description provided for @tripReceiptDeletePartial.
  ///
  /// In en, this message translates to:
  /// **'The trip was deleted, but some receipt images could not be removed.'**
  String get tripReceiptDeletePartial;

  /// No description provided for @tripName.
  ///
  /// In en, this message translates to:
  /// **'Trip name'**
  String get tripName;

  /// No description provided for @tripDestinations.
  ///
  /// In en, this message translates to:
  /// **'Countries or regions'**
  String get tripDestinations;

  /// No description provided for @tripDestinationsHint.
  ///
  /// In en, this message translates to:
  /// **'For example: JP, KR'**
  String get tripDestinationsHint;

  /// No description provided for @tripDestinationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get tripDestinationsEmpty;

  /// No description provided for @tripCurrentAndUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Current & upcoming'**
  String get tripCurrentAndUpcoming;

  /// No description provided for @tripHistoryTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tripHistoryTab;

  /// No description provided for @tripRoutePlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan a multi-country route'**
  String get tripRoutePlannerTitle;

  /// No description provided for @tripRoutePlannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add stops in order. Budget and insights cover the whole trip.'**
  String get tripRoutePlannerSubtitle;

  /// No description provided for @tripStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Destinations & stays'**
  String get tripStopsTitle;

  /// No description provided for @tripAddNextStop.
  ///
  /// In en, this message translates to:
  /// **'Add next stop'**
  String get tripAddNextStop;

  /// No description provided for @tripWholeRange.
  ///
  /// In en, this message translates to:
  /// **'Whole trip'**
  String get tripWholeRange;

  /// No description provided for @tripDateRangePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get tripDateRangePickerTitle;

  /// No description provided for @tripWholeBudget.
  ///
  /// In en, this message translates to:
  /// **'Whole-trip budget'**
  String get tripWholeBudget;

  /// No description provided for @tripMoreSettings.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get tripMoreSettings;

  /// No description provided for @tripCurrentStop.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get tripCurrentStop;

  /// No description provided for @tripNextStop.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tripNextStop;

  /// No description provided for @tripDaysLater.
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String tripDaysLater(int count);

  /// No description provided for @tripDayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String tripDayCount(int count);

  /// No description provided for @tripStopDayProgress.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String tripStopDayProgress(int day, int total);

  /// No description provided for @tripBudgetUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String tripBudgetUsed(String percent);

  /// No description provided for @tripBudgetRemainingPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% remaining'**
  String tripBudgetRemainingPercent(String percent);

  /// No description provided for @tripDailyBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Based on remaining days · updates automatically'**
  String get tripDailyBudgetHint;

  /// No description provided for @tripDailyBudgetApprox.
  ///
  /// In en, this message translates to:
  /// **'About {amount} / day'**
  String tripDailyBudgetApprox(String amount);

  /// No description provided for @tripViewAction.
  ///
  /// In en, this message translates to:
  /// **'View trip'**
  String get tripViewAction;

  /// No description provided for @tripRecordAction.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get tripRecordAction;

  /// No description provided for @tripRouteRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one destination.'**
  String get tripRouteRequired;

  /// No description provided for @tripAdjustStopEnd.
  ///
  /// In en, this message translates to:
  /// **'Adjust departure date'**
  String get tripAdjustStopEnd;

  /// No description provided for @tripChangeDestination.
  ///
  /// In en, this message translates to:
  /// **'Change destination'**
  String get tripChangeDestination;

  /// No description provided for @tripChangeStopCurrency.
  ///
  /// In en, this message translates to:
  /// **'Change local currency'**
  String get tripChangeStopCurrency;

  /// No description provided for @tripRemoveStop.
  ///
  /// In en, this message translates to:
  /// **'Remove this stop'**
  String get tripRemoveStop;

  /// No description provided for @tripOfflineMultiHint.
  ///
  /// In en, this message translates to:
  /// **'Includes every local currency without requesting location.'**
  String get tripOfflineMultiHint;

  /// No description provided for @countrySearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No countries or regions found'**
  String get countrySearchEmpty;

  /// No description provided for @countryUnknownSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved but unrecognized; select a valid destination before removing'**
  String get countryUnknownSaved;

  /// No description provided for @tripStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get tripStartDate;

  /// No description provided for @tripEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get tripEndDate;

  /// No description provided for @tripLocalCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Local currencies'**
  String get tripLocalCurrencies;

  /// No description provided for @tripLocalCurrenciesPending.
  ///
  /// In en, this message translates to:
  /// **'Recommended after destination selection'**
  String get tripLocalCurrenciesPending;

  /// No description provided for @tripLocalCurrenciesMissing.
  ///
  /// In en, this message translates to:
  /// **'Not recognized; select manually'**
  String get tripLocalCurrenciesMissing;

  /// No description provided for @tripLocalCurrenciesRecommended.
  ///
  /// In en, this message translates to:
  /// **'{currencies} · Recommended'**
  String tripLocalCurrenciesRecommended(String currencies);

  /// No description provided for @tripCurrencyRecommendationTitle.
  ///
  /// In en, this message translates to:
  /// **'Update local currencies?'**
  String get tripCurrencyRecommendationTitle;

  /// No description provided for @tripCurrencyRecommendationMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected countries or regions commonly use {currencies}. Update the local currencies?'**
  String tripCurrencyRecommendationMessage(String currencies);

  /// No description provided for @tripCurrencyRecommendationKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get tripCurrencyRecommendationKeep;

  /// No description provided for @tripCurrencyRecommendationUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get tripCurrencyRecommendationUpdate;

  /// No description provided for @tripBudget.
  ///
  /// In en, this message translates to:
  /// **'Total budget'**
  String get tripBudget;

  /// No description provided for @tripBudgetOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional; zero is allowed'**
  String get tripBudgetOptional;

  /// No description provided for @tripParticipants.
  ///
  /// In en, this message translates to:
  /// **'Travelers'**
  String get tripParticipants;

  /// No description provided for @tripDefaultPayment.
  ///
  /// In en, this message translates to:
  /// **'Default payment method'**
  String get tripDefaultPayment;

  /// No description provided for @tripOfflinePack.
  ///
  /// In en, this message translates to:
  /// **'Offline rate pack'**
  String get tripOfflinePack;

  /// No description provided for @tripOfflinePackHint.
  ///
  /// In en, this message translates to:
  /// **'Prepare the selected local and home currency pair without requesting location.'**
  String get tripOfflinePackHint;

  /// No description provided for @tripInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the name, dates, currencies, budget and traveler count.'**
  String get tripInvalid;

  /// No description provided for @tripActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get tripActive;

  /// No description provided for @tripUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tripUpcoming;

  /// No description provided for @tripHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tripHistory;

  /// No description provided for @tripMissing.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer available.'**
  String get tripMissing;

  /// No description provided for @tripNoBudget.
  ///
  /// In en, this message translates to:
  /// **'No budget'**
  String get tripNoBudget;

  /// No description provided for @tripSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get tripSpent;

  /// No description provided for @tripRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get tripRemaining;

  /// No description provided for @tripDailyRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining per day'**
  String get tripDailyRemaining;

  /// No description provided for @tripDayProgress.
  ///
  /// In en, this message translates to:
  /// **'Trip days'**
  String get tripDayProgress;

  /// No description provided for @tripDailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Current daily average'**
  String get tripDailyAverage;

  /// No description provided for @tripPaymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment-method breakdown'**
  String get tripPaymentBreakdown;

  /// No description provided for @tripOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline pack ready'**
  String get tripOfflineReady;

  /// No description provided for @tripOfflineMissing.
  ///
  /// In en, this message translates to:
  /// **'Offline pack not downloaded'**
  String get tripOfflineMissing;

  /// No description provided for @expenseManualAdd.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseManualAdd;

  /// No description provided for @expenseOcrPrefillBanner.
  ///
  /// In en, this message translates to:
  /// **'Filled {count} items from the receipt. Please review them.'**
  String expenseOcrPrefillBanner(int count);

  /// No description provided for @expenseOcrNeedsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get expenseOcrNeedsConfirmation;

  /// No description provided for @expenseSave.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get expenseSave;

  /// No description provided for @expenseRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent expenses'**
  String get expenseRecent;

  /// No description provided for @expenseEditorBasics.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get expenseEditorBasics;

  /// No description provided for @expenseEditorAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseEditorAmount;

  /// No description provided for @expenseEditorPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment and status'**
  String get expenseEditorPaymentStatus;

  /// No description provided for @expenseEditorTripCategory.
  ///
  /// In en, this message translates to:
  /// **'Trip and category'**
  String get expenseEditorTripCategory;

  /// No description provided for @expenseEditorAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments and travelers'**
  String get expenseEditorAdjustments;

  /// No description provided for @expenseEditorLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Updates with the trip, currencies, and payment method'**
  String get expenseEditorLiveHint;

  /// No description provided for @expenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchant or item'**
  String get expenseTitle;

  /// No description provided for @expenseTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter merchant or item'**
  String get expenseTitlePlaceholder;

  /// No description provided for @expenseTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get expenseTrip;

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCategory;

  /// No description provided for @expenseTransactionAmount.
  ///
  /// In en, this message translates to:
  /// **'Transaction amount'**
  String get expenseTransactionAmount;

  /// No description provided for @expenseTransactionAmountPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter transaction amount'**
  String get expenseTransactionAmountPlaceholder;

  /// No description provided for @expenseReferenceAmount.
  ///
  /// In en, this message translates to:
  /// **'Reference conversion'**
  String get expenseReferenceAmount;

  /// No description provided for @expenseEstimatedAmount.
  ///
  /// In en, this message translates to:
  /// **'Estimated final amount'**
  String get expenseEstimatedAmount;

  /// No description provided for @expenseActualAmount.
  ///
  /// In en, this message translates to:
  /// **'Actual posted amount'**
  String get expenseActualAmount;

  /// No description provided for @expensePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get expensePaymentMethod;

  /// No description provided for @expenseTax.
  ///
  /// In en, this message translates to:
  /// **'Tax in home currency'**
  String get expenseTax;

  /// No description provided for @expenseTip.
  ///
  /// In en, this message translates to:
  /// **'Tip in home currency'**
  String get expenseTip;

  /// No description provided for @expenseDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount in home currency'**
  String get expenseDiscount;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Transaction date'**
  String get expenseDate;

  /// No description provided for @expenseReceiptPath.
  ///
  /// In en, this message translates to:
  /// **'Receipt attachment (optional)'**
  String get expenseReceiptPath;

  /// No description provided for @expenseReceiptSection.
  ///
  /// In en, this message translates to:
  /// **'Receipt attachment'**
  String get expenseReceiptSection;

  /// No description provided for @expenseReceiptReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get expenseReceiptReplace;

  /// No description provided for @expenseReceiptAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get expenseReceiptAdd;

  /// No description provided for @expenseReceiptRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove receipt'**
  String get expenseReceiptRemove;

  /// No description provided for @expenseNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get expenseNotes;

  /// No description provided for @expenseBudgetIncluded.
  ///
  /// In en, this message translates to:
  /// **'Include in trip budget'**
  String get expenseBudgetIncluded;

  /// No description provided for @expenseStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get expenseStatus;

  /// No description provided for @expenseAmountStatus.
  ///
  /// In en, this message translates to:
  /// **'Amount status'**
  String get expenseAmountStatus;

  /// No description provided for @expensePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get expensePending;

  /// No description provided for @expenseConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get expenseConfirmed;

  /// No description provided for @expenseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the title, positive amounts, currencies and traveler count.'**
  String get expenseInvalid;

  /// No description provided for @expenseMissingRequired.
  ///
  /// In en, this message translates to:
  /// **'Merchant name and transaction amount are still required.'**
  String get expenseMissingRequired;

  /// No description provided for @expenseDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate expense'**
  String get expenseDuplicateTitle;

  /// No description provided for @expenseDuplicateMessage.
  ///
  /// In en, this message translates to:
  /// **'A matching expense was saved within five minutes. Save another copy?'**
  String get expenseDuplicateMessage;

  /// No description provided for @expenseSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get expenseSaveAnyway;

  /// No description provided for @expenseMissing.
  ///
  /// In en, this message translates to:
  /// **'This expense is no longer available.'**
  String get expenseMissing;

  /// No description provided for @expenseDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference from estimate'**
  String get expenseDifference;

  /// No description provided for @expenseRateSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Saved rate snapshot'**
  String get expenseRateSnapshot;

  /// No description provided for @expensePaymentSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Saved fee-rule snapshot'**
  String get expensePaymentSnapshot;

  /// No description provided for @expenseActualConflict.
  ///
  /// In en, this message translates to:
  /// **'Two actual posted amounts need conflict resolution before sync can continue.'**
  String get expenseActualConflict;

  /// No description provided for @expenseRecordActual.
  ///
  /// In en, this message translates to:
  /// **'Record actual amount'**
  String get expenseRecordActual;

  /// No description provided for @expenseEditActual.
  ///
  /// In en, this message translates to:
  /// **'Edit actual amount'**
  String get expenseEditActual;

  /// No description provided for @expenseAdjust.
  ///
  /// In en, this message translates to:
  /// **'Refund or void'**
  String get expenseAdjust;

  /// No description provided for @expenseRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get expenseRefund;

  /// No description provided for @expensePartialRefund.
  ///
  /// In en, this message translates to:
  /// **'Partial refund'**
  String get expensePartialRefund;

  /// No description provided for @expenseVoid.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get expenseVoid;

  /// No description provided for @expenseRefundInvalid.
  ///
  /// In en, this message translates to:
  /// **'The refund must be greater than zero and cannot exceed the original posted amount.'**
  String get expenseRefundInvalid;

  /// No description provided for @expenseRefundStatus.
  ///
  /// In en, this message translates to:
  /// **'Refund status'**
  String get expenseRefundStatus;

  /// No description provided for @expenseRefundNone.
  ///
  /// In en, this message translates to:
  /// **'No refund'**
  String get expenseRefundNone;

  /// No description provided for @expenseRefundPartialStatus.
  ///
  /// In en, this message translates to:
  /// **'Partially refunded'**
  String get expenseRefundPartialStatus;

  /// No description provided for @expenseRefundFullStatus.
  ///
  /// In en, this message translates to:
  /// **'Fully refunded'**
  String get expenseRefundFullStatus;

  /// No description provided for @expenseRefundInvalidStatus.
  ///
  /// In en, this message translates to:
  /// **'Invalid refund amount'**
  String get expenseRefundInvalidStatus;

  /// No description provided for @expenseRefundedTotal.
  ///
  /// In en, this message translates to:
  /// **'Total refunded'**
  String get expenseRefundedTotal;

  /// No description provided for @expenseNetAmount.
  ///
  /// In en, this message translates to:
  /// **'Net expense'**
  String get expenseNetAmount;

  /// No description provided for @expenseRefundRecords.
  ///
  /// In en, this message translates to:
  /// **'Refund records'**
  String get expenseRefundRecords;

  /// No description provided for @expenseRelatedOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original expense'**
  String get expenseRelatedOriginal;

  /// No description provided for @expenseViewOriginal.
  ///
  /// In en, this message translates to:
  /// **'View original expense'**
  String get expenseViewOriginal;

  /// No description provided for @expenseCorrectOriginal.
  ///
  /// In en, this message translates to:
  /// **'Correct original amount'**
  String get expenseCorrectOriginal;

  /// No description provided for @expenseCorrectRefund.
  ///
  /// In en, this message translates to:
  /// **'Correct refund amount'**
  String get expenseCorrectRefund;

  /// No description provided for @expenseRecordRefund.
  ///
  /// In en, this message translates to:
  /// **'Record refund'**
  String get expenseRecordRefund;

  /// No description provided for @expenseContinueRefund.
  ///
  /// In en, this message translates to:
  /// **'Continue refund'**
  String get expenseContinueRefund;

  /// No description provided for @expenseVoidAction.
  ///
  /// In en, this message translates to:
  /// **'Void record'**
  String get expenseVoidAction;

  /// No description provided for @expenseVoidConfirm.
  ///
  /// In en, this message translates to:
  /// **'Only an expense that has not posted can be voided. Void this record?'**
  String get expenseVoidConfirm;

  /// No description provided for @expenseCorrectionWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing the original amount may change the refund status, but it will not change existing refund amounts.'**
  String get expenseCorrectionWarning;

  /// No description provided for @expenseAdjustmentInvalid.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be completed. Check the original amount and total refunded.'**
  String get expenseAdjustmentInvalid;

  /// No description provided for @expenseManualRateSource.
  ///
  /// In en, this message translates to:
  /// **'Manual ledger rate'**
  String get expenseManualRateSource;

  /// No description provided for @expenseManualPaymentRule.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get expenseManualPaymentRule;

  /// No description provided for @ledgerTimeline.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get ledgerTimeline;

  /// No description provided for @ledgerCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get ledgerCalendar;

  /// No description provided for @ledgerCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get ledgerCategories;

  /// No description provided for @ledgerFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get ledgerFilters;

  /// No description provided for @ledgerClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get ledgerClearFilters;

  /// No description provided for @ledgerThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get ledgerThisMonth;

  /// No description provided for @ledgerLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get ledgerLastMonth;

  /// No description provided for @ledgerAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get ledgerAllTime;

  /// No description provided for @ledgerThisMonthSpending.
  ///
  /// In en, this message translates to:
  /// **'This month spending'**
  String get ledgerThisMonthSpending;

  /// No description provided for @ledgerLastMonthSpending.
  ///
  /// In en, this message translates to:
  /// **'Last month spending'**
  String get ledgerLastMonthSpending;

  /// No description provided for @ledgerTotalSpending.
  ///
  /// In en, this message translates to:
  /// **'Total spending'**
  String get ledgerTotalSpending;

  /// No description provided for @ledgerSummaryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records · Calculated in {currencyCode}'**
  String ledgerSummaryCount(int count, String currencyCode);

  /// No description provided for @ledgerToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String ledgerToday(String date);

  /// No description provided for @ledgerDayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String ledgerDayCount(int count);

  /// No description provided for @ledgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses yet.'**
  String get ledgerEmpty;

  /// No description provided for @ledgerMinimumAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum amount'**
  String get ledgerMinimumAmount;

  /// No description provided for @ledgerMaximumAmount.
  ///
  /// In en, this message translates to:
  /// **'Maximum amount'**
  String get ledgerMaximumAmount;

  /// No description provided for @ledgerInvalidFilters.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid non-negative amount range.'**
  String get ledgerInvalidFilters;

  /// No description provided for @ledgerFilteredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} expenses'**
  String ledgerFilteredCount(int count);

  /// No description provided for @ledgerRecentDays.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String ledgerRecentDays(int count);

  /// No description provided for @ledgerRecentDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String ledgerRecentDaysShort(int count);

  /// No description provided for @ledgerCustomDate.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get ledgerCustomDate;

  /// No description provided for @ledgerDateRangePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get ledgerDateRangePickerTitle;

  /// No description provided for @ledgerStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get ledgerStartDate;

  /// No description provided for @ledgerEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get ledgerEndDate;

  /// No description provided for @ledgerViewRecords.
  ///
  /// In en, this message translates to:
  /// **'View {count} records'**
  String ledgerViewRecords(int count);

  /// No description provided for @ledgerSelectionSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get ledgerSelectionSeparator;

  /// No description provided for @calibrationNone.
  ///
  /// In en, this message translates to:
  /// **'Record an actual amount to build a local fee comparison.'**
  String get calibrationNone;

  /// No description provided for @calibrationRange.
  ///
  /// In en, this message translates to:
  /// **'Recent {count} comparable charges: {minimum}% to {maximum}% markup. Three or more records are required before suggesting a rule change.'**
  String calibrationRange(int count, String minimum, String maximum);

  /// No description provided for @calibrationRangeReady.
  ///
  /// In en, this message translates to:
  /// **'Recent {count} comparable charges: {minimum}% to {maximum}% markup. Review them before manually changing the rule.'**
  String calibrationRangeReady(int count, String minimum, String maximum);

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get categoryHotel;

  /// No description provided for @categoryTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get categoryTickets;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'iCloud sync'**
  String get syncTitle;

  /// No description provided for @syncEnable.
  ///
  /// In en, this message translates to:
  /// **'Sync structured data with iCloud'**
  String get syncEnable;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync is off. Local data is unchanged.'**
  String get syncStatusDisabled;

  /// No description provided for @syncStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready to sync'**
  String get syncStatusIdle;

  /// No description provided for @syncStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusWorking;

  /// No description provided for @syncStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncStatusSucceeded;

  /// No description provided for @syncCompletedNotice.
  ///
  /// In en, this message translates to:
  /// **'iCloud sync complete. Latest data is now shown.'**
  String get syncCompletedNotice;

  /// No description provided for @syncStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get syncStatusWaiting;

  /// No description provided for @syncStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Local data remains available.'**
  String get syncStatusFailed;

  /// No description provided for @syncStatusNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to iCloud to sync.'**
  String get syncStatusNoAccount;

  /// No description provided for @syncStatusRestricted.
  ///
  /// In en, this message translates to:
  /// **'iCloud is restricted on this device.'**
  String get syncStatusRestricted;

  /// No description provided for @syncLastSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync: {value}'**
  String syncLastSuccess(String value);

  /// No description provided for @syncFailureReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {value}'**
  String syncFailureReason(String value);

  /// No description provided for @syncActualConflict.
  ///
  /// In en, this message translates to:
  /// **'Two posted amounts need your choice.'**
  String get syncActualConflict;

  /// No description provided for @syncConflictValues.
  ///
  /// In en, this message translates to:
  /// **'On this device: {local} · In iCloud: {remote}'**
  String syncConflictValues(String local, String remote);

  /// No description provided for @syncKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep this device'**
  String get syncKeepLocal;

  /// No description provided for @syncUseCloud.
  ///
  /// In en, this message translates to:
  /// **'Use iCloud'**
  String get syncUseCloud;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded. Local data is unchanged.'**
  String get settingsLoadFailed;

  /// No description provided for @settingsSectionCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get settingsSectionCommon;

  /// No description provided for @settingsSectionDataDevices.
  ///
  /// In en, this message translates to:
  /// **'Data and devices'**
  String get settingsSectionDataDevices;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsPaymentMethodsSummary.
  ///
  /// In en, this message translates to:
  /// **'Manage cards, cash, and fees'**
  String get settingsPaymentMethodsSummary;

  /// No description provided for @settingsDataSummary.
  ///
  /// In en, this message translates to:
  /// **'Export, backup, and cleanup'**
  String get settingsDataSummary;

  /// No description provided for @settingsPrivacySummary.
  ///
  /// In en, this message translates to:
  /// **'Policies, permissions, and disclaimers'**
  String get settingsPrivacySummary;

  /// No description provided for @kifxMiniTitle.
  ///
  /// In en, this message translates to:
  /// **'KIFX Mini Program'**
  String get kifxMiniTitle;

  /// No description provided for @kifxMiniSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to open the KIFX Mini Program'**
  String get kifxMiniSubtitle;

  /// No description provided for @kifxMiniUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The KIFX Mini Program is available on iOS only.'**
  String get kifxMiniUnavailable;

  /// No description provided for @kifxMiniOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The KIFX Mini Program cannot be opened right now. Try again later.'**
  String get kifxMiniOpenFailed;

  /// No description provided for @syncStatusEnabledShort.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get syncStatusEnabledShort;

  /// No description provided for @syncStatusDisabledShort.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get syncStatusDisabledShort;

  /// No description provided for @rateSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency and rates'**
  String get rateSettingsTitle;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default home currency'**
  String get defaultCurrency;

  /// No description provided for @refreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Automatic refresh'**
  String get refreshInterval;

  /// No description provided for @refreshEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every {count} hours'**
  String refreshEveryHours(int count);

  /// No description provided for @wifiOnlyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh rates on Wi-Fi only'**
  String get wifiOnlyRefresh;

  /// No description provided for @decimalDisplayRule.
  ///
  /// In en, this message translates to:
  /// **'Decimal display'**
  String get decimalDisplayRule;

  /// No description provided for @decimalDisplayCurrencyDefault.
  ///
  /// In en, this message translates to:
  /// **'Use each currency’s standard digits'**
  String get decimalDisplayCurrencyDefault;

  /// No description provided for @dataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data, backup, and export'**
  String get dataTitle;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export expenses as CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export expenses as PDF'**
  String get exportPdf;

  /// No description provided for @tripSummaryImageExport.
  ///
  /// In en, this message translates to:
  /// **'Save trip summary image'**
  String get tripSummaryImageExport;

  /// No description provided for @tripSummaryImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip summary'**
  String get tripSummaryImageTitle;

  /// No description provided for @tripSummaryImageSaveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get tripSummaryImageSaveToPhotos;

  /// No description provided for @tripSummaryImageSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip summary saved to Photos.'**
  String get tripSummaryImageSaved;

  /// No description provided for @tripSummaryImagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photos access is off. Allow RoamSum to add photos in Settings, then try again.'**
  String get tripSummaryImagePermissionDenied;

  /// No description provided for @tripSummaryImageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The trip summary could not be saved to Photos.'**
  String get tripSummaryImageSaveFailed;

  /// No description provided for @tripSummaryImageGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String tripSummaryImageGeneratedAt(String date);

  /// No description provided for @tripSummaryImageDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For personal reference. Receipt images and expense details are not included.'**
  String get tripSummaryImageDisclaimer;

  /// No description provided for @exportEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no expenses to export.'**
  String get exportEmpty;

  /// No description provided for @exportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This export contains more than 20,000 records. Export a smaller data set.'**
  String get exportTooLarge;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export could not be created or shared.'**
  String get exportFailed;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create local backup'**
  String get backupCreate;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be created or shared.'**
  String get backupFailed;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'A valid backup replaces the current local database. If validation fails, the current database remains unchanged.'**
  String get backupRestoreMessage;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'The backup was restored.'**
  String get backupRestored;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'This backup is invalid, unsupported, or could not be restored. Current data was not replaced.'**
  String get backupRestoreFailed;

  /// No description provided for @clearReceiptImages.
  ///
  /// In en, this message translates to:
  /// **'Clear receipt images'**
  String get clearReceiptImages;

  /// No description provided for @clearReceiptImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all receipt images?'**
  String get clearReceiptImagesTitle;

  /// No description provided for @clearReceiptImagesMessage.
  ///
  /// In en, this message translates to:
  /// **'Expense records remain, but their local image references will be removed. This cannot be undone.'**
  String get clearReceiptImagesMessage;

  /// No description provided for @clearReceiptImagesDone.
  ///
  /// In en, this message translates to:
  /// **'Receipt images and their local references were cleared.'**
  String get clearReceiptImagesDone;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear all data'**
  String get clearAllData;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all local data?'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes trips, expenses, rates, payment methods, settings, receipt images, sync state, and the Widget snapshot.'**
  String get clearAllDataMessage;

  /// No description provided for @clearAllDataAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm permanent deletion'**
  String get clearAllDataAgainTitle;

  /// No description provided for @clearAllDataAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. Continue only if you have exported anything you need.'**
  String get clearAllDataAgainMessage;

  /// No description provided for @clearDataFailed.
  ///
  /// In en, this message translates to:
  /// **'The data could not be cleared completely. No success was recorded.'**
  String get clearDataFailed;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and about'**
  String get privacyTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The privacy policy could not be loaded. Check your connection and try again.'**
  String get privacyPolicyLoadFailed;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'RoamSum does not require an account and does not store full card numbers, CVV, identity documents, or banking credentials. Trips, expenses, settings, and receipt images are stored on this device. OCR runs on this device. Receipt originals are not uploaded. If you enable iCloud sync, structured app data is sent to your private CloudKit database; receipt originals are excluded. Market reference-rate requests are sent to Frankfurter. Frankfurter states that its API does not collect personal data, while its public service uses Cloudflare and may collect basic analytics information. Exports and backups are generated locally and leave the app only when you choose a destination in the system share sheet. Trip summary images are added to Photos only after you tap Save to Photos; any iCloud Photos sync follows your system settings.'**
  String get privacyPolicyBody;

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Rates and cost disclaimer'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Rates and fee estimates are reference information, not financial or investment advice. Rates are daily reference data and may be cached or delayed. Bank, card-network, payment-provider, and merchant policies can change. Authorization and settlement dates may differ. Final posted amounts are determined by the issuer, card network, payment provider, and merchant. DCC comparisons do not guarantee a transaction result or the lowest possible cost.'**
  String get disclaimerBody;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions and data flow'**
  String get permissionsTitle;

  /// No description provided for @permissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Camera and photo-library read access are requested only after you choose the matching scan action. Add-only photo access is requested only after you tap Save to Photos on a trip-summary preview. Camera photos and selected images are processed locally with Apple Vision. Notifications and location are not required. iCloud is contacted only when structured-data sync is enabled. Receipt originals stay on this device and are not included in CloudKit sync. CSV, PDF, backups, and trip summary images are generated on this device.'**
  String get permissionsBody;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
