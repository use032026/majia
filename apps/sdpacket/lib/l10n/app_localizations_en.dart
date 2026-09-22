// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KIFXPRO';

  @override
  String get loading => 'Loading local data…';

  @override
  String get retry => 'Retry';

  @override
  String get projects => 'Moving projects';

  @override
  String get activeProjects => 'Active';

  @override
  String get newProject => 'New project';

  @override
  String get globalSearch => 'Global search';

  @override
  String get archivedProjects => 'Archived projects';

  @override
  String get settings => 'Settings';

  @override
  String get moreActions => 'More actions';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String get languageChangeFailed => 'Couldn\'t change language. Try again.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingQuickTitle => 'Register each box in seconds';

  @override
  String get onboardingQuickBody =>
      'Take a photo or enter a short note. Your box record is saved locally right away.';

  @override
  String get onboardingFindTitle => 'Find packed items offline';

  @override
  String get onboardingFindBody =>
      'Search box codes, rooms, notes and item names even when you have no signal.';

  @override
  String get onboardingTrackTitle => 'Keep every move stage clear';

  @override
  String get onboardingTrackBody =>
      'Track packed, loaded, arrived and unpacked boxes without mixing up digital records and physical labels.';

  @override
  String onboardingProgress(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get onboardingSavingFailed =>
      'Couldn\'t save your onboarding choice. Try again.';

  @override
  String get noProjects => 'No moving projects yet';

  @override
  String get noProjectsHint => 'Create a project to start registering boxes.';

  @override
  String get sampleProjectName => 'Sample move';

  @override
  String get sampleOrigin => 'Old home';

  @override
  String get sampleDestination => 'New home';

  @override
  String get sampleMemo => 'Coffee maker, cups and filters';

  @override
  String get projectName => 'Project name';

  @override
  String get origin => 'Origin (optional)';

  @override
  String get destination => 'Destination (optional)';

  @override
  String get boxPrefix => 'Box prefix';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get edit => 'Edit';

  @override
  String get archive => 'Archive';

  @override
  String get restore => 'Restore';

  @override
  String get delete => 'Delete';

  @override
  String get deleteProjectConfirm =>
      'Deleting this project also deletes its box records. Old labels may remain on physical boxes. Continue?';

  @override
  String get deleteBoxConfirm =>
      'This box number will not be reused. Old labels may remain on the physical box. Continue?';

  @override
  String boxCount(int count) {
    return '$count boxes';
  }

  @override
  String get quickEntry => 'Quick entry';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get continuousCamera => 'Continuous camera';

  @override
  String get choosePhotos => 'Choose photos';

  @override
  String get voiceEntry => 'Voice entry';

  @override
  String get manualEntry => 'Manual entry';

  @override
  String get photoLimit => 'Choose up to 30 photos per batch.';

  @override
  String batchCaptureCount(int count) {
    return '$count boxes captured';
  }

  @override
  String get batchCaptureHint =>
      'Each photo immediately creates and saves a box draft. Keep shooting, then edit the batch box by box.';

  @override
  String get noBatchPhotos => 'Photograph the first box to start this batch.';

  @override
  String get editBatch => 'Edit batch';

  @override
  String get takeNextPhoto => 'Next box photo';

  @override
  String batchProgress(int current, int total) {
    return 'Box $current / $total';
  }

  @override
  String get applyToRemaining => 'Apply to batch';

  @override
  String get applyToRemainingHint =>
      'Apply to batch copies the current room and tags to this and all remaining boxes.';

  @override
  String get batchDetailsApplied =>
      'Room and tags applied to the remaining batch';

  @override
  String get skip => 'Skip';

  @override
  String get saveAndNext => 'Save and next';

  @override
  String get finishBatch => 'Save and finish';

  @override
  String get batchUnavailable => 'This entry batch is finished or unavailable.';

  @override
  String get resumeBatch => 'Resume unfinished batch';

  @override
  String batchCreated(int count, Object from, Object to) {
    return 'Created $count box records: $from to $to';
  }

  @override
  String get physicalMarkTitle => 'Mark the physical box';

  @override
  String physicalMarkMessage(Object code) {
    return 'Digital record $code was created. Write the code on the box, use a sticky note, or attach a QR label.';
  }

  @override
  String physicalMarkBatchMessage(int count) {
    return 'Created $count digital records. Match each photo and code to a physical box to avoid mix-ups.';
  }

  @override
  String get qrLabel => 'QR label attached';

  @override
  String get handwritten => 'Code handwritten';

  @override
  String get stickyNote => 'Sticky note attached';

  @override
  String get other => 'Other method';

  @override
  String get later => 'Do later';

  @override
  String get pendingPhysicalMark => 'Needs physical mark';

  @override
  String get marked => 'Mark confirmed';

  @override
  String get progress => 'Move progress';

  @override
  String get total => 'Total';

  @override
  String get packed => 'Packed';

  @override
  String get loaded => 'Loaded';

  @override
  String get arrived => 'Arrived';

  @override
  String get unpacked => 'Unpacked';

  @override
  String get draft => 'Draft';

  @override
  String get suspectedMissing => 'Possibly missing';

  @override
  String get damagedBox => 'Box damaged';

  @override
  String get damagedContents => 'Contents damaged';

  @override
  String get priority => 'Unpack first';

  @override
  String get normal => 'Normal';

  @override
  String get searchBoxes => 'Search code, notes, items, room or tags';

  @override
  String get noResults => 'No matching results';

  @override
  String get boxCode => 'Box code';

  @override
  String get boxInformation => 'Box information';

  @override
  String get contentsAndNotes => 'Contents & notes';

  @override
  String get movingAndFlags => 'Moving & flags';

  @override
  String get boxTitle => 'Title (optional)';

  @override
  String get destinationRoom => 'Destination room (optional)';

  @override
  String get currentLocation => 'Current location (optional)';

  @override
  String get memo => 'Notes (optional)';

  @override
  String get tags => 'Tags';

  @override
  String get tagsHint => 'Separate with commas, e.g. Fragile, Keep dry';

  @override
  String get items => 'Structured items';

  @override
  String get itemsHint => 'Separate item names with commas (optional)';

  @override
  String get addItem => 'Add item';

  @override
  String get editItem => 'Edit item';

  @override
  String get itemName => 'Item name';

  @override
  String get itemNameRequired => 'Enter an item name';

  @override
  String get itemQuantity => 'Quantity (optional)';

  @override
  String get itemQuantityInvalid => 'Enter an integer greater than 0';

  @override
  String itemQuantityValue(int quantity) {
    return 'Quantity $quantity';
  }

  @override
  String get itemNote => 'Item note (optional)';

  @override
  String get noStructuredItems =>
      'No structured items yet. You can keep using free-form notes only.';

  @override
  String get quickTemplates => 'Quick templates';

  @override
  String get templateKitchen => 'Kitchen';

  @override
  String get templateBedroom => 'Bedroom';

  @override
  String get templateOldHome => 'Old home';

  @override
  String get templateNewHome => 'New home';

  @override
  String get templateStorage => 'Storage';

  @override
  String get templateFragile => 'Fragile';

  @override
  String get templateKeepDry => 'Keep dry';

  @override
  String get templateUnpackFirst => 'Unpack first';

  @override
  String get duplicateCode => 'This code is already used in the project';

  @override
  String get boxSaved => 'Box record saved';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get qrAndPrint => 'QR and printing';

  @override
  String get labelDocumentTitle => 'KIFXPRO Labels';

  @override
  String get labelBrand => 'KIFXPRO';

  @override
  String get scanOrSearchCode => 'SCAN OR SEARCH CODE';

  @override
  String get scan => 'Scan box label';

  @override
  String get movingScanMode => 'Moving-site scanner';

  @override
  String get scanTargetStatus => 'Advance scanned boxes to';

  @override
  String repeatedScan(Object code, Object status) {
    return '$code was already scanned or is already at $status or later';
  }

  @override
  String scanUpdated(Object code, Object status) {
    return '$code updated to $status';
  }

  @override
  String scannedCount(int count) {
    return '$count scanned this session';
  }

  @override
  String unscannedCount(int count) {
    return '$count still need scanning';
  }

  @override
  String get viewUnscanned => 'Unscanned list';

  @override
  String get allScanned => 'No boxes remain for the selected target stage.';

  @override
  String get unsupportedQr =>
      'This is not a supported box label. Go back and search by code instead.';

  @override
  String get boxNotFound =>
      'The label is valid, but its box record is not on this device.';

  @override
  String get moveStatus => 'Move status';

  @override
  String get statusHistory => 'Status history';

  @override
  String get undoLastStatus => 'Undo latest';

  @override
  String get noStatusHistory => 'No status changes yet.';

  @override
  String get statusUndoSuccess => 'The latest status change was undone';

  @override
  String get statusSourceManual => 'Manual edit';

  @override
  String get statusSourceScanner => 'Moving-site scan';

  @override
  String get issues => 'Issue flags';

  @override
  String get physicalMark => 'Physical mark';

  @override
  String get exportSinglePdf => 'Share single PDF';

  @override
  String get exportPng => 'Share high-resolution PNG';

  @override
  String get printLabel => 'System print';

  @override
  String get exportA4Pdf => 'Share all A4 labels';

  @override
  String get labelExportedNotice =>
      'The label was exported, but you still need to confirm it was attached or the code was written on the physical box.';

  @override
  String noPrinterHint(Object code) {
    return 'No printer is required. Write $code clearly on the box or on a sticky note and attach it.';
  }

  @override
  String get exportCsv => 'Export project CSV';

  @override
  String get projectReport => 'Project closeout report';

  @override
  String reportGeneratedAt(Object value) {
    return 'Generated: $value';
  }

  @override
  String get reportDamaged => 'Damaged boxes';

  @override
  String get roomDistribution => 'Room distribution';

  @override
  String get reportNone => 'None';

  @override
  String get unassignedRoom => 'No room assigned';

  @override
  String get moreRooms => 'Other rooms';

  @override
  String get backup => 'Share local backup';

  @override
  String get restoreBackup => 'Restore from file';

  @override
  String get restoreWarning =>
      'The backup is fully validated first. A valid backup replaces current local data; invalid data never overwrites existing records.';

  @override
  String get restoreSuccess => 'Backup restored';

  @override
  String restoreSuccessMissingPhotos(int count) {
    return 'Backup restored with $count missing photos';
  }

  @override
  String get invalidBackup =>
      'Invalid or unsupported backup. Existing data was not changed.';

  @override
  String get privacy => 'Privacy';

  @override
  String get localPrivacyFallback =>
      'Public URL not configured; showing the built-in privacy notice';

  @override
  String get privacyBody =>
      'Projects, boxes, notes and photos stay on this device by default. Core features do not require accounts, ad SDKs or third-party AI. QR codes contain only a format version, project ID, box ID and readable code—not addresses, photos or item lists. Camera, photos, microphone and speech permissions are requested only when you use those features.';

  @override
  String get about => 'About KIFXPRO';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get supportEmailSubject => 'KIFXPRO app support';

  @override
  String get supportNotConfigured =>
      'A support email has not been configured. Provide SUPPORT_EMAIL for release builds.';

  @override
  String versionBuild(Object version, Object build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutBody =>
      'Quickly register boxes, find items offline and track moving status. Every feature is free, with no subscription, trial countdown or paywall.';

  @override
  String get platformSupport => 'System requirements';

  @override
  String get platformSupportBody => 'iOS 15 or later; Android 14 or later.';

  @override
  String get noArchived => 'No archived projects';

  @override
  String get voiceTitle => 'Voice entry';

  @override
  String get voiceHint =>
      'Say the items, destination room and handling notes. You can edit the transcript before saving.';

  @override
  String get startListening => 'Start listening';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get speechUnavailable => 'Speech recognition unavailable';

  @override
  String get speechUnavailableHint =>
      'Your device, language or permission may not support recognition. Switch to manual text entry without affecting other features.';

  @override
  String get switchManual => 'Use manual entry';

  @override
  String get transcript => 'Transcript';

  @override
  String get createFromVoice => 'Create box record';

  @override
  String get voiceEmpty => 'Record or enter a note first';

  @override
  String get permissionDenied =>
      'Permission was not granted. You can use an entry method that does not need it.';

  @override
  String get photoFailed =>
      'Photo processing failed; no record was created for it.';

  @override
  String get dataError => 'Could not load local data';

  @override
  String get editProject => 'Edit project';

  @override
  String get projectDashboard => 'Project overview';

  @override
  String get waitingToLoad => 'Waiting to load';

  @override
  String get notArrived => 'Not arrived';

  @override
  String get notUnpacked => 'Not unpacked';

  @override
  String get stageFilterHint =>
      'Tap stages to filter. Multiple stages can be selected.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get boxes => 'Boxes';

  @override
  String get viewPending => 'View pending';

  @override
  String get noPending => 'Every box has a confirmed physical mark';

  @override
  String get markConfirmed => 'Confirm physical mark';

  @override
  String get labelExported => 'Label exported';

  @override
  String get close => 'Close';

  @override
  String get shareCsv => 'Share CSV';

  @override
  String get shareBackup => 'Share backup';

  @override
  String get createdAt => 'Created';

  @override
  String get searchAllHint => 'Search boxes across all projects';

  @override
  String get projectArchived => 'Project archived';

  @override
  String get projectRestored => 'Project restored';

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String get boxDeleted => 'Box record deleted';

  @override
  String get selectMarkMethod => 'Choose the completed physical marking method';

  @override
  String get statusUpdated => 'Status updated';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Photo picker';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get exportFailed => 'Export failed. Try again later.';

  @override
  String get share => 'Share';

  @override
  String get print => 'Print';

  @override
  String get allLabels => 'All labels';

  @override
  String get unknownProject => 'Unknown project';
}
