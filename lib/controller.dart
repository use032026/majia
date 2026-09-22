import 'package:flutter/foundation.dart';

import 'domain.dart';
import 'repository.dart';

class DomainValidationException implements Exception {
  const DomainValidationException(this.code);
  final String code;

  @override
  String toString() => code;
}

class AppController extends ChangeNotifier {
  AppController(
    this.repository, {
    DateTime Function()? now,
    String Function()? idFactory,
  }) : _now = now ?? DateTime.now,
       _idFactory =
           idFactory ??
           (() => DateTime.now().microsecondsSinceEpoch.toRadixString(36));

  final ExperimentRepository repository;
  final DateTime Function() _now;
  final String Function() _idFactory;

  AppSnapshot snapshot = const AppSnapshot();
  bool isReady = false;
  bool isBusy = false;
  Object? loadError;
  Object? actionError;

  DateTime get today => _now();

  Future<void> load() async {
    loadError = null;
    notifyListeners();
    try {
      snapshot = await repository.load();
      isReady = true;
    } catch (error) {
      loadError = error;
      isReady = false;
    }
    notifyListeners();
  }

  void clearActionError() {
    actionError = null;
    notifyListeners();
  }

  Future<bool> createExperiment({
    required String title,
    required String cue,
    required String fullAction,
    required String minimumAction,
    required int targetDays,
  }) async {
    if (snapshot.active != null) {
      throw const DomainValidationException('active_exists');
    }
    _validateExperiment(
      title: title,
      cue: cue,
      fullAction: fullAction,
      minimumAction: minimumAction,
      targetDays: targetDays,
    );
    final experiment = Experiment(
      id: _idFactory(),
      title: title.trim(),
      cue: cue.trim(),
      fullAction: fullAction.trim(),
      minimumAction: minimumAction.trim(),
      targetDays: targetDays,
      startedAt: _now(),
    );
    return _commit(
      snapshot.copyWith(
        experiments: List.unmodifiable([...snapshot.experiments, experiment]),
      ),
    );
  }

  Future<bool> updateExperiment({
    required String id,
    required String title,
    required String cue,
    required String fullAction,
    required String minimumAction,
    required int targetDays,
  }) async {
    _validateExperiment(
      title: title,
      cue: cue,
      fullAction: fullAction,
      minimumAction: minimumAction,
      targetDays: targetDays,
    );
    final current = _find(id);
    final updated = current.copyWith(
      title: title.trim(),
      cue: cue.trim(),
      fullAction: fullAction.trim(),
      minimumAction: minimumAction.trim(),
      targetDays: targetDays,
    );
    return _replace(updated);
  }

  Future<bool> saveEntry({
    required String experimentId,
    required EntryKind kind,
    Obstacle obstacle = Obstacle.none,
    RecoveryPlan recoveryPlan = RecoveryPlan.none,
    String note = '',
  }) async {
    final experiment = _find(experimentId);
    if (experiment.isArchived) {
      throw const DomainValidationException('archived');
    }
    final needsRecovery = experiment.needsRecoveryBefore(_now());
    if (kind == EntryKind.skipped && obstacle == Obstacle.none) {
      throw const DomainValidationException('obstacle_required');
    }
    if ((kind == EntryKind.skipped || needsRecovery) &&
        recoveryPlan == RecoveryPlan.none) {
      throw const DomainValidationException('recovery_required');
    }
    final entry = DailyEntry(
      date: localDateKey(_now()),
      kind: kind,
      obstacle: kind == EntryKind.skipped ? obstacle : Obstacle.none,
      recoveryPlan: kind == EntryKind.skipped || needsRecovery
          ? recoveryPlan
          : RecoveryPlan.none,
      note: note.trim(),
    );
    final entries =
        experiment.entries.where((item) => item.date != entry.date).toList()
          ..add(entry)
          ..sort((a, b) => a.date.compareTo(b.date));
    return _replace(
      _withoutUnreachedReviews(
        experiment.copyWith(entries: List.unmodifiable(entries)),
      ),
    );
  }

