import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final DiaryController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  var _pageIndex = 0;
  var _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final pages = <_OnboardingPageData>[
      _OnboardingPageData(
        icon: Icons.edit_note_rounded,
        title: text.onboardingFirstTitle,
        body: text.onboardingFirstBody,
      ),
      _OnboardingPageData(
        icon: Icons.event_available_rounded,
        title: text.onboardingSecondTitle,
        body: text.onboardingSecondBody,
      ),
      _OnboardingPageData(
        icon: Icons.multiple_stop_rounded,
        title: text.onboardingThirdTitle,
        body: text.onboardingThirdBody,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const _BrandMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_pageIndex < _pageCount - 1)
                    TextButton(
                      key: const ValueKey<String>('onboarding_skip'),
                      onPressed: _isSaving ? null : _finish,
                      child: Text(text.onboardingSkip),
                    ),
                ],
              ),
              Expanded(
                child: Semantics(
                  label: text.onboardingPage(_pageIndex + 1, _pageCount),
                  child: PageView.builder(
                    key: const ValueKey<String>('onboarding_pages'),
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (value) =>
                        setState(() => _pageIndex = value),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: pages[index], pageIndex: index),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (var index = 0; index < _pageCount; index++)
                    AnimatedContainer(
                      key: ValueKey<String>('onboarding_dot_$index'),
                      duration: const Duration(milliseconds: 180),
                      width: index == _pageIndex ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _pageIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: ValueKey<String>(
                      _pageIndex == _pageCount - 1
                          ? 'onboarding_start'
                          : 'onboarding_next',
                    ),
                    onPressed: _isSaving ? null : _handlePrimaryAction,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _pageIndex == _pageCount - 1
                                ? Icons.edit_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      _pageIndex == _pageCount - 1
                          ? text.onboardingStart
                          : text.onboardingNext,
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
    setState(() => _isSaving = true);
    final saved = await widget.controller.completeOnboarding();
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppText.of(context).savedFailure)));
    }
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
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
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - (compact ? 24 : 48)).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _OnboardingVisual(
                  pageIndex: pageIndex,
                  icon: data.icon,
                  compact: compact,
                ),
                SizedBox(height: compact ? 22 : 34),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: <Widget>[
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                            ),
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
        );
      },
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({
    required this.pageIndex,
    required this.icon,
    required this.compact,
  });

  final int pageIndex;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 190.0 : 238.0;
    return Container(
      key: ValueKey<String>('onboarding_visual_$pageIndex'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 36 : 46),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: size * 0.13,
            top: size * 0.14,
            child: _Dot(size: 12, color: scheme.primary),
          ),
          Positioned(
            right: size * 0.15,
            top: size * 0.2,
            child: _Dot(size: 8, color: scheme.onPrimaryContainer),
          ),
          Positioned(
            left: size * 0.18,
            bottom: size * 0.14,
            child: _Dot(size: 7, color: scheme.onPrimaryContainer),
          ),
          Transform.rotate(
            angle: pageIndex == 1 ? -0.055 : 0,
            child: Container(
              width: size * 0.58,
              height: size * 0.64,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(8, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: size * 0.31, color: scheme.primary),
            ),
          ),
          if (pageIndex == 2) ...<Widget>[
            Positioned(
              right: size * 0.12,
              bottom: size * 0.15,
              child: Container(
                width: size * 0.27,
                height: size * 0.19,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primaryContainer, width: 3),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: scheme.onPrimary,
                  size: size * 0.13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: size * 0.58,
        color: scheme.onPrimary,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
