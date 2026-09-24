import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/lesson_catalog.dart';
import '../data/lesson_catalog_repository.dart';
import '../data/progress_repository.dart';
import '../domain/models.dart';

enum AppErrorKind { load, save, clear }

class AppController extends ChangeNotifier {
  AppController(
    this._repository, {
    LessonCatalogRepository? lessonCatalogRepository,
  }) : _lessonCatalogRepository = lessonCatalogRepository;

  final ProgressRepository _repository;
  final LessonCatalogRepository? _lessonCatalogRepository;
  List<Attempt> _attempts = <Attempt>[];
  List<Lesson> _lessons = List<Lesson>.unmodifiable(lessons);
  Locale _locale = const Locale('zh');
  String? _errorMessage;
  AppErrorKind? _errorKind;
  String? _catalogErrorMessage;
  String? _catalogRevision;
  DateTime? _catalogGeneratedAt;
  bool _isRefreshingCatalog = false;
  bool _hasCompletedOnboarding = false;

  List<Attempt> get attempts => List<Attempt>.unmodifiable(_attempts);
  List<Lesson> get activeLessons => _lessons;
  Locale get locale => _locale;
  String? get errorMessage => _errorMessage;
  AppErrorKind? get errorKind => _errorKind;
  String? get catalogErrorMessage => _catalogErrorMessage;
  String? get catalogRevision => _catalogRevision;
  DateTime? get catalogGeneratedAt => _catalogGeneratedAt;
  bool get isRefreshingCatalog => _isRefreshingCatalog;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  int get remoteLessonCount =>
      _lessons.where((lesson) => lesson.isRemote).length;
  bool get hasRecoverableLoadError =>
      _errorKind == AppErrorKind.load || _errorKind == AppErrorKind.clear;

  Future<void> initialize({Locale? systemLocale}) async {
    await _loadCachedCatalog();
    try {
      final storedLanguage = await _repository.loadLanguageCode();
      _locale = Locale(
        storedLanguage == 'zh'
            ? 'zh'
            : storedLanguage == 'en'
            ? 'en'
            : systemLocale?.languageCode == 'zh'
            ? 'zh'
            : 'en',
      );
      _hasCompletedOnboarding = await _repository.loadOnboardingCompleted();
      _attempts = await _repository.loadAttempts();
      _errorMessage = null;
      _errorKind = null;
    } catch (error) {
      _attempts = <Attempt>[];
      _errorMessage = error.toString();
      _errorKind = AppErrorKind.load;
    }
    notifyListeners();
  }

  Future<bool> refreshLessons({bool force = false}) async {
    final repository = _lessonCatalogRepository;
    if (repository == null || _isRefreshingCatalog) return false;
    _isRefreshingCatalog = true;
    _catalogErrorMessage = null;
    notifyListeners();
    try {
      final snapshot = await repository.refresh(force: force);
      if (snapshot == null) return false;
      _activateCatalog(snapshot);
      return true;
    } catch (error) {
      _catalogErrorMessage = error.toString();
      return false;
    } finally {
      _isRefreshingCatalog = false;
      notifyListeners();
    }
  }

  Future<bool> completeLesson(Lesson lesson, Verdict verdict) async {
    final attempt = Attempt(
      lessonId: lesson.id,
      verdict: verdict,
      isCorrect: verdict == lesson.correctVerdict,
      completedAt: DateTime.now(),
      misconception: lesson.id,
      lessonRevision: lesson.revision,
      misconceptionText: lesson.misconception,
    );
    final next = <Attempt>[..._attempts, attempt];
    try {
      await _repository.saveAttempts(next);
      _attempts = next;
      _errorMessage = null;
      _errorKind = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      _errorKind = AppErrorKind.save;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setLocale(Locale locale) async {
    try {
      await _repository.saveLanguageCode(locale.languageCode);
      _locale = Locale(locale.languageCode == 'en' ? 'en' : 'zh');
      _errorMessage = null;
      _errorKind = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      _errorKind = AppErrorKind.save;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeOnboarding() async {
    try {
      await _repository.saveOnboardingCompleted(true);
      _hasCompletedOnboarding = true;
      _errorMessage = null;
      _errorKind = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      _errorKind = AppErrorKind.save;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearProgress() async {
    try {
      await _repository.clearAttempts();
      _attempts = <Attempt>[];
      _errorMessage = null;
      _errorKind = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      _errorKind = AppErrorKind.clear;
      notifyListeners();
      return false;
    }
  }

  Map<String, Attempt> get latestAttemptByLesson {
    final latest = <String, Attempt>{};
    for (final attempt in _attempts) {
      latest[attempt.lessonId] = attempt;
    }
    return latest;
  }

  Set<String> get completedLessonIds =>
      _attempts.map((attempt) => attempt.lessonId).toSet();

  Set<String> get reviewLessonIds => latestAttemptByLesson.entries
      .where((entry) => !entry.value.isCorrect)
      .map((entry) => entry.key)
      .toSet();

  double get accuracy => _attempts.isEmpty
      ? 0
      : _attempts.where((attempt) => attempt.isCorrect).length /
            _attempts.length;

  Future<void> _loadCachedCatalog() async {
    final repository = _lessonCatalogRepository;
    if (repository == null) return;
    try {
      final snapshot = await repository.loadCached();
      if (snapshot != null) _activateCatalog(snapshot);
    } catch (error) {
      _catalogErrorMessage = error.toString();
    }
  }

  void _activateCatalog(LessonCatalogSnapshot snapshot) {
    final remoteLessons = snapshot.lessons.length <= maximumRemoteLessonCount
        ? snapshot.lessons
        : snapshot.lessons.sublist(
            snapshot.lessons.length - maximumRemoteLessonCount,
          );
    _lessons = List<Lesson>.unmodifiable(<Lesson>[
      ...lessons,
      ...remoteLessons,
    ]);
    _catalogRevision = snapshot.revision;
    _catalogGeneratedAt = snapshot.generatedAt;
    _catalogErrorMessage = null;
  }
}
