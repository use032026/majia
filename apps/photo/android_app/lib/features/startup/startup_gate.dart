import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/startup_service.dart';
import '../../shared/widgets/st_toast.dart';

const _appGuideVersionKey = 'AppGuideVersionKey';

typedef StartupAppBuilder =
    Widget Function(BuildContext context, StartupResult result);

/// Flutter counterpart of iOS `STStartViewController`.
///
/// It owns only the launch shell responsibilities: launch image, guide gate,
/// no-network placeholder, retry, and handing off to the configured root app.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.onStartupReady,
    required this.appBuilder,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final Future<void> Function(StartupResult result) onStartupReady;
  final StartupAppBuilder appBuilder;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool? _needsGuide;
  String _appVersion = '1.0.0';
  bool _placeholderVisible = false;

  @override
  void initState() {
    super.initState();
    _loadGuideStep();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && mounted && _placeholderVisible) {
        ref.invalidate(startupFutureProvider);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadGuideStep() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _appVersion = '1.0.0';
    }
    final storedVersion = prefs.getString(_appGuideVersionKey);
    final needsGuide =
        storedVersion == null || storedVersion.compareTo(_appVersion) < 0;
    if (!mounted) return;
    setState(() => _needsGuide = needsGuide);
  }

  Future<void> _confirmGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appGuideVersionKey, _appVersion);
    if (!mounted) return;
    setState(() => _needsGuide = false);
    ref.invalidate(startupFutureProvider);
  }

  Future<void> _retryStartup() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online) {
      if (!mounted) return;
      STToast.show(context, _StartupCopy.forLocale(widget.locale).nonet);
      return;
    }
    ref.invalidate(startupFutureProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsGuide == null) {
      _placeholderVisible = false;
      return StartupMaterialShell(
        locale: widget.locale,
        themeMode: widget.themeMode,
        child: StartupLaunchView(locale: widget.locale),
      );
    }

    if (_needsGuide!) {
      _placeholderVisible = false;
      return StartupMaterialShell(
        locale: widget.locale,
        themeMode: widget.themeMode,
        child: StartupGuideView(
          locale: widget.locale,
          onConfirm: _confirmGuide,
        ),
      );
    }

    final startupAsync = ref.watch(startupFutureProvider);

    ref.listen(startupFutureProvider, (prev, next) {
      next.whenOrNull(
        data: (result) {
          if (result.configLoaded && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(widget.onStartupReady(result));
            });
          }
        },
      );
    });

    return startupAsync.when(
      data: (result) {
        if (!result.configLoaded) {
          _placeholderVisible = true;
          return StartupMaterialShell(
            locale: widget.locale,
            themeMode: widget.themeMode,
            child: StartupPlaceholderView(
              locale: widget.locale,
              onRefresh: _retryStartup,
            ),
          );
        }
        _placeholderVisible = false;
        return StartupRootHandoff(
          locale: widget.locale,
          child: widget.appBuilder(context, result),
        );
      },
      loading: () {
        _placeholderVisible = false;
        return StartupMaterialShell(
          locale: widget.locale,
          themeMode: widget.themeMode,
          child: StartupLaunchView(locale: widget.locale),
        );
      },
      error: (_, __) {
        _placeholderVisible = true;
        return StartupMaterialShell(
          locale: widget.locale,
          themeMode: widget.themeMode,
          child: StartupPlaceholderView(
            locale: widget.locale,
            onRefresh: _retryStartup,
          ),
        );
      },
    );
  }
}

class StartupRootHandoff extends StatelessWidget {
  const StartupRootHandoff({
    super.key,
    required this.locale,
    required this.child,
  });

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        StartupLaunchView(locale: locale),
        child,
      ],
    );
  }
}

class StartupMaterialShell extends StatelessWidget {
  const StartupMaterialShell({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.child,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B57A)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF18191A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B57A),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(body: child),
    );
  }
}

class StartupLaunchView extends StatelessWidget {
  const StartupLaunchView({super.key, required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _launchImageFor(locale),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }
}

class StartupGuideView extends StatefulWidget {
  const StartupGuideView({
    super.key,
    required this.locale,
    required this.onConfirm,
  });

