import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'copy.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.controller,
    required this.copy,
  });

  final AppController controller;
  final AppCopy copy;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.controller.completeOnboarding();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveFailed = !saved;
    });
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      _OnboardingPage(
        image: 'assets/onboarding/seed.png',
        eyebrow: copy.t('第一步 · 定义', 'STEP 1 · DEFINE'),
        title: copy.t('从一个小实验开始', 'Start with one small experiment'),
        body: copy.t(
          '选一个触发线索，写下标准行动，再给低精力的日子留一个最低行动。',
          'Choose a cue, a standard action, and a smaller option for low-energy days.',
        ),
      ),
      _OnboardingPage(
        image: 'assets/onboarding/observe.png',
        eyebrow: copy.t('第二步 · 观察', 'STEP 2 · OBSERVE'),
        title: copy.t('记录真实发生的事', 'Notice what actually happened'),
        body: copy.t(
          '完成、只做一点，或暂停观察。每一天都能帮你找到更合适的方法。',
          'Do the full action, do a little, or pause. Every day gives you something to learn from.',
        ),
      ),
      _OnboardingPage(
        image: 'assets/onboarding/reflect.png',
        eyebrow: copy.t('第三步 · 复盘', 'STEP 3 · REFLECT'),
        title: copy.t('按自己的节奏继续', 'Keep going at your own pace'),
        body: copy.t(
          '在第 7、14、21 个练习日回看与调整。21 天是复盘节点，不是习惯保证；记录只留在本机。',
          'Reflect on practice days 7, 14, and 21. This is a milestone, not a habit guarantee. Records stay on your device.',
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.inkGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: AppTheme.paper,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          copy.appName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        key: const Key('onboardingSkip'),
                        onPressed: _saving ? null : _finish,
                        child: Text(copy.t('跳过', 'Skip')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _page = index),
                      children: pages,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_saveFailed) ...[
                    const SizedBox(height: 12),
                    Text(
                      copy.saveFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: Key(
                        _page == 2 ? 'onboardingStart' : 'onboardingNext',
                      ),
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _page == 2
                                  ? copy.t('开始我的实验', 'Start my experiment')
                                  : copy.continueLabel,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String image;
  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: math.min(constraints.maxWidth, 340),
                height: math.min(constraints.maxHeight * 0.53, 330),
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const SizedBox(height: 18),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
