import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../data/app_store.dart';
import '../models/box_record.dart';
import '../models/entry_batch.dart';
import '../models/moving_project.dart';
import '../services/export_service.dart';
import '../services/photo_storage.dart';
import '../widgets/ios_modal.dart';
import '../widgets/localized_values.dart';
import '../widgets/physical_mark_dialog.dart';
import '../widgets/project_form_dialog.dart';
import 'batch_capture_screen.dart';
import 'batch_editor_screen.dart';
import 'box_editor_screen.dart';
import 'moving_scan_screen.dart';
import 'pending_marks_screen.dart';
import 'qr_label_screen.dart';
import 'voice_entry_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _query = TextEditingController();
  final _photos = PhotoStorage();
  final _exports = const ExportService();
  final _stageFilters = <_StageFilter>{};
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<String?> _openEditor(String boxId) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => BoxEditorScreen(boxId: boxId)),
    );
  }

  Future<void> _manualEntry() async {
    final boxId = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => BoxEditorScreen.create(projectId: widget.projectId),
      ),
    );
    if (!mounted || boxId == null) return;
    final current = StoreScope.of(context).boxById(boxId);
    if (current != null &&
        current.physicalMarkStatus == PhysicalMarkStatus.pending) {
      await showPhysicalMarkReminder(context, current);
    }
  }

  Future<void> _voiceEntry() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => VoiceEntryScreen(projectId: widget.projectId),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'manual') {
      await _manualEntry();
      return;
    }
    final box = StoreScope.of(context).boxById(result);
    if (box != null) {
      await _openEditor(box.id);
      if (!mounted) return;
      final current = StoreScope.of(context).boxById(box.id);
      if (current != null &&
          current.physicalMarkStatus == PhysicalMarkStatus.pending) {
        await showPhysicalMarkReminder(context, current);
      }
    }
  }

  Future<void> _photoEntry({required bool camera}) async {
    final store = StoreScope.of(context);
    final existingBatch = store.activeEntryBatchForProject(widget.projectId);
    if (existingBatch != null) {
      await _openBatchEditor(existingBatch.id);
      return;
    }
    if (camera) {
      final batch = await store.createEntryBatch(
        projectId: widget.projectId,
        source: EntryBatchSource.camera,
      );
      if (!mounted) return;
      final result = await Navigator.push<BatchEditorResult>(
        context,
        MaterialPageRoute<BatchEditorResult>(
          builder: (_) => BatchCaptureScreen(
            projectId: widget.projectId,
            batchId: batch.id,
          ),
        ),
      );
      if (mounted) await _handleBatchResult(result);
      return;
    }
    setState(() => _busy = true);
    final created = <BoxRecord>[];
    late final EntryBatch batch;
    try {
      final selected = await _photos.choosePhotos(limit: 30);
      if (selected.isEmpty) return;
      batch = await store.createEntryBatch(
        projectId: widget.projectId,
        source: EntryBatchSource.gallery,
      );
      for (final source in selected) {
        String? persistedPath;
        try {
          persistedPath = await _photos.persist(source);
          final box = await store.createBox(
            projectId: widget.projectId,
            photoPaths: [persistedPath],
            entryBatchId: batch.id,
          );
          created.add(box);
        } catch (_) {
          if (persistedPath != null) {
            await _photos.deleteIfManaged(persistedPath);
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.photoFailed)));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (created.isEmpty) {
      await store.discardEmptyEntryBatch(batch.id);
      return;
    }
    await _openBatchEditor(batch.id);
  }

  Future<void> _openBatchEditor(String batchId) async {
    final result = await Navigator.push<BatchEditorResult>(
      context,
      MaterialPageRoute<BatchEditorResult>(
        builder: (_) => BatchEditorScreen(batchId: batchId),
      ),
    );
    if (mounted) await _handleBatchResult(result);
  }

  Future<void> _handleBatchResult(BatchEditorResult? result) async {
    if (result != BatchEditorResult.viewPending || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PendingMarksScreen(projectId: widget.projectId),
      ),
    );
  }

  Future<void> _scan() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MovingScanScreen(projectId: widget.projectId),
      ),
    );
  }

  Future<void> _exportLabels() async {
    final store = StoreScope.of(context);
    final boxes = store.boxesForProject(widget.projectId).reversed.toList();
    if (boxes.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await _exports.buildLabelPdf(
        store.projectById(widget.projectId),
        boxes,
        BoxLabelPdfLabels(
          documentTitle: context.l10n.labelDocumentTitle,
          brand: context.l10n.labelBrand,
          scanOrSearchCode: context.l10n.scanOrSearchCode,
        ),
      );
      final shared = await Printing.sharePdf(
        bytes: bytes,
        filename: 'KIFXPRO-labels.pdf',
      );
      if (shared) {
        await store.markLabelExported(boxes.map((box) => box.id));
      }
      if (mounted && shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.labelExportedNotice)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv(MovingProject project) async {
    final bytes = _exports.buildCsv(
      project,
      StoreScope.of(context).boxesForProject(project.id).reversed.toList(),
    );
    final renderBox = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv')],
        fileNameOverrides: ['${project.boxPrefix}-boxes.csv'],
        sharePositionOrigin: renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size,
      ),
    );
  }

  Future<void> _exportReport(MovingProject project) async {
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final generatedAt =
        '${material.formatFullDate(now)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(now))}';
    setState(() => _busy = true);
    try {
      final bytes = await _exports.buildProjectReportPdf(
        project: project,
        boxes: StoreScope.of(context).boxesForProject(project.id),
        labels: ProjectReportLabels(
          title: context.l10n.projectReport,
          generatedAt: context.l10n.reportGeneratedAt(generatedAt),
          total: context.l10n.total,
          suspectedMissing: context.l10n.suspectedMissing,
          damaged: context.l10n.reportDamaged,
          notUnpacked: context.l10n.notUnpacked,
          roomDistribution: context.l10n.roomDistribution,
          none: context.l10n.reportNone,
          unassignedRoom: context.l10n.unassignedRoom,
          moreRooms: context.l10n.moreRooms,
        ),
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${project.boxPrefix}-project-report.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.exportFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _projectAction(
    _ProjectAction action,
    MovingProject project,
  ) async {
    final store = StoreScope.of(context);
    switch (action) {
      case _ProjectAction.edit:
        await showProjectFormDialog(context, project: project);
      case _ProjectAction.csv:
        await _exportCsv(project);
      case _ProjectAction.report:
        await _exportReport(project);
      case _ProjectAction.archive:
        await store.setProjectArchived(project.id, true);
        if (mounted) Navigator.pop(context);
      case _ProjectAction.delete:
        final confirmed = await showIosConfirmation(
          context: context,
          title: context.l10n.delete,
          message: context.l10n.deleteProjectConfirm,
          cancelLabel: context.l10n.cancel,
          confirmLabel: context.l10n.delete,
          isDestructive: true,
        );
        if (!confirmed || !mounted) return;
        final paths = store
            .boxesForProject(project.id)
            .expand((box) => box.photoPaths)
            .toList();
        await store.deleteProject(project.id);
        for (final path in paths) {
          await _photos.deleteIfManaged(path);
        }
        if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showProjectActions(MovingProject project) async {
    final action = await showIosActionSheet<_ProjectAction>(
      context: context,
      cancelLabel: context.l10n.cancel,
      options: [
        IosActionSheetOption(
          label: context.l10n.editProject,
          value: _ProjectAction.edit,
        ),
        IosActionSheetOption(
          label: context.l10n.exportCsv,
          value: _ProjectAction.csv,
        ),
        IosActionSheetOption(
          label: context.l10n.projectReport,
          value: _ProjectAction.report,
        ),
        IosActionSheetOption(
          label: context.l10n.archive,
          value: _ProjectAction.archive,
        ),
        IosActionSheetOption(
          label: context.l10n.delete,
          value: _ProjectAction.delete,
          isDestructive: true,
        ),
      ],
    );
    if (action != null && mounted) await _projectAction(action, project);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final project = store.projectById(widget.projectId);
    final allMatchingBoxes = store.boxesForProject(
      widget.projectId,
      query: _query.text,
    );
    final boxes = _stageFilters.isEmpty
        ? allMatchingBoxes
        : allMatchingBoxes.where(_matchesSelectedStage).toList();
    final stats = store.statsFor(widget.projectId);
    final activeBatch = store.activeEntryBatchForProject(widget.projectId);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: context.l10n.movingScanMode,
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: context.l10n.moreActions,
            onPressed: _busy ? null : () => _showProjectActions(project),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : _QuickEntryDock(
              busy: _busy,
              onCamera: () => _photoEntry(camera: true),
              onGallery: () => _photoEntry(camera: false),
              onVoice: _voiceEntry,
              onManual: _manualEntry,
            ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          key: const Key('project-detail-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _ProgressSummary(
              stats: stats,
              onPendingMarks: stats.pendingMarks == 0
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PendingMarksScreen(projectId: project.id),
                      ),
                    ),
            ),
            if (activeBatch != null) ...[
              const SizedBox(height: 10),
              Material(
                key: const Key('project-resume-batch'),
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.pending_actions_outlined),
                  title: Text(context.l10n.resumeBatch),
                  subtitle: Text(
                    context.l10n.batchProgress(
                      activeBatch.safeNextIndex + 1,
                      activeBatch.boxIds.length,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openBatchEditor(activeBatch.id),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _StageFilterStrip(
              stats: stats,
              selected: _stageFilters,
              onToggle: (filter) => setState(() {
                _stageFilters.contains(filter)
                    ? _stageFilters.remove(filter)
                    : _stageFilters.add(filter);
              }),
              onClear: () => setState(_stageFilters.clear),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('project-box-search'),
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.l10n.searchBoxes,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _query.clear()),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            _BoxSectionHeader(
              count: boxes.length,
              busy: _busy,
              onExportLabels: _exportLabels,
            ),
            const SizedBox(height: 8),
            if (boxes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text(context.l10n.noResults)),
              )
            else
              _BoxGroup(
                boxes: boxes,
                onOpenBox: _openEditor,
                onOpenQr: (boxId) => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => QrLabelScreen(boxId: boxId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _matchesStage(BoxRecord box, _StageFilter filter) => switch (filter) {
  _StageFilter.waitingToLoad => box.moveStatus.index < MoveStatus.loaded.index,
  _StageFilter.notArrived => box.moveStatus.index < MoveStatus.arrived.index,
  _StageFilter.notUnpacked => box.moveStatus.index < MoveStatus.unpacked.index,
  _StageFilter.suspectedMissing => box.issues.contains(
    BoxIssue.suspectedMissing,
  ),
};

extension on _ProjectDetailScreenState {
  bool _matchesSelectedStage(BoxRecord box) =>
      _stageFilters.any((filter) => _matchesStage(box, filter));
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.stats, required this.onPendingMarks});

  final ProjectStats stats;
  final VoidCallback? onPendingMarks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('project-progress-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.progress,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                context.l10n.boxCount(stats.total),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (stats.pendingMarks > 0) ...[
            const SizedBox(height: 10),
            Material(
              color: colors.errorContainer.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPendingMarks,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        color: colors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${context.l10n.pendingPhysicalMark}  ${stats.pendingMarks}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageFilterStrip extends StatelessWidget {
  const _StageFilterStrip({
    required this.stats,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final ProjectStats stats;
  final Set<_StageFilter> selected;
  final ValueChanged<_StageFilter> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textStyle = theme.textTheme.labelSmall ?? const TextStyle();
    final metrics = <(_StageFilter, String, int, IconData)>[
      (
        _StageFilter.waitingToLoad,
        context.l10n.waitingToLoad,
        stats.waitingToLoad,
        Icons.inventory_2_outlined,
      ),
      (
        _StageFilter.notArrived,
        context.l10n.notArrived,
        stats.notArrived,
        Icons.local_shipping_outlined,
      ),
      (
        _StageFilter.notUnpacked,
        context.l10n.notUnpacked,
        stats.notUnpacked,
        Icons.unarchive_outlined,
      ),
      (
        _StageFilter.suspectedMissing,
        context.l10n.suspectedMissing,
        stats.suspectedMissing,
        Icons.warning_amber,
      ),
    ];
    return Column(
      key: const Key('project-stage-filters'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final minimumWidths = metrics.map((metric) {
              final painter = TextPainter(
                text: TextSpan(
                  text: '${metric.$2} ${metric.$3}',
                  style: textStyle,
                ),
                textDirection: Directionality.of(context),
                textScaler: textScaler,
                locale: Localizations.localeOf(context),
                maxLines: 1,
              )..layout();
              return painter.width + 16 + 4 + 12;
            }).toList();
            final minimumRowWidth =
                minimumWidths.fold<double>(0, (sum, width) => sum + width) +
                (metrics.length - 1) * 6;
            final useSingleRow = minimumRowWidth <= constraints.maxWidth;
            if (useSingleRow) {
              return Row(
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      flex: (minimumWidths[index] * 10).ceil(),
                      child: _StageFilterButton(
                        metric: metrics[index],
                        selected: selected.contains(metrics[index].$1),
                        onPressed: () => onToggle(metrics[index].$1),
                        allowLabelWrap: false,
                      ),
                    ),
                  ],
                ],
              );
            }
            final scale = textScaler.scale(12) / 12;
            return GridView.builder(
              itemCount: metrics.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 52 + (scale - 1).clamp(0, 1) * 24,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) => _StageFilterButton(
                metric: metrics[index],
                selected: selected.contains(metrics[index].$1),
                onPressed: () => onToggle(metrics[index].$1),
                allowLabelWrap: true,
              ),
            );
          },
        ),
        if (selected.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(context.l10n.clearFilters),
            ),
          ),
      ],
    );
  }
}

class _StageFilterButton extends StatelessWidget {
  const _StageFilterButton({
    required this.metric,
    required this.selected,
    required this.onPressed,
    required this.allowLabelWrap,
  });

  final (_StageFilter, String, int, IconData) metric;
  final bool selected;
  final VoidCallback onPressed;
  final bool allowLabelWrap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Material(
      key: Key('project-stage-filter-${metric.$1.name}'),
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(metric.$4, size: 16, color: colors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${metric.$2} ${metric.$3}',
                  maxLines: allowLabelWrap ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: allowLabelWrap,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickEntryDock extends StatelessWidget {
  const _QuickEntryDock({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onVoice,
    required this.onManual,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVoice;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        context.l10n.continuousCamera,
        Icons.camera_alt_outlined,
        onCamera,
        true,
      ),
      (
        context.l10n.choosePhotos,
        Icons.photo_library_outlined,
        onGallery,
        false,
      ),
      (context.l10n.voiceEntry, Icons.mic_none, onVoice, false),
      (context.l10n.manualEntry, Icons.edit_note, onManual, false),
    ];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final actionHeight = (80 + (textScale - 1).clamp(0, 1) * 32).toDouble();
    return Material(
      key: const Key('project-quick-entry-dock'),
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.quickEntry, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: actionHeight,
              child: Row(
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _QuickEntryAction(
                        label: entries[index].$1,
                        icon: entries[index].$2,
                        primary: entries[index].$4,
                        onPressed: busy ? null : entries[index].$3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEntryAction extends StatelessWidget {
  const _QuickEntryAction({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: primary ? colors.primaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colors.onSurface, size: 23),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoxSectionHeader extends StatelessWidget {
  const _BoxSectionHeader({
    required this.count,
    required this.busy,
    required this.onExportLabels,
  });

  final int count;
  final bool busy;
  final VoidCallback onExportLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.boxes,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(context.l10n.boxCount(count)),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('project-export-labels'),
            onPressed: busy ? null : onExportLabels,
            icon: const Icon(Icons.print_outlined, size: 20),
            label: Text(context.l10n.exportA4Pdf),
          ),
        ),
      ],
    );
  }
}

class _BoxGroup extends StatelessWidget {
  const _BoxGroup({
    required this.boxes,
    required this.onOpenBox,
    required this.onOpenQr,
  });

  final List<BoxRecord> boxes;
  final ValueChanged<String> onOpenBox;
  final ValueChanged<String> onOpenQr;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('project-box-group'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < boxes.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            _BoxRow(
              box: boxes[index],
              onTap: () => onOpenBox(boxes[index].id),
              onQr: () => onOpenQr(boxes[index].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({required this.box, required this.onTap, required this.onQr});

  final BoxRecord box;
  final VoidCallback onTap;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    final summary = [
      box.destinationRoom,
      box.memo,
    ].where((value) => value.isNotEmpty).join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 72,
                child: box.photoPaths.isEmpty
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.inventory_2_outlined, size: 30),
                      )
                    : Image.file(
                        File(box.photoPaths.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        box.shortCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _StatusBadge(box: box),
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (box.physicalMarkStatus == PhysicalMarkStatus.pending) ...[
                    const SizedBox(height: 5),
                    Text(
                      context.l10n.pendingPhysicalMark,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: context.l10n.qrAndPrint,
              onPressed: onQr,
              icon: const Icon(Icons.qr_code_2),
            ),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.box});

  final BoxRecord box;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        box.moveStatus.label(context),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

enum _ProjectAction { edit, csv, report, archive, delete }

enum _StageFilter { waitingToLoad, notArrived, notUnpacked, suspectedMissing }
