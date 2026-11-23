import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../app_controller.dart';
import '../models.dart';
import 'annotation_editor_screen.dart';
import 'app_theme.dart';
import 'create_flow_logic.dart';
import 'widgets/annotated_photo.dart';
import 'widgets/common.dart';

enum IssueEntryMode { quick, formal }

enum IssueFormResult { saved, savedAndAddAnother, savedAndOpenProject }

class IssueFormScreen extends StatefulWidget {
  const IssueFormScreen({
    required this.controller,
    required this.project,
    required this.sequence,
    this.existingIssues = const [],
    this.issue,
    this.entryMode = IssueEntryMode.quick,
    this.offerPostSaveActions = false,
    super.key,
  });

  final PhotoReportController controller;
  final ProjectRecord project;
  final int sequence;
  final List<IssueRecord> existingIssues;
  final IssueRecord? issue;
  final IssueEntryMode entryMode;
  final bool offerPostSaveActions;

  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final descriptionFocusNode = FocusNode();
  late final String issueId;
  late final TextEditingController roomController;
  late final TextEditingController locationController;
  late final TextEditingController categoryController;
  late final TextEditingController descriptionController;
  late final TextEditingController assigneeController;
  late IssueSeverity severity;
  late IssueStatus status;
  late DateTime? dueDate;
  late List<PhotoRecord> photos;
  final Set<String> newPaths = {};
  bool committed = false;
  bool saving = false;
  bool allowPop = false;
  late bool showAdvanced;
  late bool showOptionalDetails;
  late IssueEntryMode activeMode;

