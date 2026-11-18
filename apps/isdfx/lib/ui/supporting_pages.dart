part of 'app.dart';

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.settings, this.replay = false});

  final AppSettings settings;
  final bool replay;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  int _page = 0;
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.replay) {
        Navigator.pop(context);
      } else {
        await widget.settings.completeOnboarding();
      }
    } catch (error) {
      if (!mounted) return;
      await _notice(
        context,
        title: _text(context, '无法保存引导状态', 'Could not save setup'),
        message: _errorText(context, error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = _page == 0;
    final heroColor = theme.brightness == Brightness.dark
        ? scheme.surface
        : _brandCharcoal;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.replay,
        titleSpacing: widget.replay ? 0 : 20,
        title: Row(
          children: [
            const _Mark(size: 32),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                _brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('onboarding.skip'),
            onPressed: _saving ? null : _finish,
            child: Text(_text(context, '跳过', 'Skip')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _SupportingBody(
        key: ValueKey(_page),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: heroColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _brandRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      first
                          ? _text(context, '生成测试号码', 'Generate test numbers')
                          : _text(context, '复现同一组用例', 'Replay the same cases'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    first
                        ? _text(
                            context,
                            '按公开规则生成软件测试所需的号码。',
                            'Create numbers for software testing using public rules.',
                          )
                        : _text(
                            context,
                            '用例包保留生成参数及规则版本。',
                            'Test packages keep the generation settings and rule versions.',
                          ),
                    style: const TextStyle(
                      color: Color(0xffdedee2),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: first
                  ? [
                      _GuideTile(
                        icon: CupertinoIcons.doc_text,
                        label: _text(
                          context,
                          '选择国家、地区和证件',
                          'Choose a country and document',
                        ),
                      ),
                      const Divider(height: 1, indent: 59, endIndent: 14),
                      _GuideTile(
                        icon: CupertinoIcons.slider_horizontal_3,
                        label: _text(
                          context,
                          '设定参数后生成',
                          'Set your options and generate',
                        ),
                      ),
                      const Divider(height: 1, indent: 59, endIndent: 14),
                      _GuideTile(
                        icon: CupertinoIcons.checkmark_seal,
                        label: _text(
                          context,
                          '逐项查看规则检查',
                          'Review each rule check',
                        ),
                      ),
                    ]
                  : [
                      _GuideTile(
                        icon: CupertinoIcons.share,
                        label: _text(
                          context,
                          '导出 JSON 用例包',
                          'Export a JSON test package',
                        ),
                      ),
                      const Divider(height: 1, indent: 59, endIndent: 14),
                      _GuideTile(
                        icon: CupertinoIcons.folder_open,
                        label: _text(
                          context,
                          '打开用例包重新生成',
                          'Open the package to regenerate',
                        ),
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 18),
          const _ScopeNote(compact: true),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: _text(
                      context,
                      '引导第 ${_page + 1} 步，共 2 步',
                      'Step ${_page + 1} of 2',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 2; i++)
                          Container(
                            width: i == _page ? 22 : 7,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: ValueKey(
                      first ? 'onboarding.next' : 'onboarding.complete',
                    ),
                    onPressed: _saving
                        ? null
                        : first
                        ? () => setState(() => _page = 1)
                        : _finish,
                    child: Text(
                      first
                          ? _text(context, '继续', 'Continue')
                          : _text(context, '开始使用', 'Get started'),
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

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: _SupportingIcon(icon),
    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _SupportingBody extends StatelessWidget {
  const _SupportingBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            math.max(20, MediaQuery.viewPaddingOf(context).bottom),
          ),
          children: children,
        ),
      ),
    ),
  );
}

class _SupportingIcon extends StatelessWidget {
  const _SupportingIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .085),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 17, color: scheme.primary),
      ),
    );
  }
}

class _SupportingHeading extends StatelessWidget {
  const _SupportingHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _RulesPage extends StatelessWidget {
  const _RulesPage({required this.services});

  final PlatformServices services;

  @override
  Widget build(BuildContext context) {
    final current = FixtureEngine.profiles.where((entry) => !entry.archived);
    final archived = FixtureEngine.profiles.where((entry) => entry.archived);
    final countries = current.map((entry) => entry.country).toSet();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_text(context, '规则目录', 'Rule catalog'))),
      body: _SupportingBody(
        children: [
          Text(
            _text(
              context,
              '查看各证件的支持范围、规则版本和公开来源。',
              'See the supported checks, version and sources for each document.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          for (final country in countries) ...[
            const SizedBox(height: 22),
            _SupportingHeading(switch (country) {
              'CN' => _text(context, '中国', 'China'),
              'US' => _text(context, '美国', 'United States'),
              'VN' => _text(context, '越南', 'Vietnam'),
              _ => country,
            }),
            const SizedBox(height: 8),
            _profileGroup(context, current.where((p) => p.country == country)),
          ],
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SupportingHeading(_text(context, '归档规则', 'Archived rules')),
            const SizedBox(height: 4),
            Text(
              _text(context, '用于复现已有用例包。', 'For replaying existing packages.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _profileGroup(context, archived),
          ],
        ],
      ),
    );
  }

  Widget _profileGroup(BuildContext context, Iterable<RuleProfile> entries) {
    final profiles = entries.toList(growable: false);
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < profiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _profileTile(context, profiles[i]),
          ],
        ],
      ),
    );
  }

  Widget _profileTile(BuildContext context, RuleProfile profile) => ListTile(
    key: ValueKey('rule.${profile.id}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    title: Text(
      _chinese(context) ? profile.nameZh : profile.nameEn,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        profile.archived
            ? profile.version
            : _chinese(context)
            ? profile.coverageZh
            : profile.coverageEn,
      ),
    ),
    trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _RuleDetail(profile: profile, services: services),
      ),
    ),
  );
}

