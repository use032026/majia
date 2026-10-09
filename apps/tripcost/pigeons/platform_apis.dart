import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/generated/platform_apis.g.dart',
    dartOptions: DartOptions(),
    dartPackageName: 'trip_cost',
    swiftOut: 'ios/Runner/Generated/PlatformApis.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/tripcost/lite/PlatformApis.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.tripcost.lite'),
  ),
)
enum OcrRecognitionMode { fast, accurate }

enum CloudAccountState { available, noAccount, restricted, couldNotDetermine }

class OcrRequest {
  OcrRequest({
    required this.contractVersion,
    required this.imagePath,
    required this.mode,
    required this.preferredLanguages,
  });

  int contractVersion;
  String imagePath;
  OcrRecognitionMode mode;
  List<String> preferredLanguages;
}

class OcrCandidate {
  OcrCandidate({
    required this.confidence,
    required this.height,
    required this.text,
    required this.width,
    required this.x,
    required this.y,
  });

  String text;
  double confidence;
  double x;
  double y;
  double width;
  double height;
}

class OcrResult {
  OcrResult({required this.candidates, required this.contractVersion});

  int contractVersion;
  List<OcrCandidate> candidates;
}

class SyncRecord {
  SyncRecord({
    required this.contractVersion,
    required this.deleted,
    required this.id,
    required this.modifiedAtUtc,
    required this.payloadJson,
    required this.recordType,
    required this.schemaVersion,
    required this.deviceId,
    required this.changeId,
  });

  int contractVersion;
  String id;
  String recordType;
  int schemaVersion;
  String deviceId;
  String changeId;
  String payloadJson;
  String modifiedAtUtc;
  bool deleted;
}

class SyncPushResult {
  SyncPushResult({
    required this.acceptedRecordIds,
    required this.contractVersion,
    required this.cursor,
  });

  int contractVersion;
  List<String> acceptedRecordIds;
  String? cursor;
}

class SyncPullResult {
  SyncPullResult({
    required this.contractVersion,
    required this.cursor,
    required this.hasMore,
    required this.records,
  });

  int contractVersion;
  List<SyncRecord> records;
  String? cursor;
  bool hasMore;
}

class SharedSnapshot {
  SharedSnapshot({required this.contractVersion, required this.payloadJson});

  int contractVersion;
  String payloadJson;
}

@HostApi()
abstract class VisionOcrApi {
  @async
  OcrResult recognizeImage(OcrRequest request);

  List<String> supportedRecognitionLanguages();
}

@HostApi()
abstract class CloudSyncApi {
  @async
  CloudAccountState accountStatus();

  @async
  SyncPushResult pushChanges(List<SyncRecord> records, String? cursor);

  @async
  SyncPullResult pullChanges(String? cursor);
}

@HostApi()
abstract class SharedSnapshotApi {
  @async
  void writeWidgetSnapshot(SharedSnapshot snapshot);

  @async
  void clearWidgetSnapshot();
}

@HostApi()
abstract class WidgetControlApi {
  void reloadTimelines();
}
