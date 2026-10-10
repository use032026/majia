import 'package:almanac/src/data/local_store.dart';

class MemoryStateStore implements StateStore {
  MemoryStateStore({this.value, this.failRead = false, this.failWrite = false});

  String? value;
  bool failRead;
  bool failWrite;
  bool failClear = false;
  int writeCount = 0;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<bool> write(String next) async {
    writeCount += 1;
    if (failWrite) return false;
    value = next;
    return true;
  }

  @override
  Future<bool> clear() async {
    if (failClear) return false;
    value = null;
    return true;
  }
}
