import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

abstract class IntroStore {
  Future<bool> isComplete();
  Future<void> complete();
}

class LocalIntroStore implements IntroStore {
  Future<File> _marker() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/filerecheck_onboarding_v1');
  }

  @override
  Future<bool> isComplete() async => (await _marker()).exists();

  @override
  Future<void> complete() async {
    final marker = await _marker();
    await marker.writeAsString('complete', flush: true);
  }
}

const _brand = Color(0xFF0D3F43);
const _iconAsset = 'assets/branding/filerecheck_icon_1024.png';

class LaunchView extends StatelessWidget {
  const LaunchView({super.key, required this.zh});

  final bool zh;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _brand,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(_iconAsset, width: 152, height: 152),
          const SizedBox(height: 20),
          const Text(
            'FileRecheck',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            zh ? '在本机，看清每一份文件' : 'Know your files, right on your device',
            style: const TextStyle(color: Color(0xFFD0E7E3), fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.zh,
    required this.onLanguageChange,
    required this.onComplete,
  });

  final bool zh;
  final VoidCallback onLanguageChange;
  final Future<void> Function() onComplete;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _saving = false;
  bool _saveFailed = false;

  String _t(String cn, String en) => widget.zh ? cn : en;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(_iconAsset, width: 34, height: 34),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'FileRecheck',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onLanguageChange,
                        child: Text(widget.zh ? 'EN' : '中文'),
                      ),
                      if (_page < 2)
                        TextButton(
                          onPressed: _saving ? null : _finish,
                          child: Text(_t('跳过', 'Skip')),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: 3,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) =>
                        _IntroPage(index: index, zh: widget.zh),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_saveFailed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _t(
                              '无法保存引导进度，请重试。',
                              'Could not save your progress. Please retry.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final active = _page == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 22 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: active
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _next,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _page == 2
                                    ? _t('开始使用', 'Get started')
                                    : _t('继续', 'Continue'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.index, required this.zh});

  final int index;
  final bool zh;

  String _t(String cn, String en) => zh ? cn : en;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titles = [
      _t('选择本机文件', 'Open from Files'),
      _t('本机检查与修正', 'Inspect on your device'),
      _t('预览后再导出', 'Preview before exporting'),
    ];
    final descriptions = [
      _t(
        '通过系统文件入口打开 JSON、CSV、TXT 或 LOG。无需账号，也不会自动上传。',
        'Choose a JSON, CSV, TXT or LOG file through the system picker. No account or automatic upload.',
      ),
      _t(
        '查看格式与内容，搜索问题，并在工作副本中修改。原文件始终保留。',
        'Check format and content, search for issues, and edit a working copy. Your original stays intact.',
      ),
      _t(
        '先看检查报告，再决定是否导出报告或处理副本。分享只在你主动操作时发生。',
        'Review the report first, then decide whether to export it or your working copy. Sharing is always your choice.',
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('第 ${index + 1} 步，共 3 步', 'STEP ${index + 1} OF 3'),
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          _IntroArtwork(index: index, zh: zh),
          const SizedBox(height: 28),
          Text(
            titles[index],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descriptions[index],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroArtwork extends StatelessWidget {
  const _IntroArtwork({required this.index, required this.zh});

  final int index;
  final bool zh;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFCCF0E9) : _brand;
    final fill = dark ? const Color(0xFF173B3D) : const Color(0xFFE3F3EF);
    return Container(
      height: 230,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(28),
      ),
      child: switch (index) {
        0 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 82, color: foreground),
            const SizedBox(height: 22),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _Pill(
                label: 'JSON  ·  CSV  ·  TXT  ·  LOG',
                color: foreground,
              ),
            ),
          ],
        ),
        1 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ArtworkRow(
              icon: Icons.check_circle_outline,
              label: 'JSON',
              color: foreground,
            ),
            const SizedBox(height: 12),
            _ArtworkRow(
              icon: Icons.search_rounded,
              label: zh ? '搜索内容' : 'Search content',
              color: foreground,
            ),
            const SizedBox(height: 12),
            _ArtworkRow(
              icon: Icons.edit_note_rounded,
              label: zh ? '工作副本' : 'Working copy',
              color: foreground,
            ),
          ],
        ),
        _ => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 58, color: foreground),
            const SizedBox(height: 13),
            Text(
              zh ? '检查报告' : 'Inspection report',
              style: TextStyle(
                color: foreground,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _Pill(
              label: zh ? '预览后可选择导出' : 'Export only if you choose',
              color: foreground,
              icon: Icons.ios_share_rounded,
            ),
          ],
        ),
      },
    );
  }
}

class _ArtworkRow extends StatelessWidget {
  const _ArtworkRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
