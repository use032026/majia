import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import 'strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  int _pageIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.localeCode);
    final colors = Theme.of(context).colorScheme;
    final pages = [
      _OnboardingPageData(
        icon: Icons.graphic_eq_rounded,
        accent: colors.primary,
        surface: colors.primaryContainer,
        onSurface: colors.onPrimaryContainer,
        title: strings.t('onboardingListenTitle'),
        body: strings.t('onboardingListenBody'),
        note: strings.t('onboardingListenNote'),
      ),
      _OnboardingPageData(
        icon: Icons.headphones_rounded,
        accent: colors.secondary,
        surface: colors.secondaryContainer,
        onSurface: colors.onSecondaryContainer,
        title: strings.t('onboardingReviewTitle'),
        body: strings.t('onboardingReviewBody'),
        note: strings.t('onboardingReviewNote'),
      ),
      _OnboardingPageData(
        icon: Icons.lock_outline_rounded,
        accent: colors.primary,
        surface: colors.tertiaryContainer,
        onSurface: colors.onTertiaryContainer,
        title: strings.t('onboardingPrivacyTitle'),
        body: strings.t('onboardingPrivacyBody'),
        note: strings.t('onboardingPrivacyNote'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const _OnboardingMark(),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      strings.t('appName'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_pageIndex < _pageCount - 1)
                    TextButton(
                      key: const Key('onboarding_skip'),
                      onPressed: _saving ? null : _finish,
                      child: Text(strings.t('onboardingSkip')),
                    ),
                ],
              ),
              Expanded(
                child: Semantics(
                  label: strings.onboardingProgress(_pageIndex + 1, _pageCount),
                  child: PageView.builder(
                    key: const Key('onboarding_pages'),
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: pages[index], pageIndex: index),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _pageCount; index++)
                    AnimatedContainer(
                      key: Key('onboarding_dot_$index'),
                      duration: const Duration(milliseconds: 180),
                      width: index == _pageIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _pageIndex
                            ? colors.primary
                            : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key(
                    _pageIndex == _pageCount - 1
                        ? 'onboarding_start'
                        : 'onboarding_next',
                  ),
                  onPressed: _saving ? null : _handlePrimaryAction,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _pageIndex == _pageCount - 1
                              ? Icons.nightlight_round
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    strings.t(
                      _pageIndex == _pageCount - 1
                          ? 'onboardingStart'
                          : 'onboardingNext',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_pageIndex < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final saved = await widget.controller.completeOnboarding();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      final strings = AppStrings(widget.controller.localeCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('onboardingSaveFailed'))),
      );
    }
  }
}

class _OnboardingMark extends StatelessWidget {
  const _OnboardingMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.mode_night_rounded, color: colors.onPrimary, size: 24),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.onSurface,
    required this.title,
    required this.body,
    required this.note,
  });

  final IconData icon;
  final Color accent;
  final Color surface;
  final Color onSurface;
  final String title;
  final String body;
  final String note;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = math.max(0.0, constraints.maxHeight - 32);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OnboardingVisual(data: data, pageIndex: pageIndex),
                const SizedBox(height: 30),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    children: [
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontSize: 32, height: 1.14),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        data.body,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: data.surface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          data.note,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: data.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('onboarding_visual_$pageIndex'),
      width: 238,
      height: 224,
      decoration: BoxDecoration(
        color: data.surface,
        borderRadius: BorderRadius.circular(42),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 24,
            left: 26,
            child: _Dot(color: data.accent, size: 12),
          ),
          Positioned(
            top: 38,
            right: 34,
            child: _Dot(color: colors.surface, size: 8),
          ),
          Positioned(
            bottom: 34,
            right: 28,
            child: _Dot(color: data.accent, size: 9),
          ),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.88),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 66, color: data.accent),
          ),
          Positioned(
            left: 49,
            right: 49,
            bottom: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final height in const [8.0, 16.0, 10.0, 22.0, 13.0])
                  Container(
                    width: 7,
                    height: height,
                    decoration: BoxDecoration(
                      color: data.accent.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(99),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
