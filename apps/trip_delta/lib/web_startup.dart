import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

import 'site_update.dart';
import 'stmini_web_host.dart';
import 'strings.dart';
import 'trip_theme.dart';
import 'web_mode_actions.dart';
import 'web_startup_preference.dart';
import 'onboarding.dart';
import 'web_launch_splash.dart';

abstract interface class WebRootSession {
  Stream<StminiEvent> get events;
  Future<void> open();
  Future<String?> readLaunchLanguage();
  void dispose();
}

/// Sole owner of the Web host. It initializes the runtime on first open.
class StminiWebRootSession implements WebRootSession {
  TripDeltaWebHost? _host;
  @override
  Stream<StminiEvent> get events => StminiFlutter.events;
  @override
  Future<void> open() =>
      (_host ??= TripDeltaWebHost()).openHome(showNavigationBar: false);
  @override
  Future<String?> readLaunchLanguage() =>
      StminiFlutter.getWebLaunchLanguage(TripDeltaWebHost.defaultHomeUrl);
  @override
  void dispose() => _host?.dispose();
}

class TripDeltaStartup extends StatefulWidget {
  const TripDeltaStartup({
    super.key,
    required this.preference,
    required this.session,
    required this.tripBuilder,
    this.checkUpdate = checkInstalledSiteUpdate,
  });
  final WebStartupPreference preference;
  final WebRootSession session;
  final Widget Function(WebModeActions? actions) tripBuilder;
  final Future<SiteUpdate> Function() checkUpdate;

  @override
  State<TripDeltaStartup> createState() => _TripDeltaStartupState();
}

class _TripDeltaStartupState extends State<TripDeltaStartup> {
  bool _loading = true;
  bool _enabled = false;
  bool _saved = false;
  bool _opening = false;
  bool _failed = false;
  bool _terminal = false;
  int _generation = 0;
  Future<void>? _saving;
  StreamSubscription<StminiEvent>? _events;
  Widget? _trip;
  Locale? _locale;
  late final bool _supported;

  @override
  void initState() {
    super.initState();
    _supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (_supported) {
      unawaited(_chooseStartupHome());
    } else {
      _loading = false;
    }
  }

  Future<void> _chooseStartupHome() async {
    var enabled = false;
    try {
      final update = await widget.checkUpdate().timeout(
        const Duration(seconds: 3),
      );
      enabled = update.side == 'B';
    } catch (_) {
      // Keep the trip home available when the site cannot be reached.
    }
    if (!mounted) return;
    final locale = enabled ? await _readWebLocale() : null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _enabled = enabled;
      _locale = locale;
    });
    if (enabled) _scheduleOpen();
  }

  Future<void> _persist() {
    if (_saved) return Future.value();
    return _saving ??= _save();
  }

  Future<void> _save() async {
    try {
      await widget.preference.saveEnabled();
      if (mounted) _saved = true;
    } finally {
      _saving = null;
    }
  }

  Future<Locale> _readWebLocale() async {
    String? language;
    try {
      language = await widget.session.readLaunchLanguage();
    } catch (_) {
      // 没有 H5 手动选择或读取失败时使用当前系统语言。
    }
    language ??= WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return Locale(language.toLowerCase().startsWith('zh') ? 'zh' : 'en');
  }

  Future<void> _activate(Locale _) async {
    if (!mounted || !_supported || !_saved || _enabled) return;
    final locale = await _readWebLocale();
    if (!mounted || _enabled) return;
    setState(() {
      _enabled = true;
      _trip = null;
      _locale = locale;
    });
    _scheduleOpen();
  }

  void _scheduleOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _enabled) unawaited(_open());
    });
  }

  void _rootUnavailable(int generation) {
    if (!mounted || !_enabled || _terminal || generation != _generation) return;
    _generation++;
    setState(() {
      _terminal = true;
      _opening = false;
      _failed = true;
    });
  }

  Future<void> _open() async {
    if (!mounted || !_enabled || _opening) return;
    final generation = ++_generation;
    setState(() {
      _opening = true;
      _failed = false;
      _terminal = false;
    });
    try {
      final previousEvents = _events;
      _events = null;
      await previousEvents?.cancel();
      if (!mounted || generation != _generation) return;
      _events = widget.session.events.listen(
        (event) {
          // The native plugin emits this only for whole-root dismissal; child
          // navigation pops are deliberately left to the existing container.
          if (event.name == 'web_closed') _rootUnavailable(generation);
        },
        onError: (Object _, StackTrace __) => _rootUnavailable(generation),
        onDone: () => _rootUnavailable(generation),
      );
      if (!mounted || generation != _generation || _terminal) return;
      await widget.session.open();
      if (!mounted || generation != _generation || _terminal) return;
      // This acknowledges native presentation, not successful H5 loading.
      setState(() {
        _opening = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _opening = false;
        _failed = true;
        _terminal = true;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_events?.cancel());
    if (_supported) widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_enabled) {
      return _trip ??= widget.tripBuilder(
        _supported ? WebModeActions(save: _persist, activate: _activate) : null,
      );
    }
    return MaterialApp(
      key: const Key('web_startup_root'),
      title: 'Trip Delta',
      debugShowCheckedModeBanner: false,
      theme: tripDeltaTheme(Brightness.light),
      darkTheme: tripDeltaTheme(Brightness.dark),
      locale: _locale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          final l = L(Localizations.localeOf(context).languageCode == 'zh');
          return Scaffold(
            key: const Key('web_only_home'),
            backgroundColor: _loading || _opening || _failed
                ? Theme.of(context).colorScheme.surface
                : const Color(0xFFF8F7F2),
            body: _failed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l('webHomeUnavailable'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('web_home_retry'),
                            onPressed: _opening
                                ? null
                                : () => unawaited(_open()),
                            child: Text(l('retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                : _enabled
                ? WebLaunchSplash(languageCode: _locale?.languageCode ?? 'en')
                : const BrandSplash(),
          );
        },
      ),
    );
  }
}