  Future<bool> undoToday(String experimentId) async {
    final experiment = _find(experimentId);
    final key = localDateKey(_now());
    final entries = experiment.entries
        .where((item) => item.date != key)
        .toList();
    return _replace(
      _withoutUnreachedReviews(
        experiment.copyWith(entries: List.unmodifiable(entries)),
      ),
    );
  }

  Future<bool> saveMilestoneReview({
    required String experimentId,
    required int milestone,
    required ReviewDecision decision,
    String note = '',
  }) async {
    if (!const [7, 14, 21].contains(milestone)) {
      throw const DomainValidationException('invalid_milestone');
    }
    final experiment = _find(experimentId);
    if (ExperimentStats(experiment, _now()).practiceDays < milestone) {
      throw const DomainValidationException('milestone_not_reached');
    }
    final review = MilestoneReview(
      milestone: milestone,
      decision: decision,
      recordedAt: _now(),
      note: note.trim(),
    );
    final reviews =
        experiment.reviews.where((item) => item.milestone != milestone).toList()
          ..add(review)
          ..sort((a, b) => a.milestone.compareTo(b.milestone));
    return _replace(experiment.copyWith(reviews: List.unmodifiable(reviews)));
  }

  Future<bool> archive(String experimentId) async {
    final experiment = _find(experimentId);
    return _replace(experiment.copyWith(archivedAt: _now()));
  }

  Future<bool> restore(String experimentId) async {
    if (snapshot.active != null) {
      throw const DomainValidationException('active_exists');
    }
    final experiment = _find(experimentId);
    return _replace(experiment.copyWith(clearArchivedAt: true));
  }

  Future<bool> deleteExperiment(String experimentId) async {
    final experiments = snapshot.experiments
        .where((item) => item.id != experimentId)
        .toList();
    return _commit(
      snapshot.copyWith(experiments: List.unmodifiable(experiments)),
    );
  }

  Future<bool> deleteAll() => _commit(
    AppSnapshot(localeCode: snapshot.localeCode, experiments: const []),
  );

  Future<bool> setLocale(String localeCode) async {
    if (localeCode != 'zh' && localeCode != 'en') {
      throw const DomainValidationException('invalid_locale');
    }
    return _commit(snapshot.copyWith(localeCode: localeCode));
  }

  void _validateExperiment({
    required String title,
    required String cue,
    required String fullAction,
    required String minimumAction,
    required int targetDays,
  }) {
    if ([
      title,
      cue,
      fullAction,
      minimumAction,
    ].any((value) => value.trim().isEmpty)) {
      throw const DomainValidationException('required');
    }
    if (targetDays < 1 || targetDays > 365) {
      throw const DomainValidationException('target_range');
    }
  }

  Experiment _find(String id) => snapshot.experiments.firstWhere(
    (item) => item.id == id,
    orElse: () => throw const DomainValidationException('not_found'),
  );

  Future<bool> _replace(Experiment updated) {
    final experiments = snapshot.experiments
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    return _commit(
      snapshot.copyWith(experiments: List.unmodifiable(experiments)),
    );
  }

  Experiment _withoutUnreachedReviews(Experiment experiment) {
    final practiceDays = experiment.entries
        .where((entry) => entry.isPractice)
        .length;
    final validReviews = experiment.reviews
        .where((review) => review.milestone <= practiceDays)
        .toList();
    if (validReviews.length == experiment.reviews.length) return experiment;
    return experiment.copyWith(reviews: List.unmodifiable(validReviews));
  }

  Future<bool> _commit(AppSnapshot candidate) async {
    if (isBusy) return false;
    isBusy = true;
    actionError = null;
    notifyListeners();
    try {
      await repository.save(candidate);
      snapshot = candidate;
      isBusy = false;
      notifyListeners();
      return true;
    } catch (error) {
      actionError = error;
      isBusy = false;
      notifyListeners();
      return false;
    }
  }
}
