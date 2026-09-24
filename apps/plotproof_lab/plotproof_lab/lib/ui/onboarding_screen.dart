import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  var _pageIndex = 0;
  var _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final pages = <_OnboardingPageData>[
      _OnboardingPageData(
        icon: Icons.query_stats_rounded,
        accent: scheme.primary,
        surface: scheme.primaryContainer,
        title: strings.onboardingFirstTitle,
        body: strings.onboardingFirstBody,
      ),
      _OnboardingPageData(
        icon: Icons.tune_rounded,
        accent: scheme.secondary,
        surface: scheme.secondaryContainer,
        title: strings.onboardingSecondTitle,
        body: strings.onboardingSecondBody,
      ),
      _OnboardingPageData(
        icon: Icons.offline_bolt_rounded,
        accent: scheme.error,
        surface: scheme.errorContainer,
        title: strings.onboardingThirdTitle,
        body: strings.onboardingThirdBody,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.query_stats_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_pageIndex < _pageCount - 1)
                    TextButton(
                      key: const Key('onboarding-skip'),
                      onPressed: _saving ? null : _finish,
                      child: Text(strings.skip),
                    ),
                ],
              ),
              Expanded(
                child: Semantics(
                  label: strings.onboardingPage(_pageIndex + 1, _pageCount),
                  child: PageView.builder(
                    key: const Key('onboarding-pages'),
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: pages[index], pageIndex: index),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _pageCount; index++)
                    AnimatedContainer(
                      key: Key('onboarding-dot-$index'),
                      duration: const Duration(milliseconds: 180),
                      width: index == _pageIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _pageIndex
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key(
                    _pageIndex == _pageCount - 1
                        ? 'onboarding-start'
                        : 'onboarding-next',
                  ),
                  onPressed: _saving ? null : _handlePrimaryAction,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _pageIndex == _pageCount - 1
                              ? Icons.science_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    _pageIndex == _pageCount - 1
                        ? strings.startLearning
                        : strings.next,
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
      final strings = AppStrings(Localizations.localeOf(context));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.saveFailed)));
    }
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final Color surface;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OnboardingVisual(data: data, pageIndex: pageIndex),
              const SizedBox(height: 34),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.16),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      data.body,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final foreground = switch (pageIndex) {
      0 => Theme.of(context).colorScheme.onPrimaryContainer,
      1 => Theme.of(context).colorScheme.onSecondaryContainer,
      _ => Theme.of(context).colorScheme.onErrorContainer,
    };
    return Container(
      key: Key('onboarding-visual-$pageIndex'),
      width: 238,
      height: 238,
      decoration: BoxDecoration(
        color: data.surface,
        borderRadius: BorderRadius.circular(44),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            top: 28,
            child: _DecorativeDot(color: data.accent, size: 14),
          ),
          Positioned(
            right: 32,
            top: 42,
            child: _DecorativeDot(color: foreground, size: 9),
          ),
          Positioned(
            left: 42,
            bottom: 32,
            child: _DecorativeDot(color: foreground, size: 8),
          ),
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.86),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 78, color: data.accent),
          ),
        ],
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  const _DecorativeDot({required this.color, required this.size});

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
