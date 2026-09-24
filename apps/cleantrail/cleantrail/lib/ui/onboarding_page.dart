import 'package:flutter/material.dart';

import '../app/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _assetName =
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png';
  static const _pages = [
    _OnboardingItem(
      icon: Icons.file_open_outlined,
      titleKey: 'onboardingImportTitle',
      bodyKey: 'onboardingImportBody',
    ),
    _OnboardingItem(
      icon: Icons.rule_folder_outlined,
      titleKey: 'onboardingRepairTitle',
      bodyKey: 'onboardingRepairBody',
    ),
    _OnboardingItem(
      icon: Icons.phonelink_lock_outlined,
      titleKey: 'onboardingPrivacyTitle',
      bodyKey: 'onboardingPrivacyBody',
    ),
  ];

  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinished();
      return;
    }
    _pageController.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLastPage = _page == _pages.length - 1;
    return Scaffold(
      key: const Key('onboarding-screen'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      _assetName,
                      key: const Key('onboarding-brand-mark'),
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.s.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: widget.onFinished,
                    child: Text(context.s.get('onboardingSkip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) =>
                    _OnboardingSlide(item: _pages[index], page: index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  key: Key('onboarding-dot-$index'),
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? colors.primary
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key(isLastPage ? 'onboarding-start' : 'onboarding-next'),
                  onPressed: _next,
                  icon: Icon(
                    isLastPage
                        ? Icons.arrow_forward_rounded
                        : Icons.chevron_right_rounded,
                  ),
                  label: Text(
                    context.s.get(
                      isLastPage ? 'onboardingStart' : 'onboardingNext',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.item, required this.page});

  final _OnboardingItem item;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: Key('onboarding-page-$page'),
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(38),
                ),
                child: Icon(item.icon, size: 64, color: colors.primary),
              ),
              const SizedBox(height: 34),
              Text(
                context.s.get(item.titleKey),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  context.s.get(item.bodyKey),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
}
