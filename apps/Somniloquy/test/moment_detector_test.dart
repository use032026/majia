import 'package:flutter_test/flutter_test.dart';
import 'package:somniloquy/domain/models.dart';

void main() {
  test('calibrates before creating bounded, cooled-down candidates', () {
    final detector = MomentDetector(
      calibrationSampleCount: 3,
      cooldownSeconds: 10,
      maxMoments: 2,
    );

    expect(detector.addSample(-60, Duration.zero), isNull);
    expect(detector.addSample(-58, const Duration(seconds: 2)), isNull);
    expect(detector.addSample(-62, const Duration(seconds: 4)), isNull);
    expect(detector.isCalibrated, isTrue);
    expect(detector.thresholdDb, -38);

    final first = detector.addSample(-20, const Duration(seconds: 6));
    expect(first, isNotNull);
    expect(first!.label, MomentLabel.pending);
    expect(detector.addSample(-10, const Duration(seconds: 12)), isNull);

    final second = detector.addSample(-18, const Duration(seconds: 17));
    expect(second, isNotNull);
    expect(detector.addSample(-5, const Duration(seconds: 40)), isNull);
    expect(detector.moments, hasLength(2));
  });

  test('ignores invalid and quiet samples', () {
    final detector = MomentDetector(calibrationSampleCount: 1);
    detector.addSample(-50, Duration.zero);
    expect(detector.addSample(double.nan, const Duration(seconds: 2)), isNull);
    expect(detector.addSample(-90, const Duration(seconds: 20)), isNull);
    expect(detector.moments, isEmpty);
  });
}
