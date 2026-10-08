import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

abstract class RecorderService {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<double?> readAmplitude();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceRecorderService implements RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      audioInterruption: AudioInterruptionMode.pause,
    ),
    path: path,
  );

  @override
  Future<double?> readAmplitude() async {
    final amplitude = await _recorder.getAmplitude();
    return amplitude.current;
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

abstract class ClipPlayerService {
  Future<void> play(String path, Duration position, {Duration? maxDuration});
  Future<void> stop();
  Future<void> dispose();
}

class DeviceClipPlayerService implements ClipPlayerService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _stopTimer;

  @override
  Future<void> play(
    String path,
    Duration position, {
    Duration? maxDuration,
  }) async {
    _stopTimer?.cancel();
    await _player.stop();
    await _player.play(
      DeviceFileSource(path),
      position: position,
      mode: PlayerMode.mediaPlayer,
    );
    if (maxDuration != null) {
      _stopTimer = Timer(maxDuration, _player.stop);
    }
  }

  @override
  Future<void> stop() async {
    _stopTimer?.cancel();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _stopTimer?.cancel();
    await _player.dispose();
  }
}