  String get issueCode =>
      widget.issue?.code ??
      '${widget.project.codePrefix}-${widget.sequence.toString().padLeft(3, '0')}';

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    issueId = issue?.id ?? const Uuid().v4();
    roomController = TextEditingController(text: issue?.room ?? '');
    locationController = TextEditingController(text: issue?.location ?? '');
    categoryController = TextEditingController(text: issue?.category ?? '');
    descriptionController = TextEditingController(
      text: issue?.description ?? '',
    );
    assigneeController = TextEditingController(text: issue?.assignee ?? '');
    severity = issue?.severity ?? IssueSeverity.unspecified;
    status = issue?.status ?? IssueStatus.unspecified;
    dueDate = issue?.dueDate;
    photos = [...?issue?.photos];
    activeMode = issue != null && hasFormalCoreFields(issue)
        ? IssueEntryMode.formal
        : widget.entryMode;
    showOptionalDetails =
        activeMode == IssueEntryMode.formal ||
        (issue != null && (issue.room.isNotEmpty || issue.location.isNotEmpty));
    showAdvanced =
        issue != null &&
        (issue.assignee.isNotEmpty ||
            issue.dueDate != null ||
            issue.severity != IssueSeverity.unspecified ||
            issue.status != IssueStatus.unspecified);
  }

  @override
  void dispose() {
    roomController.dispose();
    locationController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    assigneeController.dispose();
    descriptionFocusNode.dispose();
    if (!committed && newPaths.isNotEmpty) {
      unawaited(widget.controller.photoStorage.deletePaths(newPaths));
    }
    super.dispose();
  }

  Future<void> addPhoto(PhotoPhase phase) async {
    final source = await showAppActionSheet<ImageSource>(
      context: context,
      title: '添加现场照片',
      message: '选择拍摄新照片或从系统相册导入',
      actions: const [
        AppActionSheetAction(
          label: '现场拍照',
          value: ImageSource.camera,
          icon: Icons.camera_alt_outlined,
          isDefaultAction: true,
        ),
        AppActionSheetAction(
          label: '从相册选择',
          value: ImageSource.gallery,
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    if (source == null) return;
    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (picked == null) return;
      final imported = await widget.controller.photoStorage.importPhoto(
        picked.path,
      );
      newPaths.add(imported);
      if (!mounted) {
        await widget.controller.photoStorage.deletePaths([imported]);
        return;
      }
      setState(() {
        photos.add(
          PhotoRecord(
            id: const Uuid().v4(),
            issueId: issueId,
            path: imported,
            phase: phase,
            createdAt: DateTime.now(),
          ),
        );
      });
      if (activeMode == IssueEntryMode.quick) {
        descriptionFocusNode.requestFocus();
      }
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    }
  }

  Future<void> editAnnotations(int index) async {
    final result = await Navigator.push<List<PhotoAnnotation>>(
      context,
      MaterialPageRoute(
        builder: (context) => AnnotationEditorScreen(photo: photos[index]),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => photos[index] = photos[index].copyWith(annotations: result));
  }

  Future<void> removePhoto(int index) async {
    final removed = photos[index];
    setState(() => photos.removeAt(index));
    if (newPaths.remove(removed.path)) {
      await widget.controller.photoStorage.deletePaths([removed.path]);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    if (widget.issue == null && photos.isEmpty) {
      AppToast.show(context, tr('请至少添加一张现场照片'), style: AppToastStyle.error);
      return;
    }
    setState(() => saving = true);
    final now = DateTime.now();
    final original = widget.issue;
    final issue = IssueRecord(
      id: issueId,
      projectId: widget.project.id,
      sequence: original?.sequence ?? widget.sequence,
      code: issueCode,
      room: roomController.text.trim(),
      location: locationController.text.trim(),
      category: categoryController.text.trim().isEmpty
          ? quickRecordTitle(descriptionController.text)
          : categoryController.text.trim(),
      severity: severity,
      description: descriptionController.text.trim(),
      status: status,
      assignee: assigneeController.text.trim(),
      dueDate: dueDate,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
      photos: photos.map((photo) => photo.copyWith(issueId: issueId)).toList(),
    );
    try {
      await widget.controller.saveIssue(issue);
      committed = true;
      if (!mounted) return;
      setState(() {
        saving = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (widget.offerPostSaveActions && original == null) {
        final result = await showAppActionSheet<IssueFormResult>(
          context: context,
          title: '图文记录已保存',
          message: '接下来要做什么？',
          barrierDismissible: false,
          cancelLabel: '完成',
          cancelValue: IssueFormResult.saved,
          actions: const [
            AppActionSheetAction(
              label: '继续记录下一条',
              value: IssueFormResult.savedAndAddAnother,
              icon: Icons.add_a_photo_outlined,
              isDefaultAction: true,
            ),
            AppActionSheetAction(
              label: '查看项目记录',
              value: IssueFormResult.savedAndOpenProject,
              icon: Icons.folder_open_outlined,
            ),
          ],
        );
        if (mounted) Navigator.pop(context, result ?? IssueFormResult.saved);
      } else {
        Navigator.pop(context, IssueFormResult.saved);
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<IssueFormResult>(
      canPop: !saving && (committed || allowPop || widget.issue != null),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (saving) return;
        if (!_hasUnsavedDraft) {
          await _allowAndPop();
          return;
        }
        final discard = await confirmAction(
          context,
          title: '放弃这条记录？',
          message: '已添加的照片和填写内容不会保存。',
          confirmLabel: '放弃记录',
        );
        if (discard) await _allowAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: LText(
            widget.issue == null
                ? activeMode == IssueEntryMode.quick
                      ? '快速图文记录 $issueCode'
                      : '正式记录 $issueCode'
                : '编辑记录 $issueCode',
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : save,
              child: const LText(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.brand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LText(
                        issueCode,
                        translate: false,
                        style: TextStyle(
                          color: context.appColors.onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LText(
                        activeMode == IssueEntryMode.quick
                            ? '保存到“${widget.project.name}”；添加照片和说明即可。'
                            : '步骤 2/3：交代位置与内容，责任和进度按需补充。',
                        style: TextStyle(
                          color: context.appColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (activeMode == IssueEntryMode.quick) ..._buildQuickFields(),
              if (activeMode == IssueEntryMode.formal) ...[
                const SizedBox(height: 22),
                const SectionHeader(
                  title: '位置与内容',
                  subtitle: '用简短标题和说明把照片交代清楚。',
                ),
                const SizedBox(height: 14),
                ResponsiveFieldRow(
                  children: [
                    TextFormField(
                      controller: roomController,
                      decoration: InputDecoration(
                        labelText: tr('房间/区域 *'),
                        hintText: tr('主卫'),
                      ),
                      validator: _required,
                      textInputAction: TextInputAction.next,
                    ),
                    TextFormField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: tr('具体位置（可选）'),
                        hintText: tr('东侧墙面'),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                _ReuseChips(
                  label: '常用区域',
                  values: _uniqueSuggestions(
                    widget.existingIssues.map((issue) => issue.room),
                  ),
                  onSelected: (value) => roomController.text = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: tr('记录标题 *'),
                    hintText: tr('例如：墙面裂缝、设备位置、到货情况'),
                  ),
                  validator: _required,
                  textInputAction: TextInputAction.next,
                ),
                _ReuseChips(
                  label: '常用标题',
                  values: _uniqueSuggestions(
                    widget.existingIssues.map((issue) => issue.category),
                  ),
                  onSelected: (value) => categoryController.text = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: tr('照片说明 *'),
                    hintText: tr('说明现场情况、关注点或后续安排'),
                  ),
                  validator: _required,
                ),
                _ReuseChips(
                  label: '常用说明',
                  values: _uniqueSuggestions(
                    widget.existingIssues.map((issue) => issue.description),
                  ),
                  onSelected: (value) => descriptionController.text = value,
                ),
                const SizedBox(height: 18),
                Card(
                  child: SwitchListTile(
                    value: showAdvanced,
                    onChanged: (value) => setState(() => showAdvanced = value),
                    secondary: Icon(
                      Icons.tune_rounded,
                      color: context.appColors.brand,
                    ),
                    title: const LText(
                      '补充责任与进度',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const LText('可选：优先级、状态、负责人和期限'),
                  ),
                ),
                if (showAdvanced) ...[
                  const SizedBox(height: 14),
                  ResponsiveFieldRow(
                    children: [
                      DropdownButtonFormField<IssueSeverity>(
                        initialValue: severity,
                        dropdownColor: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        decoration: InputDecoration(labelText: tr('优先级')),
                        items: IssueSeverity.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: LText(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => severity = value!),
                      ),
                      DropdownButtonFormField<IssueStatus>(
                        initialValue: status,
                        dropdownColor: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        decoration: InputDecoration(labelText: tr('处理状态')),
                        items: IssueStatus.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: LText(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => status = value!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveFieldRow(
                    children: [
                      TextFormField(
                        controller: assigneeController,
                        decoration: InputDecoration(labelText: tr('负责人')),
                        textInputAction: TextInputAction.next,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showAppDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                            initialDate:
                                dueDate ??
                                DateTime.now().add(const Duration(days: 7)),
                            title: '选择处理期限',
                          );
                          if (picked != null) {
                            setState(() => dueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: tr('处理期限'),
                            suffixIcon: dueDate == null
                                ? const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                  )
                                : IconButton(
                                    tooltip: tr('清除期限'),
                                    onPressed: () =>
                                        setState(() => dueDate = null),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                          ),
                          child: LText(
                            dueDate == null
                                ? '未设置'
                                : DateFormat('yyyy-MM-dd').format(dueDate!),
                            translate: dueDate == null,
                            style: TextStyle(
                              color: dueDate == null
                                  ? context.appColors.muted
                                  : context.appColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _PhotoSection(
                  phase: PhotoPhase.before,
                  photos: photos,
                  onAdd: () => addPhoto(PhotoPhase.before),
                  onEdit: editAnnotations,
                  onRemove: removePhoto,
                ),
                const SizedBox(height: 20),
                _PhotoSection(
                  phase: PhotoPhase.after,
                  photos: photos,
                  onAdd: () => addPhoto(PhotoPhase.after),
                  onEdit: editAnnotations,
                  onRemove: removePhoto,
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.onBrand,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: LText(
              saving
                  ? '正在保存…'
                  : activeMode == IssueEntryMode.quick
                  ? '保存图文记录'
                  : '保存完整记录',
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasUnsavedDraft {
    if (widget.issue != null) return false;
    return photos.isNotEmpty ||
        roomController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty ||
        categoryController.text.trim().isNotEmpty ||
        descriptionController.text.trim().isNotEmpty ||
        assigneeController.text.trim().isNotEmpty ||
        dueDate != null ||
        severity != IssueSeverity.unspecified ||
        status != IssueStatus.unspecified;
  }

  Future<void> _allowAndPop() async {
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  List<Widget> _buildQuickFields() {
    return [
      const SizedBox(height: 22),
      _PhotoSection(
        phase: PhotoPhase.before,
        photos: photos,
        title: '现场照片',
        subtitle: '先拍下现场情况，可继续添加照片或标注重点。',
        onAdd: () => addPhoto(PhotoPhase.before),
        onEdit: editAnnotations,
        onRemove: removePhoto,
      ),
      const SizedBox(height: 22),
      const SectionHeader(title: '事情说明', subtitle: '用一句或几句话把照片中的事情交代清楚。'),
      const SizedBox(height: 12),
      TextFormField(
        controller: descriptionController,
        focusNode: descriptionFocusNode,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: tr('照片说明 *'),
          hintText: tr('例如：主卫天花板持续漏水，需要尽快检查上层管道。'),
          alignLabelWithHint: true,
        ),
        validator: _required,
      ),
      _ReuseChips(
        label: '常用说明',
        values: _uniqueSuggestions(
          widget.existingIssues.map((issue) => issue.description),
        ),
        onSelected: (value) => descriptionController.text = value,
      ),
      const SizedBox(height: 16),
      Card(
        child: ExpansionTile(
          initiallyExpanded: showOptionalDetails,
          onExpansionChanged: (value) => showOptionalDetails = value,
          leading: Icon(Icons.place_outlined, color: context.appColors.brand),
          title: const LText(
            '补充位置与标题（可选）',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const LText('不填写时会自动生成标题，并显示为“未分类”'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            ResponsiveFieldRow(
              children: [
                TextFormField(
                  controller: roomController,
                  decoration: InputDecoration(
                    labelText: tr('房间/区域'),
                    hintText: tr('主卫'),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: tr('具体位置'),
                    hintText: tr('东侧墙面'),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            _ReuseChips(
              label: '常用区域',
              values: _uniqueSuggestions(
                widget.existingIssues.map((issue) => issue.room),
              ),
              onSelected: (value) => roomController.text = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: tr('记录标题'),
                hintText: tr('留空时取说明第一行'),
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          activeMode = IssueEntryMode.formal;
          showOptionalDetails = true;
        }),
        icon: const Icon(Icons.fact_check_outlined),
        label: const LText('补充为完整记录'),
      ),
    ];
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? tr('此项必填') : null;
  }

  List<String> _uniqueSuggestions(Iterable<String> source) {
    return reusableIssueSuggestions(source);
  }
}

class _ReuseChips extends StatelessWidget {
  const _ReuseChips({
    required this.label,
    required this.values,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            LText(
              label,
              style: TextStyle(color: context.appColors.muted, fontSize: 12),
            ),
            const SizedBox(width: 8),
            for (final value in values) ...[
              ActionChip(
                label: LText(
                  value,
                  translate: false,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => onSelected(value),
              ),
              const SizedBox(width: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.phase,
    required this.photos,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    this.title,
    this.subtitle,
  });

  final PhotoPhase phase;
  final List<PhotoRecord> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final indexed = <(int, PhotoRecord)>[
      for (var index = 0; index < photos.length; index++)
        if (photos[index].phase == phase) (index, photos[index]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title ?? '${phase.label}照片',
          subtitle:
              subtitle ??
              (phase == PhotoPhase.before
                  ? '保留现场原貌，可添加红框、箭头和文字。'
                  : '关联后续情况，形成同一编号下的前后对比。'),
          trailing: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const LText('添加'),
          ),
        ),
        const SizedBox(height: 12),
        if (indexed.isEmpty)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 108,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appColors.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: context.appColors.brand,
                  ),
                  const SizedBox(height: 7),
                  LText(
                    '拍照或从相册导入',
                    style: TextStyle(color: context.appColors.muted),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: indexed.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, listIndex) {
                if (listIndex == indexed.length) {
                  return InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 88,
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appColors.line),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: context.appColors.brand,
                          ),
                          const SizedBox(height: 5),
                          LText(
                            '继续添加',
                            style: TextStyle(
                              color: context.appColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final (sourceIndex, photo) = indexed[listIndex];
                return SizedBox(
                  width: 176,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => onEdit(sourceIndex),
                            child: AnnotatedPhoto(
                              path: photo.path,
                              annotations: photo.annotations,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Semantics(
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onEdit(sourceIndex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.68),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: LText(
                                  photo.annotations.isEmpty
                                      ? '点击标注'
                                      : '${photo.annotations.length} 个标注',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton.filled(
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.62,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            tooltip: tr('移除照片'),
                            onPressed: () => onRemove(sourceIndex),
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
