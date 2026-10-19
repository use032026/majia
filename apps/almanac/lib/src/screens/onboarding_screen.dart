import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const int _pageCount = 3;
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    _pages.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final colors = Theme.of(context).colorScheme;
    final lastPage = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '宜',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: colors.onSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.text('appName'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!lastPage)
                    TextButton(
                      key: const Key('open_today_button'),
                      onPressed: widget.controller.isBusy
                          ? null
                          : widget.controller.completeOnboarding,
                      child: Text(strings.text('onboardingSkip')),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _pageCount,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) =>
                    _OnboardingPage(index: index, strings: strings),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (widget.controller.hasSaveFailure) ...<Widget>[
                      Text(
                        strings.text('saveError'),
                        style: TextStyle(color: colors.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Semantics(
                      label: '${_page + 1}/$_pageCount',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(
                            _pageCount,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: index == _page ? 26 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: index == _page
                                    ? colors.primary
                                    : colors.outlineVariant,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    FilledButton(
                      key: Key(
                        lastPage
                            ? 'open_today_button'
                            : 'onboarding_next_button',
                      ),
                      onPressed: widget.controller.isBusy
                          ? null
                          : lastPage
                          ? widget.controller.completeOnboarding
                          : _next,
                      child: Text(
                        widget.controller.isBusy
                            ? strings.text('saving')
                            : strings.text(
                                lastPage ? 'openToday' : 'onboardingNext',
                              ),
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
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.index, required this.strings});

  final int index;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final eyebrow = switch (index) {
      0 => 'introEyebrow',
      1 => 'onboardingStep2Eyebrow',
      _ => 'onboardingStep3Eyebrow',
    };
    final title = switch (index) {
      0 => 'introTitle',
      1 => 'onboardingStep2Title',
      _ => 'onboardingStep3Title',
    };
    final body = switch (index) {
      0 => 'introBody',
      1 => 'onboardingStep2Body',
      _ => 'onboardingStep3Body',
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final artHeight = math.max(
          190.0,
          math.min(234.0, constraints.maxHeight * 0.43),
        );
        return SingleChildScrollView(
          key: Key('onboarding_page_$index'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: SizedBox(
                    height: artHeight,
                    child: _OnboardingArt(index: index, strings: strings),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  strings.text(eyebrow),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    strings.text(title),
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  strings.text(body),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (index == 0 || index == 2)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        index == 0
                            ? Icons.auto_awesome_outlined
                            : Icons.lock_outline_rounded,
                        size: 20,
                        color: colors.secondary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          strings.text(
                            index == 0 ? 'notDivination' : 'privateByDesign',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt({required this.index, required this.strings});

  final int index;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: AspectRatio(
        aspectRatio: 1.32,
        child: Container(
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                right: 22,
                top: 18,
                child: Icon(
                  Icons.wb_sunny_outlined,
                  size: 52,
                  color: colors.primary.withValues(alpha: 0.16),
                ),
              ),
              Positioned.fill(
                left: 28,
                right: 28,
                top: 21,
                bottom: 21,
                child: Transform.rotate(
                  angle: index == 2 ? -0.06 : 0.035,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: switch (index) {
                      0 => _CoverArt(colors: colors),
                      1 => _ChoiceArt(colors: colors, strings: strings),
                      _ => _FolioArt(colors: colors, strings: strings),
                    },
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

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 12,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'DEYNU',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Container(height: 1, color: colors.outlineVariant),
              Align(
                alignment: Alignment.centerRight,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.secondary,
                  child: Text(
                    '宜',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: colors.onSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceArt extends StatelessWidget {
  const _ChoiceArt({required this.colors, required this.strings});

  final ColorScheme colors;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChoiceLine(
            mark: strings.text('suitable'),
            text: strings.text('onboardingPreviewTry'),
            color: colors.primary,
          ),
          _ChoiceLine(
            mark: strings.text('avoid'),
            text: strings.text('onboardingPreviewSkip'),
            color: colors.secondary,
          ),
          if (constraints.maxHeight >= 145) ...<Widget>[
            Container(height: 1, color: colors.outlineVariant),
            Text(
              strings.text('onboardingPreviewIntention'),
              textScaler: TextScaler.noScaling,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({
    required this.mark,
    required this.text,
    required this.color,
  });

  final String mark;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mark,
            textScaler: TextScaler.noScaling,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            textScaler: TextScaler.noScaling,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(Icons.check_circle, size: 19, color: color),
      ],
    );
  }
}

class _FolioArt extends StatelessWidget {
  const _FolioArt({required this.colors, required this.strings});

  final ColorScheme colors;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.menu_book_outlined, color: colors.primary, size: 27),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.text('onboardingPreviewFolio'),
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          height: 9,
          width: 125,
          color: colors.primary.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 9),
        Container(
          height: 9,
          width: 170,
          color: colors.primary.withValues(alpha: 0.10),
        ),
        const SizedBox(height: 9),
        Container(
          height: 9,
          width: 98,
          color: colors.primary.withValues(alpha: 0.10),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.lock_outline_rounded,
            size: 32,
            color: colors.secondary,
          ),
        ),
      ],
    );
  }
}
