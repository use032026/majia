// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RoamSum';

  @override
  String get homeTab => 'Home';

  @override
  String get tripsTab => 'Trips';

  @override
  String get ledgerTab => 'Ledger';

  @override
  String get settingsTab => 'Settings';

  @override
  String get scanAction => 'Scan';

  @override
  String get homeTitle => 'Understand the real cost';

  @override
  String get homeSubtitle =>
      'Convert a local price and compare payment methods.';

  @override
  String get tripsTitle => 'Trips';

  @override
  String get tripsSubtitle =>
      'Trip budgets and offline packs will appear here.';

  @override
  String get ledgerTitle => 'Ledger';

  @override
  String get ledgerSubtitle =>
      'Saved expenses and actual charges will appear here.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Currency, rates, payments, sync, and privacy.';

  @override
  String get scanTitle => 'Scan';

  @override
  String get scanPurposeCompare => 'Compare';

  @override
  String get scanPurposeRecord => 'Record';

  @override
  String get scanSubtitle =>
      'Photograph a price tag or bill, then confirm the price before comparing payment methods.';

  @override
  String get scanRecordSubtitle =>
      'Scan a receipt or bill to prefill an expense.';

  @override
  String get scanCamera => 'Camera';

  @override
  String get scanPhotoLibrary => 'Photos';

  @override
  String get scanPrivacy =>
      'Recognition runs on this device. The original image is not uploaded.';

  @override
  String get scanRecognizing => 'Recognizing text on this device…';

  @override
  String get scanPreparingExpense => 'Recognizing and preparing the expense…';

  @override
  String get scanDetectedPrices => 'Detected prices';

  @override
  String scanDetectedPriceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prices detected',
      one: '1 price detected',
    );
    return '$_temp0';
  }

  @override
  String get scanSelectHint =>
      'Select one price, or select several to add them together.';

  @override
  String get scanLowConfidence => 'Low confidence · review this value';

  @override
  String get scanManualEntry => 'Enter an amount manually';

  @override
  String get scanManualEntryHint => 'Continue even without an image';

  @override
  String get scanRecordManualEntry => 'Add an expense manually';

  @override
  String get scanRecordManualEntryHint => 'Continue without scanning';

  @override
  String get scanCameraAction => 'Scan a photo';

  @override
  String get scanRetake => 'Retake';

  @override
  String get scanPhotoLibraryAction => 'Choose from Photos';

  @override
  String get scanManualSheetTitle => 'Enter an amount';

  @override
  String get scanManualSheetSubtitle => 'Type the listed price directly';

  @override
  String get scanEditSheetTitle => 'Confirm price';

  @override
  String get scanEditSheetSubtitle => 'Edit the recognized result';

  @override
  String get scanAmount => 'Amount';

  @override
  String get scanTransactionCurrency => 'Transaction currency';

  @override
  String get scanChooseCurrency => 'Choose currency';

  @override
  String get scanInvalidEdit => 'Enter a valid amount and choose a currency.';

  @override
  String get scanReviewBeforeContinue =>
      'Check the amount and currency before continuing.';

  @override
  String get scanSaveAndUse => 'Save and use';

  @override
  String get scanCurrencyRequired =>
      'Choose a currency for every selected price.';

  @override
  String get scanMixedCurrencies =>
      'Selected prices use different currencies. Edit them before continuing.';

  @override
  String scanSelectedTotal(String currency, String amount) {
    return 'Selected total · $currency $amount';
  }

  @override
  String get scanContinue => 'Compare payment methods';

  @override
  String get scanPermissionDenied =>
      'Access was not granted. Choose the other image source or enter the amount manually.';

  @override
  String get permissionCameraUnavailableTitle => 'Camera access is unavailable';

  @override
  String get permissionCameraUnavailableBody =>
      'Allow RoamSum to use the camera in Settings, then try again. If access is restricted by Screen Time or device management, change that restriction first.';

  @override
  String get permissionPhotoLibraryUnavailableTitle =>
      'Photo access is unavailable';

  @override
  String get permissionPhotoLibraryUnavailableBody =>
      'Allow RoamSum to access photos in Settings, then try again. If access is restricted by Screen Time or device management, change that restriction first.';

  @override
  String get permissionOpenSettings => 'Open Settings';

  @override
  String get scanImageUnavailable =>
      'This image is no longer available. Choose it again or enter the amount manually.';

  @override
  String get scanRecognitionFailed =>
      'The image could not be recognized. Try another image or enter the amount manually.';

  @override
  String get scanNoCandidates =>
      'No prices were found. Try another image or enter the amount manually.';

  @override
  String get scanRateUnavailable =>
      'No reference rate is available for this currency. Enter a manual rate on Home, then try again.';

  @override
  String get languageTitle => 'Language';

  @override
  String get systemLanguage => 'System default';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get scaffoldNotice => 'Project scaffold ready';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start exploring';

  @override
  String get onboardingScanTitle => 'Understand prices instantly';

  @override
  String get onboardingScanSubtitle =>
      'Scan price tags, menus, and receipts to make foreign prices easier to understand.';

  @override
  String get onboardingCompareTitle => 'Compare the cost to pay';

  @override
  String get onboardingCompareSubtitle =>
      'Include fees and rewards to compare the estimated cost of each payment method.';

  @override
  String get onboardingBudgetTitle => 'Keep every trip on budget';

  @override
  String get onboardingBudgetSubtitle =>
      'Add expenses to a trip and see how much of your travel budget remains.';

  @override
  String get onboardingSetupStart => 'Start setup';

  @override
  String get onboardingSetupTitle => 'Quick setup';

  @override
  String get onboardingSetupSubtitle =>
      'Takes about a minute. You can add a trip and payment methods later.';

  @override
  String onboardingSetupProgress(int completed, int total) {
    return '$completed of $total complete';
  }

  @override
  String get onboardingSetupEnterHome => 'Enter home';

  @override
  String get onboardingSetupContinue => 'Continue setup';

  @override
  String get onboardingSetupDismiss => 'Not now';

  @override
  String get onboardingSetupTripNotCreated => 'Not created';

  @override
  String onboardingSetupTripCount(int count) {
    return '$count trips created';
  }

  @override
  String get onboardingSetupPaymentNotAdded => 'Not added';

  @override
  String onboardingSetupPaymentCount(int count) {
    return '$count methods added';
  }

  @override
  String onboardingSetupCurrencySelected(String code) {
    return '$code · Selected';
  }

  @override
  String get converterInputLabel => 'Local price or expression';

  @override
  String get converterInputHint => 'For example: 1200 * 3 + 500';

  @override
  String get converterResultLabel => 'Reference conversion';

  @override
  String get converterInvalidExpression =>
      'Check the expression and edit it in place.';

  @override
  String get converterPositiveAmount => 'Enter an amount greater than zero.';

  @override
  String get converterRateLoading => 'Finding the latest reference rate…';

  @override
  String get converterRateUnavailable =>
      'No reference rate is available. Add a manual rate to continue.';

  @override
  String converterRateLive(String source, String time) {
    return 'Latest reference rate · $source · $time';
  }

  @override
  String converterRateCached(String time, String source) {
    return 'Cached at $time · $source';
  }

  @override
  String converterRateStale(String time) {
    return 'Older cache from $time · review before paying';
  }

  @override
  String get converterRateManual => 'Using your manual reference rate';

  @override
  String converterRateCard(String source, String time) {
    return 'Card-network reference · $source · $time';
  }

  @override
  String get converterRateIdentity => 'Same currency · rate 1';

  @override
  String get converterManualRate => 'Enter manual rate';

  @override
  String get converterManualRateHint =>
      '1 local currency = how much home currency';

  @override
  String get converterAdjustRate => 'Adjust';

  @override
  String get converterRateSheetTitle => 'Choose exchange rate';

  @override
  String get converterMarketReference => 'API reference rate';

  @override
  String get converterMarketUnavailable => 'No API reference rate available';

  @override
  String get converterManualReference => 'Manual rate';

  @override
  String converterRateSourceDetail(String source, String time) {
    return '$source · $time';
  }

  @override
  String converterRateUnit(String quote, String base) {
    return '$quote / $base';
  }

  @override
  String get converterUseMarketRate => 'Use API reference rate';

  @override
  String get converterSaveAndUse => 'Save and use';

  @override
  String converterRateDifferenceLower(String percent) {
    return '$percent% below the API reference rate';
  }

  @override
  String converterRateDifferenceHigher(String percent) {
    return '$percent% above the API reference rate';
  }

  @override
  String get converterRateDifferenceSame => 'Matches the API reference rate';

  @override
  String get converterRefresh => 'Refresh rate';

  @override
  String get converterCompare => 'Compare payment methods';

  @override
  String get converterDcc => 'Check DCC';

  @override
  String get converterRecentTitle => 'Recent expenses';

  @override
  String get converterRecentEmpty => 'Saved expenses will appear here.';

  @override
  String get currencyLocal => 'Transaction currency';

  @override
  String get currencyHome => 'Home currency';

  @override
  String get currencyCommonTrading => 'Common trading currencies';

  @override
  String get currencyAllTrading => 'All trading currencies';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonManage => 'Manage';

  @override
  String get commonEstimated => 'Estimated';

  @override
  String get paymentMethodsTitle => 'Payment methods';

  @override
  String get paymentMethodsSubtitle =>
      'Store fee rules only. Never enter card numbers, expiry dates, CVV, identity, or banking credentials.';

  @override
  String get paymentMethodsEmpty =>
      'Add cash or a card to compare estimated costs.';

  @override
  String get paymentAddTitle => 'Add payment method';

  @override
  String get paymentEditorQuickStart => 'Quick setup';

  @override
  String get paymentEditorTemplateHint =>
      'Start with a common rule, then fine-tune it below';

  @override
  String get paymentEditorBasics => 'Basic details';

  @override
  String get paymentEditorFees => 'Fee rules';

  @override
  String get paymentEditorOptional => 'Optional details';

  @override
  String get paymentEditName => 'Name';

  @override
  String get paymentNamePlaceholder => 'Enter a payment method name';

  @override
  String get paymentOptionalPlaceholder => 'Optional';

  @override
  String get paymentNotesPlaceholder =>
      'Optional, such as usage conditions or notes';

  @override
  String get paymentType => 'Type';

  @override
  String get paymentNetwork => 'Card network';

  @override
  String get paymentBillingCurrency => 'Billing currency';

  @override
  String get paymentTemplate => 'Template';

  @override
  String get paymentForeignFee => 'Foreign conversion fee %';

  @override
  String get paymentCrossBorderFee => 'Cross-border fee %';

  @override
  String get paymentRateMarkup => 'Exchange-rate markup %';

  @override
  String get paymentFixedFee => 'Fixed fee';

  @override
  String get paymentCashback => 'Cashback %';

  @override
  String get paymentMinimumFee => 'Minimum variable fee (optional)';

  @override
  String get paymentMaximumFee => 'Maximum variable fee (optional)';

  @override
  String get paymentCashRate => 'Actual cash exchange rate (optional)';

  @override
  String get paymentNotes => 'Notes (optional)';

  @override
  String get paymentTransactionScope => 'Applies to';

  @override
  String get paymentPurchase => 'Purchases';

  @override
  String get paymentAtm => 'ATM';

  @override
  String get paymentAll => 'Purchases and ATM';

  @override
  String get paymentTypeCredit => 'Credit card';

  @override
  String get paymentTypeDebit => 'Debit card';

  @override
  String get paymentTypeCash => 'Cash';

  @override
  String get paymentTypeWallet => 'Digital wallet';

  @override
  String get paymentTypeCustom => 'Custom';

  @override
  String get paymentNetworkUnknown => 'Unknown';

  @override
  String get paymentNetworkOther => 'Other';

  @override
  String get paymentInvalidForm =>
      'Check the name, non-negative rates and fee limits.';

  @override
  String get paymentDeleteTitle => 'Delete this payment method?';

  @override
  String get paymentDeleteMessage =>
      'Historical expense snapshots remain unchanged.';

  @override
  String get paymentPolicyNotice =>
      'Generic estimate only. Bank and card-network policies may change.';

  @override
  String get paymentComparisonTitle => 'Estimated payment costs';

  @override
  String get paymentComparisonMissing =>
      'Start from a valid conversion to compare costs.';

  @override
  String get paymentComparisonNeedTwo =>
      'Add at least two applicable methods for a useful comparison.';

  @override
  String paymentComparisonNoApplicable(String currency) {
    return 'You have payment methods, but none apply to purchases billed in $currency. Check their billing currency and transaction type.';
  }

  @override
  String paymentComparisonOnlyOne(String currency) {
    return 'Only one payment method applies to purchases billed in $currency. Manage your existing rules to compare another.';
  }

  @override
  String get paymentComparisonConfiguredButUnavailable =>
      'Your payment methods are still saved; they just cannot be used for this conversion.';

  @override
  String get paymentRecommended => 'Lowest estimated cost';

  @override
  String paymentDifference(String amount) {
    return '+$amount vs lowest';
  }

  @override
  String get paymentBaseAmount => 'Base conversion';

  @override
  String get paymentRateMarkupAmount => 'Rate markup';

  @override
  String get paymentForeignFeeAmount => 'Foreign conversion fee';

  @override
  String get paymentCrossBorderFeeAmount => 'Cross-border fee';

  @override
  String get paymentVariableFee => 'Variable fee after limits';

  @override
  String get paymentFixedFeeAmount => 'Fixed fee';

  @override
  String get paymentCashbackAmount => 'Estimated cashback';

  @override
  String get paymentEstimatedTotal => 'Estimated total';

  @override
  String get paymentCashRateUsed => 'Uses your actual cash exchange rate';

  @override
  String get paymentEstimateDisclaimer =>
      'All figures are estimates. Final charges depend on the merchant, card network, issuer and posting date.';

  @override
  String get dccTitle => 'DCC check';

  @override
  String get dccLocalAmount => 'Local-currency amount';

  @override
  String get dccMerchantQuote => 'Merchant home-currency quote';

  @override
  String get dccOptionalPayment => 'Payment method (optional)';

  @override
  String get dccNoPayment => 'No payment method';

  @override
  String get dccImpliedRate => 'Merchant implied rate';

  @override
  String get dccReferenceRate => 'Reference rate';

  @override
  String get dccReferenceAmount => 'Reference conversion';

  @override
  String get dccExtraAmount => 'DCC extra amount';

  @override
  String get dccExtraPercent => 'DCC extra percentage';

  @override
  String get dccLocalPaymentEstimate =>
      'Estimated cost if paying in local currency';

  @override
  String dccGuidanceHigher(String percent) {
    return 'The merchant quote is about $percent% above the current reference conversion. Paying in local currency is usually more transparent, but the final charge still depends on the issuer.';
  }

  @override
  String get dccGuidanceLower =>
      'The merchant quote is not above the current reference conversion. This is still only a comparison; verify the currency and final amount on the terminal.';

  @override
  String get dccInvalidLocal => 'Enter a local amount greater than zero.';

  @override
  String get dccInvalidQuote => 'Enter a merchant quote greater than zero.';

  @override
  String get dccSameCurrency => 'DCC requires two different currencies.';

  @override
  String get dccMissingRate =>
      'A reference rate is required before checking DCC.';

  @override
  String get templateNoForeignFee => 'No foreign-fee card';

  @override
  String get templateOnePercent => '1% fee card';

  @override
  String get templateOnePointFivePercent => '1.5% fee card';

  @override
  String get templateTwoPercent => '2% fee card';

  @override
  String get templateUnionPayCny => 'UnionPay CNY billing card';

  @override
  String get templateCash => 'Cash exchange';

  @override
  String get templateCustom => 'Fully custom';

  @override
  String get onboardingHomeCurrency => 'Suggested home currency';

  @override
  String get onboardingCreateTrip => 'Create a trip';

  @override
  String get onboardingAddPayment => 'Add payment method';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get tripCreate => 'New trip';

  @override
  String get tripEdit => 'Edit trip';

  @override
  String get tripCopy => 'Copy configuration';

  @override
  String get tripArchive => 'Archive';

  @override
  String get tripDeleteTitle => 'Delete this trip?';

  @override
  String get tripDeleteMessage =>
      'Expenses stay in the ledger without this trip. Choose whether their local receipt images should also be removed. This cannot be undone.';

  @override
  String get tripExport => 'Export this trip';

  @override
  String get tripDeleteKeepReceipts => 'Delete trip, keep receipts';

  @override
  String get tripDeleteWithReceipts => 'Delete trip and receipts';

  @override
  String get tripReceiptDeletePartial =>
      'The trip was deleted, but some receipt images could not be removed.';

  @override
  String get tripName => 'Trip name';

  @override
  String get tripDestinations => 'Countries or regions';

  @override
  String get tripDestinationsHint => 'For example: JP, KR';

  @override
  String get tripDestinationsEmpty => 'Select';

  @override
  String get tripCurrentAndUpcoming => 'Current & upcoming';

  @override
  String get tripHistoryTab => 'History';

  @override
  String get tripRoutePlannerTitle => 'Plan a multi-country route';

  @override
  String get tripRoutePlannerSubtitle =>
      'Add stops in order. Budget and insights cover the whole trip.';

  @override
  String get tripStopsTitle => 'Destinations & stays';

  @override
  String get tripAddNextStop => 'Add next stop';

  @override
  String get tripWholeRange => 'Whole trip';

  @override
  String get tripDateRangePickerTitle => 'Select date range';

  @override
  String get tripWholeBudget => 'Whole-trip budget';

  @override
  String get tripMoreSettings => 'More settings';

  @override
  String get tripCurrentStop => 'Current';

  @override
  String get tripNextStop => 'Next';

  @override
  String tripDaysLater(int count) {
    return 'In $count days';
  }

  @override
  String tripDayCount(int count) {
    return '$count days';
  }

  @override
  String tripStopDayProgress(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String tripBudgetUsed(String percent) {
    return '$percent% used';
  }

  @override
  String tripBudgetRemainingPercent(String percent) {
    return '$percent% remaining';
  }

  @override
  String get tripDailyBudgetHint =>
      'Based on remaining days · updates automatically';

  @override
  String tripDailyBudgetApprox(String amount) {
    return 'About $amount / day';
  }

  @override
  String get tripViewAction => 'View trip';

  @override
  String get tripRecordAction => 'Add expense';

  @override
  String get tripRouteRequired => 'Add at least one destination.';

  @override
  String get tripAdjustStopEnd => 'Adjust departure date';

  @override
  String get tripChangeDestination => 'Change destination';

  @override
  String get tripChangeStopCurrency => 'Change local currency';

  @override
  String get tripRemoveStop => 'Remove this stop';

  @override
  String get tripOfflineMultiHint =>
      'Includes every local currency without requesting location.';

  @override
  String get countrySearchEmpty => 'No countries or regions found';

  @override
  String get countryUnknownSaved =>
      'Saved but unrecognized; select a valid destination before removing';

  @override
  String get tripStartDate => 'Start date';

  @override
  String get tripEndDate => 'End date';

  @override
  String get tripLocalCurrencies => 'Local currencies';

  @override
  String get tripLocalCurrenciesPending =>
      'Recommended after destination selection';

  @override
  String get tripLocalCurrenciesMissing => 'Not recognized; select manually';

  @override
  String tripLocalCurrenciesRecommended(String currencies) {
    return '$currencies · Recommended';
  }

  @override
  String get tripCurrencyRecommendationTitle => 'Update local currencies?';

  @override
  String tripCurrencyRecommendationMessage(String currencies) {
    return 'The selected countries or regions commonly use $currencies. Update the local currencies?';
  }

  @override
  String get tripCurrencyRecommendationKeep => 'Keep current';

  @override
  String get tripCurrencyRecommendationUpdate => 'Update';

  @override
  String get tripBudget => 'Total budget';

  @override
  String get tripBudgetOptional => 'Optional; zero is allowed';

  @override
  String get tripParticipants => 'Travelers';

  @override
  String get tripDefaultPayment => 'Default payment method';

  @override
  String get tripOfflinePack => 'Offline rate pack';

  @override
  String get tripOfflinePackHint =>
      'Prepare the selected local and home currency pair without requesting location.';

  @override
  String get tripInvalid =>
      'Check the name, dates, currencies, budget and traveler count.';

  @override
  String get tripActive => 'In progress';

  @override
  String get tripUpcoming => 'Upcoming';

  @override
  String get tripHistory => 'History';

  @override
  String get tripMissing => 'This trip is no longer available.';

  @override
  String get tripNoBudget => 'No budget';

  @override
  String get tripSpent => 'Spent';

  @override
  String get tripRemaining => 'Remaining';

  @override
  String get tripDailyRemaining => 'Remaining per day';

  @override
  String get tripDayProgress => 'Trip days';

  @override
  String get tripDailyAverage => 'Current daily average';

  @override
  String get tripPaymentBreakdown => 'Payment-method breakdown';

  @override
  String get tripOfflineReady => 'Offline pack ready';

  @override
  String get tripOfflineMissing => 'Offline pack not downloaded';

  @override
  String get expenseManualAdd => 'Add expense';

  @override
  String expenseOcrPrefillBanner(int count) {
    return 'Filled $count items from the receipt. Please review them.';
  }

  @override
  String get expenseOcrNeedsConfirmation => 'Review';

  @override
  String get expenseSave => 'Save expense';

  @override
  String get expenseRecent => 'Recent expenses';

  @override
  String get expenseEditorBasics => 'Basic information';

  @override
  String get expenseEditorAmount => 'Amount';

  @override
  String get expenseEditorPaymentStatus => 'Payment and status';

  @override
  String get expenseEditorTripCategory => 'Trip and category';

  @override
  String get expenseEditorAdjustments => 'Adjustments and travelers';

  @override
  String get expenseEditorLiveHint =>
      'Updates with the trip, currencies, and payment method';

  @override
  String get expenseTitle => 'Merchant or item';

  @override
  String get expenseTitlePlaceholder => 'Enter merchant or item';

  @override
  String get expenseTrip => 'Trip';

  @override
  String get expenseCategory => 'Category';

  @override
  String get expenseTransactionAmount => 'Transaction amount';

  @override
  String get expenseTransactionAmountPlaceholder => 'Enter transaction amount';

  @override
  String get expenseReferenceAmount => 'Reference conversion';

  @override
  String get expenseEstimatedAmount => 'Estimated final amount';

  @override
  String get expenseActualAmount => 'Actual posted amount';

  @override
  String get expensePaymentMethod => 'Payment method';

  @override
  String get expenseTax => 'Tax in home currency';

  @override
  String get expenseTip => 'Tip in home currency';

  @override
  String get expenseDiscount => 'Discount in home currency';

  @override
  String get expenseDate => 'Transaction date';

  @override
  String get expenseReceiptPath => 'Receipt attachment (optional)';

  @override
  String get expenseReceiptSection => 'Receipt attachment';

  @override
  String get expenseReceiptReplace => 'Replace';

  @override
  String get expenseReceiptAdd => 'Add photo';

  @override
  String get expenseReceiptRemove => 'Remove receipt';

  @override
  String get expenseNotes => 'Notes';

  @override
  String get expenseBudgetIncluded => 'Include in trip budget';

  @override
  String get expenseStatus => 'Status';

  @override
  String get expenseAmountStatus => 'Amount status';

  @override
  String get expensePending => 'Pending';

  @override
  String get expenseConfirmed => 'Posted';

  @override
  String get expenseInvalid =>
      'Check the title, positive amounts, currencies and traveler count.';

  @override
  String get expenseMissingRequired =>
      'Merchant name and transaction amount are still required.';

  @override
  String get expenseDuplicateTitle => 'Possible duplicate expense';

  @override
  String get expenseDuplicateMessage =>
      'A matching expense was saved within five minutes. Save another copy?';

  @override
  String get expenseSaveAnyway => 'Save anyway';

  @override
  String get expenseMissing => 'This expense is no longer available.';

  @override
  String get expenseDifference => 'Difference from estimate';

  @override
  String get expenseRateSnapshot => 'Saved rate snapshot';

  @override
  String get expensePaymentSnapshot => 'Saved fee-rule snapshot';

  @override
  String get expenseActualConflict =>
      'Two actual posted amounts need conflict resolution before sync can continue.';

  @override
  String get expenseRecordActual => 'Record actual amount';

  @override
  String get expenseEditActual => 'Edit actual amount';

  @override
  String get expenseAdjust => 'Refund or void';

  @override
  String get expenseRefund => 'Refund';

  @override
  String get expensePartialRefund => 'Partial refund';

  @override
  String get expenseVoid => 'Voided';

  @override
  String get expenseRefundInvalid =>
      'The refund must be greater than zero and cannot exceed the original posted amount.';

  @override
  String get expenseRefundStatus => 'Refund status';

  @override
  String get expenseRefundNone => 'No refund';

  @override
  String get expenseRefundPartialStatus => 'Partially refunded';

  @override
  String get expenseRefundFullStatus => 'Fully refunded';

  @override
  String get expenseRefundInvalidStatus => 'Invalid refund amount';

  @override
  String get expenseRefundedTotal => 'Total refunded';

  @override
  String get expenseNetAmount => 'Net expense';

  @override
  String get expenseRefundRecords => 'Refund records';

  @override
  String get expenseRelatedOriginal => 'Original expense';

  @override
  String get expenseViewOriginal => 'View original expense';

  @override
  String get expenseCorrectOriginal => 'Correct original amount';

  @override
  String get expenseCorrectRefund => 'Correct refund amount';

  @override
  String get expenseRecordRefund => 'Record refund';

  @override
  String get expenseContinueRefund => 'Continue refund';

  @override
  String get expenseVoidAction => 'Void record';

  @override
  String get expenseVoidConfirm =>
      'Only an expense that has not posted can be voided. Void this record?';

  @override
  String get expenseCorrectionWarning =>
      'Changing the original amount may change the refund status, but it will not change existing refund amounts.';

  @override
  String get expenseAdjustmentInvalid =>
      'This action cannot be completed. Check the original amount and total refunded.';

  @override
  String get expenseManualRateSource => 'Manual ledger rate';

  @override
  String get expenseManualPaymentRule => 'Manual entry';

  @override
  String get ledgerTimeline => 'Details';

  @override
  String get ledgerCalendar => 'Calendar';

  @override
  String get ledgerCategories => 'Categories';

  @override
  String get ledgerFilters => 'Filters';

  @override
  String get ledgerClearFilters => 'Clear';

  @override
  String get ledgerThisMonth => 'This month';

  @override
  String get ledgerLastMonth => 'Last month';

  @override
  String get ledgerAllTime => 'All time';

  @override
  String get ledgerThisMonthSpending => 'This month spending';

  @override
  String get ledgerLastMonthSpending => 'Last month spending';

  @override
  String get ledgerTotalSpending => 'Total spending';

  @override
  String ledgerSummaryCount(int count, String currencyCode) {
    return '$count records · Calculated in $currencyCode';
  }

  @override
  String ledgerToday(String date) {
    return 'Today · $date';
  }

  @override
  String ledgerDayCount(int count) {
    return '$count records';
  }

  @override
  String get ledgerEmpty => 'No matching expenses yet.';

  @override
  String get ledgerMinimumAmount => 'Minimum amount';

  @override
  String get ledgerMaximumAmount => 'Maximum amount';

  @override
  String get ledgerInvalidFilters => 'Enter a valid non-negative amount range.';

  @override
  String ledgerFilteredCount(int count) {
    return '$count expenses';
  }

  @override
  String ledgerRecentDays(int count) {
    return 'Last $count days';
  }

  @override
  String ledgerRecentDaysShort(int count) {
    return '${count}d';
  }

  @override
  String get ledgerCustomDate => 'Custom';

  @override
  String get ledgerDateRangePickerTitle => 'Select date range';

  @override
  String get ledgerStartDate => 'Start date';

  @override
  String get ledgerEndDate => 'End date';

  @override
  String ledgerViewRecords(int count) {
    return 'View $count records';
  }

  @override
  String get ledgerSelectionSeparator => ', ';

  @override
  String get calibrationNone =>
      'Record an actual amount to build a local fee comparison.';

  @override
  String calibrationRange(int count, String minimum, String maximum) {
    return 'Recent $count comparable charges: $minimum% to $maximum% markup. Three or more records are required before suggesting a rule change.';
  }

  @override
  String calibrationRangeReady(int count, String minimum, String maximum) {
    return 'Recent $count comparable charges: $minimum% to $maximum% markup. Review them before manually changing the rule.';
  }

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryHotel => 'Hotel';

  @override
  String get categoryTickets => 'Tickets';

  @override
  String get categoryOther => 'Other';

  @override
  String get syncTitle => 'iCloud sync';

  @override
  String get syncEnable => 'Sync structured data with iCloud';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncStatusDisabled => 'Sync is off. Local data is unchanged.';

  @override
  String get syncStatusIdle => 'Ready to sync';

  @override
  String get syncStatusWorking => 'Syncing…';

  @override
  String get syncStatusSucceeded => 'Up to date';

  @override
  String get syncCompletedNotice =>
      'iCloud sync complete. Latest data is now shown.';

  @override
  String get syncStatusWaiting => 'Waiting to retry';

  @override
  String get syncStatusFailed => 'Sync failed. Local data remains available.';

  @override
  String get syncStatusNoAccount => 'Sign in to iCloud to sync.';

  @override
  String get syncStatusRestricted => 'iCloud is restricted on this device.';

  @override
  String syncLastSuccess(String value) {
    return 'Last successful sync: $value';
  }

  @override
  String syncFailureReason(String value) {
    return 'Reason: $value';
  }

  @override
  String get syncActualConflict => 'Two posted amounts need your choice.';

  @override
  String syncConflictValues(String local, String remote) {
    return 'On this device: $local · In iCloud: $remote';
  }

  @override
  String get syncKeepLocal => 'Keep this device';

  @override
  String get syncUseCloud => 'Use iCloud';

  @override
  String get commonContinue => 'Continue';

  @override
  String get settingsLoadFailed =>
      'Settings could not be loaded. Local data is unchanged.';

  @override
  String get settingsSectionCommon => 'Common';

  @override
  String get settingsSectionDataDevices => 'Data and devices';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsPaymentMethodsSummary => 'Manage cards, cash, and fees';

  @override
  String get settingsDataSummary => 'Export, backup, and cleanup';

  @override
  String get settingsPrivacySummary => 'Policies, permissions, and disclaimers';

  @override
  String get kifxMiniTitle => 'KIFX Mini Program';

  @override
  String get kifxMiniSubtitle => 'Tap to open the KIFX Mini Program';

  @override
  String get kifxMiniUnavailable =>
      'The KIFX Mini Program is available on iOS only.';

  @override
  String get kifxMiniOpenFailed =>
      'The KIFX Mini Program cannot be opened right now. Try again later.';

  @override
  String get syncStatusEnabledShort => 'On';

  @override
  String get syncStatusDisabledShort => 'Off';

  @override
  String get rateSettingsTitle => 'Currency and rates';

  @override
  String get defaultCurrency => 'Default home currency';

  @override
  String get refreshInterval => 'Automatic refresh';

  @override
  String refreshEveryHours(int count) {
    return 'Every $count hours';
  }

  @override
  String get wifiOnlyRefresh => 'Refresh rates on Wi-Fi only';

  @override
  String get decimalDisplayRule => 'Decimal display';

  @override
  String get decimalDisplayCurrencyDefault =>
      'Use each currency’s standard digits';

  @override
  String get dataTitle => 'Data, backup, and export';

  @override
  String get exportCsv => 'Export expenses as CSV';

  @override
  String get exportPdf => 'Export expenses as PDF';

  @override
  String get tripSummaryImageExport => 'Save trip summary image';

  @override
  String get tripSummaryImageTitle => 'Trip summary';

  @override
  String get tripSummaryImageSaveToPhotos => 'Save to Photos';

  @override
  String get tripSummaryImageSaved => 'Trip summary saved to Photos.';

  @override
  String get tripSummaryImagePermissionDenied =>
      'Photos access is off. Allow RoamSum to add photos in Settings, then try again.';

  @override
  String get tripSummaryImageSaveFailed =>
      'The trip summary could not be saved to Photos.';

  @override
  String tripSummaryImageGeneratedAt(String date) {
    return 'Generated $date';
  }

  @override
  String get tripSummaryImageDisclaimer =>
      'For personal reference. Receipt images and expense details are not included.';

  @override
  String get exportEmpty => 'There are no expenses to export.';

  @override
  String get exportTooLarge =>
      'This export contains more than 20,000 records. Export a smaller data set.';

  @override
  String get exportFailed => 'The export could not be created or shared.';

  @override
  String get backupCreate => 'Create local backup';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupFailed => 'The backup could not be created or shared.';

  @override
  String get backupRestoreTitle => 'Restore this backup?';

  @override
  String get backupRestoreMessage =>
      'A valid backup replaces the current local database. If validation fails, the current database remains unchanged.';

  @override
  String get backupRestored => 'The backup was restored.';

  @override
  String get backupRestoreFailed =>
      'This backup is invalid, unsupported, or could not be restored. Current data was not replaced.';

  @override
  String get clearReceiptImages => 'Clear receipt images';

  @override
  String get clearReceiptImagesTitle => 'Clear all receipt images?';

  @override
  String get clearReceiptImagesMessage =>
      'Expense records remain, but their local image references will be removed. This cannot be undone.';

  @override
  String get clearReceiptImagesDone =>
      'Receipt images and their local references were cleared.';

  @override
  String get clearAllData => 'Clear all data';

  @override
  String get clearAllDataTitle => 'Clear all local data?';

  @override
  String get clearAllDataMessage =>
      'This removes trips, expenses, rates, payment methods, settings, receipt images, sync state, and the Widget snapshot.';

  @override
  String get clearAllDataAgainTitle => 'Confirm permanent deletion';

  @override
  String get clearAllDataAgainMessage =>
      'This action cannot be undone. Continue only if you have exported anything you need.';

  @override
  String get clearDataFailed =>
      'The data could not be cleared completely. No success was recorded.';

  @override
  String get privacyTitle => 'Privacy and about';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get privacyPolicyLoadFailed =>
      'The privacy policy could not be loaded. Check your connection and try again.';

  @override
  String get privacyPolicyBody =>
      'RoamSum does not require an account and does not store full card numbers, CVV, identity documents, or banking credentials. Trips, expenses, settings, and receipt images are stored on this device. OCR runs on this device. Receipt originals are not uploaded. If you enable iCloud sync, structured app data is sent to your private CloudKit database; receipt originals are excluded. Market reference-rate requests are sent to Frankfurter. Frankfurter states that its API does not collect personal data, while its public service uses Cloudflare and may collect basic analytics information. Exports and backups are generated locally and leave the app only when you choose a destination in the system share sheet. Trip summary images are added to Photos only after you tap Save to Photos; any iCloud Photos sync follows your system settings.';

  @override
  String get disclaimerTitle => 'Rates and cost disclaimer';

  @override
  String get disclaimerBody =>
      'Rates and fee estimates are reference information, not financial or investment advice. Rates are daily reference data and may be cached or delayed. Bank, card-network, payment-provider, and merchant policies can change. Authorization and settlement dates may differ. Final posted amounts are determined by the issuer, card network, payment provider, and merchant. DCC comparisons do not guarantee a transaction result or the lowest possible cost.';

  @override
  String get permissionsTitle => 'Permissions and data flow';

  @override
  String get permissionsBody =>
      'Camera and photo-library read access are requested only after you choose the matching scan action. Add-only photo access is requested only after you tap Save to Photos on a trip-summary preview. Camera photos and selected images are processed locally with Apple Vision. Notifications and location are not required. iCloud is contacted only when structured-data sync is enabled. Receipt originals stay on this device and are not included in CloudKit sync. CSV, PDF, backups, and trip summary images are generated on this device.';
}