class _RuleDetail extends StatelessWidget {
  const _RuleDetail({required this.profile, required this.services});

  final RuleProfile profile;
  final PlatformServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewDate =
        ['cn-id', 'hk-id', 'mo-id', 'tw-id', 'vn-id'].contains(profile.id)
        ? '2026-11-05'
        : '2026-11-04';
    return Scaffold(
      appBar: AppBar(title: Text(_text(context, '规则与来源', 'Rule and sources'))),
      body: _SupportingBody(
        children: [
          Semantics(
            header: true,
            child: Text(
              _chinese(context) ? profile.nameZh : profile.nameEn,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            profile.version,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SupportingHeading(
                    _text(context, '支持范围', 'Supported checks'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _chinese(context) ? profile.coverageZh : profile.coverageEn,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _SupportingHeading(_text(context, '适用限制', 'Limitations')),
                  const SizedBox(height: 6),
                  Text(
                    _chinese(context)
                        ? profile.limitationsZh
                        : profile.limitationsEn,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _ScopeNote(),
          const SizedBox(height: 22),
          _SupportingHeading(_text(context, '公开来源', 'Public sources')),
          const SizedBox(height: 8),
          if (profile.sources.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < profile.sources.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      title: Text(profile.sources[i].title),
                      trailing: Icon(
                        CupertinoIcons.arrow_up_right,
                        size: 16,
                        color: scheme.primary,
                      ),
                      onTap: () => _openSource(context, profile.sources[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            _text(
              context,
              '资料核验日期：$reviewDate。打开外部来源需要联网，本地生成不需要。',
              'Sources reviewed: $reviewDate. External source pages need a connection; local generation does not.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSource(BuildContext context, RuleSource source) async {
    try {
      await services.openSource(source.url);
    } catch (error) {
      if (!context.mounted) return;
      await _notice(
        context,
        title: _text(context, '无法打开来源', 'Could not open source'),
        message: _errorText(context, error),
      );
    }
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.settings});

  final AppSettings settings;

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      await _notice(
        context,
        title: _text(context, '无法保存偏好', 'Could not save preference'),
        message: _errorText(context, error),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text(_text(context, '偏好设置', 'Preferences'))),
        body: _SupportingBody(
          children: [
            _SupportingHeading(_text(context, '显示设置', 'Display settings')),
            const SizedBox(height: 8),
            if (settings.storageWarning) ...[
              Text(
                _text(
                  context,
                  '本地偏好暂不可用，当前选择可能无法在重启后保留。',
                  'Local preferences are unavailable. Current choices may not survive a restart.',
                ),
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('settings.language'),
                    leading: const _SupportingIcon(CupertinoIcons.globe),
                    title: Text(_text(context, '界面语言', 'Interface language')),
                    subtitle: Text(
                      settings.locale?.languageCode == 'zh'
                          ? '简体中文'
                          : settings.locale?.languageCode == 'en'
                          ? 'English'
                          : _text(context, '跟随系统', 'Follow system'),
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_down, size: 15),
                    onTap: () async {
                      final selected = await _choose(
                        context,
                        title: _text(context, '界面语言', 'Interface language'),
                        options: [
                          ('system', _text(context, '跟随系统', 'Follow system')),
                          ('zh', '简体中文'),
                          ('en', 'English'),
                        ],
                      );
                      if (!context.mounted || selected == null) return;
                      await _save(
                        context,
                        () => settings.setLanguage(
                          selected == 'system' ? null : selected,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    key: const ValueKey('settings.theme'),
                    leading: const _SupportingIcon(
                      CupertinoIcons.circle_lefthalf_fill,
                    ),
                    title: Text(_text(context, '外观', 'Appearance')),
                    subtitle: Text(switch (settings.themeMode) {
                      ThemeMode.light => _text(context, '浅色', 'Light'),
                      ThemeMode.dark => _text(context, '深色', 'Dark'),
                      _ => _text(context, '跟随系统', 'Follow system'),
                    }),
                    trailing: const Icon(CupertinoIcons.chevron_down, size: 15),
                    onTap: () async {
                      final selected = await _choose(
                        context,
                        title: _text(context, '外观', 'Appearance'),
                        options: [
                          ('system', _text(context, '跟随系统', 'Follow system')),
                          ('light', _text(context, '浅色', 'Light')),
                          ('dark', _text(context, '深色', 'Dark')),
                        ],
                      );
                      if (!context.mounted || selected == null) return;
                      await _save(
                        context,
                        () => settings.setThemeMode(
                          ThemeMode.values.firstWhere(
                            (mode) => mode.name == selected,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SupportingHeading(_text(context, '使用帮助', 'Help')),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                key: const ValueKey('settings.replay'),
                leading: const _SupportingIcon(CupertinoIcons.question_circle),
                title: Text(_text(context, '重新查看使用引导', 'Replay introduction')),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _Onboarding(settings: settings, replay: true),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SupportingHeading(_text(context, '数据与隐私', 'Data and privacy')),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        context,
                        '在本机生成，结果不保存为历史记录。导出时由系统缓存管理临时副本。',
                        'Cases are generated on this device without keeping a history. The system cache manages temporary export copies.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _ScopeNote(compact: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_brandName · 1.1.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}
