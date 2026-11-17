import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../app_controller.dart';
import '../models.dart';
import '../report/report_service.dart';
import 'app_theme.dart';
import 'create_flow_sheet.dart';
import 'issue_form_screen.dart';
import 'privacy_policy_screen.dart';
import 'project_detail_screen.dart';
import 'project_form_sheet.dart';
import 'widgets/common.dart';

enum _HomeSettingsAction {
  createBackup,
  restoreBackup,
  language,
  privacyPolicy,
}

enum _HomeLocaleChoice { system, zh, en }

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({
    required this.controller,
    required this.preferredLocale,
    required this.onLocaleChanged,
    super.key,
  });

  final PhotoReportController controller;
  final Locale? preferredLocale;
  final ValueChanged<Locale?> onLocaleChanged;

  Future<ProjectRecord?> _editProject(
    BuildContext context, {
    ProjectRecord? project,
    bool formalFlow = false,
  }) async {
    final result = await showAppBottomSheet<ProjectRecord>(
      context: context,
      builder: (context) => ProjectFormSheet(
        project: project,
        formalFlow: formalFlow,
        suggestedNames: controller.projects
            .map((overview) => overview.project.name)
            .where((name) => name != project?.name)
            .toSet()
            .toList(),
      ),
    );
    if (result == null || !context.mounted) return null;
    try {
      await controller.saveProject(result);
      return result;
    } catch (error) {
      if (context.mounted) AppToast.showError(context, error);
      return null;
    }
  }

  Future<void> _openCreateFlow(BuildContext context) async {
    final choice = await showAppBottomSheet<CreateFlowChoice>(
      context: context,
      builder: (context) => CreateFlowSheet(
        projects: controller.projects
            .map((overview) => overview.project)
            .toList(),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice.kind == CreateFlowKind.formal) {
      final created = await _editProject(context, formalFlow: true);
      if (created == null || !context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectDetailScreen(
            controller: controller,
            initialProject: created,
            formalFlow: true,
            autoStartIssue: true,
          ),
        ),
      );
      await controller.refreshProjects();
      return;
    }

    var target = choice.project;
    if (target == null) {
      final name = await showAppBottomSheet<String>(
        context: context,
        builder: (context) => const QuickProjectNameSheet(),
      );
      if (name == null || !context.mounted) return;
      final now = DateTime.now();
      target = ProjectRecord(
        id: const Uuid().v4(),
        name: name,
        address: '',
        companyName: '',
        inspectorName: '',
        clientName: '',
        codePrefix: 'A',
        inspectionDate: now,
        notes: '',
        createdAt: now,
        updatedAt: now,
      );
      try {
        await controller.saveProject(target);
      } catch (error) {
        if (context.mounted) AppToast.showError(context, error);
        return;
      }
    }
    if (!context.mounted) return;
    await _openQuickIssue(context, target);
  }

  Future<void> _openQuickIssue(
    BuildContext context,
    ProjectRecord project,
  ) async {
    var addAnother = true;
    while (addAnother && context.mounted) {
      addAnother = false;
      try {
        final issues = await controller.loadIssues(project.id);
        final sequence = await controller.nextIssueSequence(project.id);
        if (!context.mounted) return;
        final result = await Navigator.push<IssueFormResult>(
          context,
          MaterialPageRoute(
            builder: (context) => IssueFormScreen(
              controller: controller,
              project: project,
              sequence: sequence,
              existingIssues: issues,
              entryMode: IssueEntryMode.quick,
              offerPostSaveActions: true,
            ),
          ),
        );
        await controller.refreshProjects();
        if (!context.mounted || result == null) return;
        if (result == IssueFormResult.savedAndAddAnother) {
          addAnother = true;
        } else if (result == IssueFormResult.savedAndOpenProject) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailScreen(
                controller: controller,
                initialProject: project,
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) AppToast.showError(context, error);
        return;
      }
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    ProjectRecord project,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: '删除“${project.name}”？',
      message: '项目内的记录、照片和标注都会从本机删除，此操作无法撤销。',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.deleteProject(project.id);
    } catch (error) {
      if (context.mounted) AppToast.showError(context, error);
    }
  }

  Future<void> _createBackup(BuildContext context) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    try {
      final path = await controller.createBackup();
      await const ReportService().share(path, languageCode: languageCode);
      if (context.mounted) {
        AppToast.show(
          context,
          tr('本地备份已生成，可保存到“文件”或发送到其他设备'),
          style: AppToastStyle.success,
        );
      }
    } catch (error) {
      if (context.mounted) AppToast.showError(context, error);
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final path = await const ReportService().pickBackup(
        languageCode: Localizations.localeOf(context).languageCode,
      );
      if (path == null || !context.mounted) return;
      final confirmed = await confirmAction(
        context,
        title: '恢复这份本地备份？',
        message: '当前项目、记录和照片会被备份内容替换。建议先导出一份当前备份。',
        confirmLabel: '确认恢复',
      );
      if (!confirmed || !context.mounted) return;
      await controller.restoreBackup(path);
      if (context.mounted) {
        AppToast.show(context, tr('备份已恢复'), style: AppToastStyle.success);
      }
    } catch (error) {
      if (context.mounted) AppToast.showError(context, error);
    }
  }

  Future<void> _openSettingsAndData(BuildContext context) async {
    final action = await showAppBottomSheet<_HomeSettingsAction>(
      context: context,
      builder: (context) => _SettingsAndDataSheet(
        preferredLocale: preferredLocale,
        onSelected: (action) => Navigator.pop(context, action),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _HomeSettingsAction.createBackup:
        await _createBackup(context);
      case _HomeSettingsAction.restoreBackup:
        await _restoreBackup(context);
      case _HomeSettingsAction.language:
        await _chooseLanguage(context);
      case _HomeSettingsAction.privacyPolicy:
        await PrivacyPolicyScreen.open(context);
    }
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final choice = await showAppBottomSheet<_HomeLocaleChoice>(
      context: context,
      builder: (context) => _LanguageSettingsSheet(
        preferredLocale: preferredLocale,
        onSelected: (choice) => Navigator.pop(context, choice),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _HomeLocaleChoice.system:
        onLocaleChanged(null);
      case _HomeLocaleChoice.zh:
        onLocaleChanged(const Locale('zh', 'CN'));
      case _HomeLocaleChoice.en:
        onLocaleChanged(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasProjects =
            !controller.isLoading &&
            controller.loadError == null &&
            controller.projects.isNotEmpty;
        final mediaQuery = MediaQuery.of(context);
        final compactActions =
            mediaQuery.size.width < 370 ||
            mediaQuery.textScaler.scale(1) > 1.15;
        final subtitleStyle = TextStyle(
          color: context.appColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.25,
        );
        final subtitlePainter = TextPainter(
          text: TextSpan(
            text: tr('编号 · 标注 · 整理分享', locale: Localizations.localeOf(context)),
            style: subtitleStyle,
          ),
          textDirection: Directionality.of(context),
          textScaler: mediaQuery.textScaler,
        )..layout(maxWidth: mediaQuery.size.width - 48);
        final subtitleHeight = subtitlePainter.height + 8;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 56,
            titleSpacing: 24,
            title: Text(
              'JOVFX',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                key: const Key('home-settings-button'),
                tooltip: tr('更多操作'),
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () => _openSettingsAndData(context),
              ),
              if (hasProjects)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: compactActions
                      ? SizedBox.square(
                          dimension: 48,
                          child: FilledButton(
                            key: const Key('home-appbar-create'),
                            onPressed: () => _openCreateFlow(context),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.add_rounded),
                          ),
                        )
                      : FilledButton.icon(
                          key: const Key('home-appbar-create'),
                          onPressed: () => _openCreateFlow(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const LText('新建'),
                        ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(subtitleHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LText(
                    '编号 · 标注 · 整理分享',
                    softWrap: true,
                    style: subtitleStyle,
                  ),
                ),
              ),
            ),
          ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: context.appColors.muted,
              ),
              const SizedBox(height: 16),
              const LText('暂时无法读取本地项目'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.initialize,
                child: const LText('重新载入'),
              ),
            ],
          ),
        ),
      );
    }
    if (controller.projects.isEmpty) {
      return _EmptyProjects(onCreate: () => _openCreateFlow(context));
    }
    return RefreshIndicator(
      onRefresh: controller.refreshProjects,
      child: ListView(
        padding: AppInsets.scrollable(context, left: 16, top: 8, right: 16),
        children: [
          const SectionHeader(
            title: '记录项目',
            subtitle: '每个地点独立整理，可继续补充照片并再次分享。',
          ),
          const SizedBox(height: 16),
          for (final overview in controller.projects) ...[
            _ProjectCard(
              overview: overview,
              onOpen: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(
                      controller: controller,
                      initialProject: overview.project,
                      formalFlow: overview.project.formalFlowStep > 0,
                    ),
                  ),
                );
                await controller.refreshProjects();
              },
              onEdit: () => _editProject(context, project: overview.project),
              onDelete: () => _deleteProject(context, overview.project),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const _UsageNotice(),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.overview,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectOverview overview;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final project = overview.project;
    final isFormal = project.formalFlowStep > 0;
    return Card(
      key: Key('project-card-${project.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.appColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color: context.appColors.brand,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _ProjectModeBadge(isFormal: isFormal),
                                  if (overview.highSeverity > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appColors.risk
                                            .withValues(alpha: 0.09),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: LText(
                                        '${overview.highSeverity} 项高优先级',
                                        style: TextStyle(
                                          color: context.appColors.risk,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              tooltip: tr('项目操作'),
                              onSelected: (value) {
                                if (value == 'edit') onEdit();
                                if (value == 'delete') onDelete();
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: LText('编辑项目'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: LText('删除项目'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LText(
                          project.name,
                          translate: false,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: context.appColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: LText(
                                project.address.isEmpty
                                    ? '地点待补充'
                                    : project.address,
                                translate: project.address.isEmpty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.appColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: context.appColors.muted,
                            ),
                            const SizedBox(width: 6),
                            LText(
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(project.inspectionDate),
                              translate: false,
                              style: TextStyle(
                                color: context.appColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isFormal) ...[
                const SizedBox(height: 14),
                _ProjectProgressStrip(step: project.formalFlowStep),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: context.appColors.line),
              const SizedBox(height: 10),
              CompactStatusSummary(
                total: overview.total,
                pending: overview.pending,
                inProgress: overview.inProgress,
                completed: overview.completed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectModeBadge extends StatelessWidget {
  const _ProjectModeBadge({required this.isFormal});

  final bool isFormal;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(isFormal ? 'formal-project-mode' : 'quick-project-mode'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.appColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: context.appColors.brand.withValues(alpha: 0.16),
        ),
      ),
      child: LText(
        isFormal ? '正式记录' : '快速记录',
        style: TextStyle(
          color: context.appColors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProjectProgressStrip extends StatelessWidget {
  const _ProjectProgressStrip({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final effectiveStep = step.clamp(2, 3);
    return Container(
      key: const Key('formal-project-progress'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.appColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: LText(
              effectiveStep == 3 ? '第 3/3 步 · 继续整理复核' : '第 2/3 步 · 继续添加记录',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: context.appColors.brand,
          ),
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isTall = screenHeight >= 800;
    final topSpacing = isTall ? 155.0 : (screenHeight >= 700 ? 72.0 : 24.0);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            30,
            0,
            30,
            AppInsets.bottomSafeSpacing(context, minimum: 20),
          ),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topSpacing),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.appColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.article_outlined,
                      size: 36,
                      color: context.appColors.brand,
                    ),
                  ),
                ),
                SizedBox(height: isTall ? 22 : 20),
                LText(
                  '从第一个记录项目开始',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.appColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: isTall ? 10 : 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      '把同一现场的照片归在一起，',
                      style: TextStyle(
                        color: context.appColors.muted,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                    LText(
                      '边拍边编号，整理后直接分享。',
                      style: TextStyle(
                        color: context.appColors.muted,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTall ? 34 : 24),
                const _FirstUseSteps(),
                SizedBox(height: isTall ? 40 : 24),
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    key: const Key('empty-create-project'),
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                    label: const LText('新建记录项目'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 28),
                const _CompactUsageNotice(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FirstUseSteps extends StatelessWidget {
  const _FirstUseSteps();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          child: _FirstUseStep(number: '1', label: '新建项目'),
        ),
        _FirstUseStepConnector(),
        Expanded(
          child: _FirstUseStep(number: '2', label: '添加照片'),
        ),
        _FirstUseStepConnector(),
        Expanded(
          child: _FirstUseStep(number: '3', label: '整理分享'),
        ),
      ],
    );
  }
}

class _FirstUseStep extends StatelessWidget {
  const _FirstUseStep({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.appColors.brand.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: LText(
            number,
            translate: false,
            style: TextStyle(
              color: context.appColors.brand,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LText(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.appColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _FirstUseStepConnector extends StatelessWidget {
  const _FirstUseStepConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1,
      margin: const EdgeInsets.only(top: 18),
      color: context.appColors.brand.withValues(alpha: 0.16),
    );
  }
}

class _CompactUsageNotice extends StatelessWidget {
  const _CompactUsageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.appColors.brand.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.appColors.brand,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: LText(
              '仅用于现场沟通与情况记录 · 数据保存在本机',
              style: TextStyle(
                color: context.appColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAndDataSheet extends StatelessWidget {
  const _SettingsAndDataSheet({
    required this.preferredLocale,
    required this.onSelected,
  });

  final Locale? preferredLocale;
  final ValueChanged<_HomeSettingsAction> onSelected;

  String get _languageLabel {
    if (preferredLocale == null) return '跟随系统';
    return preferredLocale!.languageCode == 'zh' ? '简体中文' : 'English';
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.44)
        .clamp(370.0, 410.0)
        .toDouble();
    return SizedBox(
      height: sheetHeight,
      child: ColoredBox(
        key: const Key('home-settings-sheet'),
        color: context.appColors.surface,
        child: SingleChildScrollView(
          key: const Key('home-settings-scroll'),
          padding: AppInsets.scrollable(
            context,
            left: 24,
            top: 8,
            right: 24,
            bottom: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.appColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LText(
                '设置与数据',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.appColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const _SettingsSectionLabel('本地数据'),
              const SizedBox(height: 3),
              _SettingsRow(
                key: const Key('settings-backup'),
                icon: Icons.save_alt_rounded,
                title: '导出本地备份',
                subtitle: '保存项目、记录和照片',
                onTap: () => onSelected(_HomeSettingsAction.createBackup),
              ),
              Divider(height: 1, color: context.appColors.line),
              _SettingsRow(
                key: const Key('settings-restore'),
                icon: Icons.restore_rounded,
                title: '从备份恢复',
                subtitle: '将替换当前本机数据',
                onTap: () => onSelected(_HomeSettingsAction.restoreBackup),
              ),
              const SizedBox(height: 8),
              const _SettingsSectionLabel('显示语言'),
              const SizedBox(height: 3),
              _SettingsRow(
                key: const Key('settings-language'),
                icon: Icons.language_rounded,
                title: '语言',
                trailingLabel: _languageLabel,
                onTap: () => onSelected(_HomeSettingsAction.language),
              ),
              Divider(height: 1, color: context.appColors.line),
              const SizedBox(height: 8),
              const _SettingsSectionLabel('隐私与支持'),
              const SizedBox(height: 3),
              _SettingsRow(
                key: const Key('settings-privacy-policy'),
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                subtitle: '在浏览器中查看官方隐私政策',
                onTap: () => onSelected(_HomeSettingsAction.privacyPolicy),
              ),
              Divider(height: 1, color: context.appColors.line),
              const SizedBox(height: 8),
              LText(
                '所有数据默认保存在本机',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSettingsSheet extends StatelessWidget {
  const _LanguageSettingsSheet({
    required this.preferredLocale,
    required this.onSelected,
  });

  final Locale? preferredLocale;
  final ValueChanged<_HomeLocaleChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('home-language-sheet'),
      color: context.appColors.surface,
      child: Padding(
        padding: AppInsets.scrollable(
          context,
          left: 24,
          top: 10,
          right: 24,
          bottom: 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: context.appColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            LText(
              '语言',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.appColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _LanguageChoiceRow(
              key: const Key('language-system'),
              label: '跟随系统',
              selected: preferredLocale == null,
              onTap: () => onSelected(_HomeLocaleChoice.system),
            ),
            _LanguageChoiceRow(
              key: const Key('language-zh'),
              label: '简体中文',
              selected: preferredLocale?.languageCode == 'zh',
              onTap: () => onSelected(_HomeLocaleChoice.zh),
            ),
            _LanguageChoiceRow(
              key: const Key('language-en'),
              label: 'English',
              selected: preferredLocale?.languageCode == 'en',
              onTap: () => onSelected(_HomeLocaleChoice.en),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return LText(
      label,
      style: TextStyle(
        color: context.appColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appColors.brand.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.appColors.brand, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    title,
                    style: TextStyle(
                      color: context.appColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    LText(
                      subtitle!,
                      style: TextStyle(
                        color: context.appColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingLabel != null) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: LText(
                  trailingLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: context.appColors.muted,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: context.appColors.muted),
          ],
        ),
      ),
    );
  }
}

class _LanguageChoiceRow extends StatelessWidget {
  const _LanguageChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.language_rounded,
              color: selected
                  ? context.appColors.brand
                  : context.appColors.muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: LText(
                label,
                style: TextStyle(
                  color: context.appColors.ink,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageNotice extends StatelessWidget {
  const _UsageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.appColors.brand,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: LText(
              '内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。数据默认保存在本机，可从右上角导出备份。',
              style: TextStyle(
                color: context.appColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
