import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../l10n/app_strings.dart';
import 'app_notice.dart';
import 'page_safe_area.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.store, this.replay = false, super.key});

  final ReaderEditStore store;
  final bool replay;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.replay) {
      Navigator.pop(context);
      return;
    }
    try {
      await widget.store.completeOnboarding();
    } on Object {
      if (mounted) showAppNotice(context, AppStrings.of(context).saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final strings = AppStrings.of(context);
        final colors = Theme.of(context).colorScheme;
        final busy = widget.store.isBusy;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              'ReaderEdit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            actions: [
              CupertinoButton(
                onPressed: busy ? null : _finish,
                child: Text(
                  strings.skipTour,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          body: PageSafeArea(
            builder: (context) => PageView.builder(
              controller: _pages,
              itemCount: 3,
              onPageChanged: (value) => setState(() => _step = value),
              itemBuilder: (context, index) => LayoutBuilder(
                builder: (context, constraints) => ListView(
                  key: ValueKey('onboarding_step_$index'),
                  padding: pageScrollPadding(context, horizontal: 24, top: 16),
                  children: [
                    if (index == 0) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: widget.store.languageCode,
                          children: const {
                            'zh': Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                '简体中文',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            'en': Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                'English',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          },
                          onValueChanged: (value) async {
                            if (value == null || busy) return;
                            try {
                              await widget.store.setLanguageCode(value);
                            } on Object {
                              if (context.mounted) {
                                showAppNotice(context, strings.saveFailed);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _TourArtwork(
                      step: index,
                      height: math.min(
                        210.0,
                        math.max(100.0, constraints.maxHeight * 0.34),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '0${index + 1} / 03',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.tourTitle(index),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 26, height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.tourBody(index),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Container(
                            width: i == _step ? 24 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i == _step
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onPressed: busy
                            ? null
                            : _step == 2
                            ? _finish
                            : () => _pages.nextPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ),
                        child: Text(
                          _step == 2 ? strings.finishTour : strings.nextTour,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Decorative manuscript illustrations drawn as UI, with no downloaded images.
class _TourArtwork extends StatelessWidget {
  const _TourArtwork({required this.step, required this.height});
  final int step;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(20),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 260,
            height: 156,
            child: step == 0
                ? Center(
                    child: CustomPaint(
                      size: const Size(132, 132),
                      painter: _BookPainter(colors.primary),
                    ),
                  )
                : step == 1
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final color in [
                        const Color(0xFF1D6B52),
                        const Color(0xFFB46A32),
                        const Color(0xFFAA3E5C),
                      ])
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 5,
                                  color: colors.outlineVariant,
                                ),
                              ),
                              const SizedBox(width: 35),
                            ],
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _PaperCard(edited: false, colors: colors),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.primary,
                        ),
                      ),
                      Expanded(child: _PaperCard(edited: true, colors: colors)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.edited, required this.colors});
  final bool edited;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    height: 136,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          edited ? Icons.edit_outlined : Icons.notes_rounded,
          size: 20,
          color: colors.primary,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          FractionallySizedBox(
            widthFactor: i == 3 ? .6 : 1,
            child: Container(
              height: 5,
              color: edited && i == 1 ? colors.primary : colors.outlineVariant,
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    ),
  );
}

class _BookPainter extends CustomPainter {
  const _BookPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 128, size.height / 128);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(16, 24)
        ..cubicTo(40, 20, 56, 28, 64, 38)
        ..lineTo(64, 108)
        ..cubicTo(52, 94, 32, 90, 16, 94)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(64, 38)
        ..cubicTo(80, 24, 98, 20, 114, 24)
        ..lineTo(114, 94)
        ..cubicTo(96, 90, 76, 96, 64, 108)
        ..close(),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(77, 49)
        ..lineTo(99, 45)
        ..moveTo(77, 64)
        ..lineTo(99, 60)
        ..moveTo(77, 79)
        ..lineTo(91, 76),
      stroke..strokeWidth = 4,
    );
    canvas.drawCircle(
      const Offset(105, 77),
      4,
      Paint()..color = const Color(0xFFD96C42),
    );
  }

  @override
  bool shouldRepaint(_BookPainter oldDelegate) => oldDelegate.color != color;
}
