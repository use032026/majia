import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'domain.dart';

abstract class TripStore {
  Future<AppData> load();
  Future<void> save(AppData data);
}

class FileTripStore implements TripStore {
  FileTripStore({Directory? directory}) : _directory = directory;
  final Directory? _directory;

  Future<File> _file() async {
    final directory = _directory ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}/trip_delta_v1.json');
  }

  @override
  Future<AppData> load() async {
    final file = await _file();
    if (!await file.exists()) return const AppData(onboardingComplete: false);
    return AppData.fromJson(jsonDecode(await file.readAsString()));
  }

  @override
  Future<void> save(AppData data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(jsonEncode(data.toJson()), flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

class AppController extends ChangeNotifier {
  AppController(this.store);
  final TripStore store;

  AppData data = const AppData();
  bool loading = true;
  bool busy = false;
  Object? loadError;

  List<Trip> get trips => data.trips;
  Trip? tripById(String id) {
    for (final trip in data.trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      data = await store.load();
    } catch (error) {
      loadError = error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> update(AppData Function(AppData current) change) async {
    if (loading || loadError != null || busy) {
      throw StateError('Store not ready');
    }
    busy = true;
    notifyListeners();
    try {
      final next = change(data);
      await store.save(next);
      data = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> upsertTrip(Trip trip) => update((current) {
    final items = [...current.trips];
    final index = items.indexWhere((item) => item.id == trip.id);
    if (index < 0) {
      items.insert(0, trip);
    } else {
      items[index] = trip;
    }
    return current.copyWith(trips: items);
  });

  Future<void> deleteTrip(String id) => update(
    (current) => current.copyWith(
      trips: current.trips.where((trip) => trip.id != id).toList(),
    ),
  );

  Future<void> setLanguage(String language) =>
      update((current) => current.copyWith(language: language));

  Future<void> completeOnboarding() =>
      update((current) => current.copyWith(onboardingComplete: true));

  Future<BackupImportResult> importBackup(
    AppData backup, {
    required bool replace,
  }) async {
    if (replace) {
      if (loading || busy) throw StateError('Store not ready');
      busy = true;
      notifyListeners();
      try {
        await store.save(backup);
        data = backup;
        loadError = null;
        return BackupImportResult(added: backup.trips.length, skipped: 0);
      } finally {
        busy = false;
        notifyListeners();
      }
    }
    var added = 0;
    var skipped = 0;
    await update((current) {
      final existingIds = current.trips.map((trip) => trip.id).toSet();
      final incoming = <Trip>[];
      for (final trip in backup.trips) {
        if (existingIds.contains(trip.id)) {
          skipped++;
        } else {
          incoming.add(trip);
          added++;
        }
      }
      return current.copyWith(trips: [...incoming, ...current.trips]);
    });
    return BackupImportResult(added: added, skipped: skipped);
  }
}

class BackupImportResult {
  const BackupImportResult({required this.added, required this.skipped});
  final int added;
  final int skipped;
}

String newId() {
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '${DateTime.now().microsecondsSinceEpoch}-$random';
}
