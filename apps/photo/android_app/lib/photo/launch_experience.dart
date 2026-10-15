import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

abstract final class _LaunchColors {
  static const canvas = Color(0xFFF8F5FC);
  static const ink = Color(0xFF2B2232);
  static const purple = Color(0xFF725286);
  static const muted = Color(0xFF66576F);
  static const lilac = Color(0xFFE9E0F7);
}

/// Keeps the native launch screen, the first Flutter frame, and onboarding in
/// one visual flow. Completion is stored only after an explicit user action.
class LaunchExperience extends StatefulWidget {
  const LaunchExperience({
    super.key,
    required this.preferences,
    required this.editorBuilder,
    this.splashDuration = const Duration(milliseconds: 900),
  });

  static const onboardingCompletedKey = 'onboarding_completed_v1';

  final SharedPreferences preferences;
  final WidgetBuilder editorBuilder;
  final Duration splashDuration;

  @override
  State<LaunchExperience> createState() => _LaunchExperienceState();
}

class _LaunchExperienceState extends State<LaunchExperience> {
  Timer? _splashTimer;
  bool _showSplash = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _completed =
        widget.preferences.getBool(LaunchExperience.onboardingCompletedKey) ??
        false;
    _splashTimer = Timer(widget.splashDuration, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    child: _showSplash
        ? const _BrandSplash(key: ValueKey('splash'))
        : _completed
        ? KeyedSubtree(
            key: const ValueKey('editor'),
            child: widget.editorBuilder(context),
          )
        : _Onboarding(
            key: const ValueKey('onboarding'),
            preferences: widget.preferences,
            onComplete: () => setState(() => _completed = true),
          ),
  );
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _LaunchColors.canvas,
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandMark(size: 112),
                const SizedBox(height: 26),
                const Text(
                  'Jufu',
                  style: TextStyle(
                    fontSize: 36,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w800,
                    color: _LaunchColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.isChinese
                      ? '为每一张照片留下精致余韵'
                      : 'A refined finish for every photo',
                  style: const TextStyle(
                    fontSize: 14,
                    color: _LaunchColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Text(
              'MADE FOR YOUR MOMENTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _LaunchColors.purple,
                letterSpacing: 2.4,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _LaunchColors.lilac,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(
          color: Color(0x18725286),
          blurRadius: 30,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Icon(
      Icons.auto_awesome_rounded,
      size: size * .49,
      color: _LaunchColors.purple,
    ),
  );
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({
    super.key,
    required this.preferences,
    required this.onComplete,
  });

  final SharedPreferences preferences;
  final VoidCallback onComplete;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _pages = PageController();
  int _index = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.preferences.setBool(
        LaunchExperience.onboardingCompletedKey,
        true,
      );
      if (!saved) throw StateError('Could not save onboarding completion');
      if (mounted) widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              '暂时无法保存设置，请重试。',
              'Couldn’t save your choice. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _next() {
    if (_index == 2) {
      _finish();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _LaunchColors.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 24,
                  color: _LaunchColors.purple,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Jufu',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _LaunchColors.ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(
                    _copy(context, '跳过', 'Skip'),
                    style: const TextStyle(
                      color: _LaunchColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: 3,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _OnboardingPage(index: index),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 3; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == index ? 28 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? _LaunchColors.purple
                          : const Color(0xFFD7CBE5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 23),
            FilledButton(
              onPressed: _busy ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: _LaunchColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(
                _index == 2
                    ? _copy(context, '开始编辑', 'Start editing')
                    : _copy(context, '继续', 'Continue'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _copy(
                context,
                '无需账号 · 核心编辑在设备本地完成',
                'No account · Core editing stays on device',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _LaunchColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

String _copy(BuildContext context, String chinese, String english) =>
    context.isChinese ? chinese : english;

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final titles = [
      _copy(context, '从一张照片开始', 'Your story starts with a photo'),
      _copy(context, '调出照片的轻盈光感', 'Find its quiet glow'),
      _copy(context, '留下你的专属印记', 'Make it yours'),
    ];
    final descriptions = [
      _copy(
        context,
        '挑选喜欢的照片，随时开始创作。',
        'Pick a favorite from your library whenever you’re ready.',
      ),
      _copy(
        context,
        '调整构图与比例，再试试柔和的效果和强度。',
        'Refine the crop, then explore soft effects and their strength.',
      ),
      _copy(
        context,
        '写一句文字水印，长按对比原图，满意后保存到相册。',
        'Add a text watermark, hold to compare, and save when it feels right.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              _PhotoIllustration(
                index: index,
                height: (constraints.maxHeight * .54).clamp(210.0, 365.0),
              ),
              const SizedBox(height: 30),
              Text(
                '${(index + 1).toString().padLeft(2, '0')}  /  03',
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w800,
                  color: _LaunchColors.purple,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                titles[index],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _LaunchColors.ink,
                  fontSize: 26,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                descriptions[index],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _LaunchColors.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoIllustration extends StatelessWidget {
  const _PhotoIllustration({required this.index, required this.height});

  final int index;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE4F8), Color(0xFFDDD0EB)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -58,
            right: -42,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x55FFFFFF),
              ),
            ),
          ),
          Positioned(
            bottom: -72,
            left: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x33FFFFFF),
              ),
            ),
          ),
          Transform.rotate(
            angle: index == 0 ? -.055 : .04,
            child: Container(
              width: height * .63,
              height: height * .79,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33725286),
                    blurRadius: 26,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFBBA5D9),
                            Color(0xFFE7BED1),
                            Color(0xFFFFD8BC),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: height * .11,
                      right: height * .1,
                      child: Container(
                        width: height * .13,
                        height: height * .13,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEACD),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x88FFF1D0), blurRadius: 20),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -height * .14,
                      left: -height * .16,
                      child: _Hill(
                        width: height * .65,
                        height: height * .38,
                        color: const Color(0xFF967EAD),
                      ),
                    ),
                    Positioned(
                      bottom: -height * .19,
                      right: -height * .18,
                      child: _Hill(
                        width: height * .67,
                        height: height * .37,
                        color: const Color(0xFF655379),
                      ),
                    ),
                    if (index == 2)
                      const Align(
                        alignment: Alignment(0, .48),
                        child: Text(
                          'make it yours',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22725286),
                    blurRadius: 13,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    [
                      Icons.add_photo_alternate_outlined,
                      Icons.tune_rounded,
                      Icons.text_fields_rounded,
                    ][index],
                    size: 17,
                    color: _LaunchColors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    [
                      _copy(context, '选一张喜欢的照片', 'Choose a moment'),
                      _copy(context, '浅紫  ·  4:5', 'Lilac  ·  4:5'),
                      _copy(context, '保存你的作品', 'Save your moment'),
                    ][index],
                    style: const TextStyle(
                      color: _LaunchColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Hill extends StatelessWidget {
  const _Hill({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