  final Locale locale;
  final VoidCallback onConfirm;

  @override
  State<StartupGuideView> createState() => _StartupGuideViewState();
}

class _StartupGuideViewState extends State<StartupGuideView> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _StartupCopy.forLocale(widget.locale);
    final images = _guideImagesFor(widget.locale);
    final scale = MediaQuery.sizeOf(context).width / 375.0;
    final buttonHeight = 34.0 * scale;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            itemCount: images.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(images[index], fit: BoxFit.fill),
                  if (index == images.length - 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 50.0 * scale,
                      child: Center(
                        child: GestureDetector(
                          onTap: widget.onConfirm,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: buttonHeight,
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B57A),
                              borderRadius: BorderRadius.circular(
                                buttonHeight / 2,
                              ),
                            ),
                            child: Center(
                              widthFactor: 1,
                              heightFactor: 1,
                              child: Text(
                                copy.experienceImmediately,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 103,
            child: Center(
              child: _StartupPageIndicator(count: images.length, index: _page),
            ),
          ),
        ],
      ),
    );
  }
}

class StartupPlaceholderView extends StatelessWidget {
  const StartupPlaceholderView({
    super.key,
    required this.locale,
    required this.onRefresh,
  });

  final Locale locale;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final copy = _StartupCopy.forLocale(locale);
    final media = MediaQuery.of(context);
    final scale = media.size.width / 375.0;
    final top = media.padding.top + 214.0 * scale;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/st_app_launch_placeholder.png',
                  width: 129,
                  height: 102,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 25),
                Text(
                  copy.noNetwork,
                  style: const TextStyle(
                    color: Color(0xFF343434),
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onRefresh,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 64,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      copy.refresh,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupPageIndicator extends StatelessWidget {
  const _StartupPageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    const dotSize = 5.0;
    const dotSpace = 8.0;
    const activeWidth = 12.0;
    const minWidth = 50.0;
    final trackWidth = count * dotSize + (count - 1) * dotSpace;
    final leadingInset = (minWidth - trackWidth) / 2;

    return SizedBox(
      width: minWidth,
      height: dotSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: leadingInset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(count, (i) {
                return Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.only(right: i == count - 1 ? 0 : dotSpace),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left:
                leadingInset +
                index * (dotSize + dotSpace) +
                (dotSize - activeWidth) / 2,
            child: Container(
              width: activeWidth,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF7EDB41),
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupCopy {
  const _StartupCopy({
    required this.experienceImmediately,
    required this.noNetwork,
    required this.nonet,
    required this.refresh,
  });

  final String experienceImmediately;
  final String noNetwork;
  final String nonet;
  final String refresh;

  static _StartupCopy forLocale(Locale locale) {
    if (_isSimplifiedChinese(locale)) {
      return const _StartupCopy(
        experienceImmediately: '立即体验',
        noNetwork: '暂无网络',
        nonet: '当前网络不可用',
        refresh: '刷新',
      );
    }
    return const _StartupCopy(
      experienceImmediately: 'Start using',
      noNetwork: 'No network',
      nonet: 'Network unavailable',
      refresh: 'Refresh',
    );
  }
}

String _launchImageFor(Locale locale) {
  return _isSimplifiedChinese(locale)
      ? 'assets/images/st_launch_zh.png'
      : 'assets/images/st_launch_en.png';
}

List<String> _guideImagesFor(Locale locale) {
  final prefix = _isSimplifiedChinese(locale)
      ? 'st_guide_zhHans'
      : 'st_guide_en';
  return [
    'assets/images/${prefix}_1.png',
    'assets/images/${prefix}_2.png',
    'assets/images/${prefix}_3.png',
  ];
}

bool _isSimplifiedChinese(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh') {
    return false;
  }

  final scriptCode = locale.scriptCode?.toLowerCase();
  if (scriptCode != null && scriptCode.isNotEmpty) {
    return scriptCode == 'hans';
  }

  final countryCode = locale.countryCode?.toLowerCase();
  if (countryCode == null || countryCode.isEmpty) {
    return true;
  }

  return countryCode == 'cn';
}
