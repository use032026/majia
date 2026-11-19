// Test-only producer shared by the probe and complete runtime result.
// The runner selects an explicit private App directory and a fresh nonce.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class FullRuntimeReportWriter {
  FullRuntimeReportWriter(String privateDirectory, this.runNonce)
    : directory = Directory(privateDirectory) {
    if (runNonce.length != 32 ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(runNonce)) {
      throw ArgumentError('A unique 32-hex test-run nonce is required.');
    }
    if (privateDirectory.isEmpty || !privateDirectory.startsWith('/')) {
      throw ArgumentError(
        'An explicit absolute private directory is required.',
      );
    }
  }

  final Directory directory;
  final String runNonce;
  bool _prepared = false;
  bool _probeWritten = false;
  bool _acknowledged = false;
  bool _resultWritten = false;

  String get probeName => 'stmini_full_runtime_probe_$runNonce.json';
  String get acknowledgementName => 'stmini_full_runtime_ack_$runNonce.txt';
  String get resultName => 'stmini_full_runtime_result_$runNonce.json';

  File _file(String name) => File('${directory.path}/$name');

  Future<void> prepare() async {
    if (_prepared) throw StateError('This writer was already prepared.');
    await directory.create(recursive: true);
    for (final name in [
      probeName,
      '$probeName.writing',
      acknowledgementName,
      resultName,
      '$resultName.writing',
    ]) {
      if (await FileSystemEntity.type(_file(name).path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('The nonce already owns a protocol artifact.');
      }
    }
    _prepared = true;
  }

  Future<String> writeProbe() async {
    if (!_prepared || _probeWritten) {
      throw StateError('The probe must be written once after prepare.');
    }
    await _write(probeName, {
      'runNonce': runNonce,
      'probe': true,
      'passed': true,
    });
    _probeWritten = true;
    return probeName;
  }

  Future<void> waitForReaderAcknowledgement({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!_probeWritten || _acknowledged) {
      throw StateError('A new probe must precede reader acknowledgement.');
    }
    final watch = Stopwatch()..start();
    final ack = _file(acknowledgementName);
    while (watch.elapsed < timeout) {
      final type = await FileSystemEntity.type(ack.path, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        if (type != FileSystemEntityType.file) {
          throw StateError('Reader acknowledgement must be a regular file.');
        }
        final content = await ack.readAsString();
        if (content == runNonce && watch.elapsed < timeout) {
          _acknowledged = true;
          return;
        }
        // A runner may still be writing its single short file. Never accept
        // a prefix or newline; only the exact complete nonce releases _verify.
        if (!runNonce.startsWith(content)) {
          throw StateError('Reader acknowledgement nonce mismatch.');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw TimeoutException('Reader acknowledgement was not received.');
  }

  Future<String> writeResult(Map<String, Object?> result) async {
    if (!_acknowledged || _resultWritten) {
      throw StateError(
        'The result needs a reader ack and may be written once.',
      );
    }
    if (result.containsKey('runNonce') && result['runNonce'] != runNonce) {
      throw StateError('The complete result nonce does not match this run.');
    }
    await _write(resultName, {...result, 'runNonce': runNonce});
    _resultWritten = true;
    return resultName;
  }

  Future<void> _write(String name, Map<String, Object?> value) async {
    final file = _file(name);
    final staging = _file('$name.writing');
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('An existing protocol result must not be replaced.');
    }
    // Exclusive creation also rejects a leftover partial or a second writer.
    // Failed writes intentionally retain the partial as diagnostic evidence.
    await staging.create(exclusive: true);
    await staging.writeAsString(jsonEncode(value), flush: true);
    await staging.rename(file.path);
  }
}
