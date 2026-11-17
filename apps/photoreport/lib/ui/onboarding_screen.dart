import 'package:flutter/material.dart';

import 'app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.locale,
    required this.preferredLocale,
    required this.onLocaleChanged,
    required this.onFinished,
    super.key,
  });

  final Locale locale;
  final Locale? preferredLocale;
  final ValueChanged<Locale?> onLocaleChanged;
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(title: '现场记录，从拍下开始', body: '照片、位置与说明放在一起，现场信息不再散落。'),
    _OnboardingPageData(title: '重点一眼可见', body: '用方框、箭头和文字标出重点，并保留处理前后对照。'),
    _OnboardingPageData(
      title: '离线整理，放心分享',
      body: '资料默认保存在本机，整理完成后可生成清晰的 PDF 记录。',
    ),
  ];

  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_pageIndex == _pages.length - 1) {
      widget.onFinished();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  return Row(
                    children: [
                      _LanguageButton(
                        locale: widget.locale,
                        preferredLocale: widget.preferredLocale,
                        onChanged: widget.onLocaleChanged,
                        compact: compact,
                      ),
                      const Spacer(),
                      if (_pageIndex != _pages.length - 1)
                        TextButton(
                          key: const Key('onboarding-skip'),
                          onPressed: widget.onFinished,
                          child: const LText('跳过'),
                        ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('onboarding-pages'),
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _pageIndex = value),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index], index: index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final dots = Row(
                    children: [
                      for (var index = 0; index < _pages.length; index++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: index == _pageIndex ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: index == _pageIndex
                                ? context.appColors.brand
                                : context.appColors.line,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  );
                  final label = LText(
                    _pageIndex == _pages.length - 1 ? '开始记录' : '下一步',
                  );
                  final button = compact
                      ? FilledButton(
                          key: const Key('onboarding-continue'),
                          onPressed: _continue,
                          child: label,
                        )
                      : FilledButton.icon(
                          key: const Key('onboarding-continue'),
                          onPressed: _continue,
                          icon: Icon(
                            _pageIndex == _pages.length - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: label,
                        );
                  return Row(
                    children: [
                      dots,
                      const SizedBox(width: 16),
                      if (compact)
                        Expanded(child: button)
                      else ...[
                        const Spacer(),
                        button,
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.index});

  final _OnboardingPageData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _OnboardingArtwork(index: index),
                  const SizedBox(height: 34),
                  LText(
                    data.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: context.appColors.ink,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LText(
                    data.body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.appColors.muted,
                      height: 1.6,
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

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      height: 252,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.appColors.line),
        boxShadow: [
          BoxShadow(
            color: context.appColors.brand.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: switch (index) {
        0 => _brandArtwork(),
        1 => _annotationArtwork(context.appColors),
        _ => _reportArtwork(context.appColors),
      },
    );
  }

  Widget _brandArtwork() {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Image.asset(
        'assets/branding/jovfx_mark.png',
        key: const Key('onboarding-brand-mark'),
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _annotationArtwork(AppThemeColors colors) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.softSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.photo_camera_back_rounded,
                size: 78,
                color: colors.brand,
              ),
            ),
          ),
        ),
        Positioned(
          left: 58,
          top: 64,
          child: Container(
            width: 112,
            height: 88,
            decoration: BoxDecoration(
              border: Border.all(color: annotationColor, width: 4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const Positioned(
          right: 35,
          bottom: 42,
          child: CircleAvatar(
            radius: 31,
            backgroundColor: annotationColor,
            foregroundColor: Colors.white,
            child: Icon(Icons.edit_rounded, size: 29),
          ),
        ),
      ],
    );
  }

  Widget _reportArtwork(AppThemeColors colors) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -0.08,
          child: Container(
            width: 132,
            height: 170,
            decoration: BoxDecoration(
              color: colors.softSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.line),
            ),
          ),
        ),
        Container(
          width: 132,
          height: 170,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: colors.brand, size: 42),
              const Spacer(),
              const _ReportLine(width: 82),
              const SizedBox(height: 10),
              const _ReportLine(width: 66),
              const SizedBox(height: 10),
              const _ReportLine(width: 76),
            ],
          ),
        ),
        Positioned(
          right: 35,
          bottom: 35,
          child: CircleAvatar(
            radius: 31,
            backgroundColor: colors.brand,
            foregroundColor: colors.onBrand,
            child: const Icon(Icons.ios_share_rounded, size: 29),
          ),
        ),
      ],
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: context.appColors.line,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.locale,
    required this.preferredLocale,
    required this.onChanged,
    required this.compact,
  });

  final Locale locale;
  final Locale? preferredLocale;
  final ValueChanged<Locale?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = preferredLocale == null
        ? tr('跟随系统', locale: widgetLocale(context))
        : locale.languageCode == 'zh'
        ? '简体中文'
        : 'English';
    return PopupMenuButton<String>(
      key: const Key('onboarding-language'),
      tooltip: tr('语言', locale: widgetLocale(context)),
      onSelected: (value) {
        if (value == 'system') onChanged(null);
        if (value == 'zh') onChanged(const Locale('zh', 'CN'));
        if (value == 'en') onChanged(const Locale('en'));
      },
      itemBuilder: (context) => [
        _languageItem(context, 'system', '跟随系统', preferredLocale == null),
        _languageItem(
          context,
          'zh',
          '简体中文',
          preferredLocale?.languageCode == 'zh',
        ),
        _languageItem(
          context,
          'en',
          'English',
          preferredLocale?.languageCode == 'en',
        ),
      ],
      child: Container(
        width: compact ? 42 : null,
        height: 42,
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 19,
              color: context.appColors.brand,
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: context.appColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Locale widgetLocale(BuildContext context) => Localizations.localeOf(context);

  PopupMenuItem<String> _languageItem(
    BuildContext context,
    String value,
    String label,
    bool selected,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_rounded : Icons.language_rounded,
            color: selected ? context.appColors.brand : context.appColors.muted,
          ),
          const SizedBox(width: 12),
          LText(label),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({required this.title, required this.body});

  final String title;
  final String body;
}
