import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/data/file_gateway.dart';
import 'src/domain/filepeek_document.dart';

void main() => runApp(const FilePeekApp());

class FilePeekApp extends StatefulWidget {
  const FilePeekApp({super.key, this.gateway, this.initialDocument});

  final FileGateway? gateway;
  final FilePeekDocument? initialDocument;

  @override
  State<FilePeekApp> createState() => _FilePeekAppState();
}

class _FilePeekAppState extends State<FilePeekApp> with WidgetsBindingObserver {
  late BuildContext uiContext;
  late final FileGateway gateway = widget.gateway ?? SystemFileGateway();
  late bool zh =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';
  ThemeMode themeMode = ThemeMode.system;
  FilePeekDocument? document;
  List<JsonDifference>? differences;
  String? comparisonName;
  String? error;
  bool busy = false;
  int _epoch = 0;
  int _linePage = 0;
  int _csvPage = 0;
  bool _rawEditorOpen = false;
  bool _rawEditorDraftDirty = false;
  final searchController = TextEditingController();
  StreamSubscription<ImportedFile>? sharedSubscription;
  bool _checkingSharedFile = false;

  String t(String cn, String en) => zh ? cn : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    document = widget.initialDocument;
    sharedSubscription = gateway.sharedFiles.listen(
      _loadShared,
      onError: (Object e) => _showError(e),
    );
    unawaited(_loadInitialShared());
    unawaited(gateway.clearOldExports().catchError((Object _) {}));
  }

  Future<void> _loadInitialShared() async {
    if (_checkingSharedFile) return;
    _checkingSharedFile = true;
    final startedAt = _epoch;
    try {
      final file = await gateway.initialSharedFile();
      if (file != null) await _load(file, expectedEpoch: startedAt);
    } catch (e) {
      _showError(e);
    } finally {
      _checkingSharedFile = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadInitialShared());
  }

  void _loadShared(ImportedFile file) => unawaited(_load(file));

  String _errorText(Object e) {
    if (e is FilePeekException) {
      switch (e.code) {
        case FilePeekErrorCode.tooLarge:
          return t('文件超过 5 MiB 上限。', 'The file exceeds the 5 MiB limit.');
        case FilePeekErrorCode.invalidUtf8:
          return t('文件不是有效的 UTF-8 文本。', 'The file is not valid UTF-8 text.');
        case FilePeekErrorCode.binaryContent:
          return t(
            '文件包含不支持的二进制或控制字符。',
            'The file contains unsupported binary or control characters.',
          );
        case FilePeekErrorCode.tooManyLines:
          return t(
            '文件超过 10,000 行上限。',
            'The file exceeds the 10,000-line limit.',
          );
        case FilePeekErrorCode.tooManyColumns:
          return t('CSV 超过 200 列上限。', 'The CSV exceeds the 200-column limit.');
        case FilePeekErrorCode.unsupportedType:
          return t(
            '仅支持 JSON、CSV、TXT 和 LOG 文件。',
            'Only JSON, CSV, TXT and LOG files are supported.',
          );
        case FilePeekErrorCode.invalidOperation:
          return t(
            '当前文件状态不允许此操作。',
            'This action is unavailable for the current file.',
          );
        case FilePeekErrorCode.invalidComparison:
          return t('两份文件都必须是有效 JSON。', 'Both files must be valid JSON.');
        case FilePeekErrorCode.diffLimit:
          return t(
            '差异过多，超出本机比较上限。',
            'The comparison exceeds the local difference limit.',
          );
      }
    }
    return t(
      '操作失败。请重试或选择其他文件。',
      'The action failed. Retry or choose another file.',
    );
  }

  void _showError(Object e) {
    if (!mounted) return;
    setState(() => error = _errorText(e));
  }

  Future<bool> _allowDiscard(FilePeekDocument? current) async {
    if (current == null || (!current.isModified && !_rawEditorDraftDirty)) {
      return true;
    }
    final choice = await showDialog<bool>(
      context: uiContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('丢弃工作副本修改？', 'Discard working-copy changes?')),
        content: Text(
          t(
            '继续会丢弃当前修改。如果还需要这些内容，请先导出副本。',
            'Continuing will discard current changes. Export a copy first if you still need them.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('保留文件', 'Keep file')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('丢弃修改', 'Discard changes')),
          ),
        ],
      ),
    );
    return choice == true;
  }

  Future<void> _load(ImportedFile file, {int? expectedEpoch}) async {
    if (!mounted || (expectedEpoch != null && _epoch != expectedEpoch)) return;
    final startedAt = _epoch;
    final current = document;
    try {
      final next = FilePeekDocument.inspect(
        fileName: file.name,
        bytes: file.bytes,
      );
      if (!await _allowDiscard(current)) return;
      if (!mounted || _epoch != startedAt || !identical(document, current)) {
        return;
      }
      if (_rawEditorOpen) {
        Navigator.of(uiContext).popUntil((route) => route.isFirst);
      }
      setState(() {
        _epoch++;
        document = next;
        differences = null;
        comparisonName = null;
        error = null;
        searchController.clear();
        _linePage = 0;
        _csvPage = 0;
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _pickFile() async {
    if (busy) return;
    final startedAt = _epoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await gateway.pickFile();
      if (file != null) await _load(file, expectedEpoch: startedAt);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _compare() async {
    final current = document;
    if (current == null || busy) return;
    final startedAt = _epoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await gateway.pickFile();
      if (file == null) return;
      if (!mounted || _epoch != startedAt || !identical(document, current)) {
        return;
      }
      if (!file.name.toLowerCase().endsWith('.json')) {
        throw const FilePeekException(
          FilePeekErrorCode.invalidComparison,
          'Expected a JSON file.',
        );
      }
      final result = current.compareJson(file.bytes);
      if (!mounted || _epoch != startedAt || !identical(document, current)) {
        return;
      }
      setState(() {
        differences = result;
        comparisonName = file.name;
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _format() {
    try {
      setState(() {
        document!.formatJson();
        differences = null;
        comparisonName = null;
        error = null;
      });
    } catch (e) {
      _showError(e);
    }
  }

  void _undo() {
    setState(() {
      document?.undo();
      differences = null;
      comparisonName = null;
      error = null;
    });
  }

  Future<void> _editRaw() async {
    final current = document;
    if (current == null) return;
    final startedAt = _epoch;
    if (utf8.encode(current.workingText).length > 128 * 1024) {
      setState(
        () => error = t(
          '原文编辑限 128 KiB；可继续查看或导出较大文件。',
          'Raw editing is limited to 128 KiB; larger files can still be viewed or exported.',
        ),
      );
      return;
    }
    _rawEditorOpen = true;
    _rawEditorDraftDirty = false;
    final String? updated;
    try {
      updated = await Navigator.of(uiContext).push<String>(
        MaterialPageRoute(
          builder: (context) => _RawEditorPage(
            initialText: current.workingText,
            zh: zh,
            onDraftChanged: (dirty) => _rawEditorDraftDirty = dirty,
          ),
        ),
      );
    } finally {
      _rawEditorOpen = false;
      _rawEditorDraftDirty = false;
    }
    if (updated == null ||
        !mounted ||
        _epoch != startedAt ||
        !identical(document, current)) {
      return;
    }
    try {
      setState(() {
        current.replaceWorkingText(updated!);
        differences = null;
        comparisonName = null;
        error = null;
        _linePage = 0;
        _csvPage = 0;
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmReset() async {
    final current = document;
    final startedAt = _epoch;
    final yes = await showDialog<bool>(
      context: uiContext,
      builder: (context) => AlertDialog(
        title: Text(t('恢复原件', 'Restore original')),
        content: Text(
          t(
            '丢弃工作副本中的所有修改？原文件不会改变。',
            'Discard all working-copy changes? The original file is unchanged.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('恢复', 'Restore')),
          ),
        ],
      ),
    );
    if (yes == true &&
        mounted &&
        _epoch == startedAt &&
        identical(document, current)) {
      setState(() {
        document?.reset();
        differences = null;
        comparisonName = null;
        error = null;
      });
    }
  }

  Future<void> _editCsv(int row, int column, String currentValue) async {
    final current = document;
    final startedAt = _epoch;
    String value = currentValue;
    final submitted = await showDialog<bool>(
      context: uiContext,
      builder: (context) => AlertDialog(
        title: Text(t('编辑工作副本', 'Edit working copy')),
        content: TextFormField(
          initialValue: currentValue,
          maxLines: 4,
          maxLength: 4000,
          autofocus: true,
          decoration: InputDecoration(labelText: t('单元格内容', 'Cell value')),
          onChanged: (next) => value = next,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('应用修改', 'Apply edit')),
          ),
        ],
      ),
    );
    if (submitted != true ||
        !mounted ||
        _epoch != startedAt ||
        !identical(document, current)) {
      return;
    }
    try {
      setState(() {
        current!.editCsvCell(row, column, value);
        differences = null;
        error = null;
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _closeFile() async {
    final current = document;
    final startedAt = _epoch;
    if (!await _allowDiscard(current)) return;
    if (!mounted || _epoch != startedAt || !identical(document, current)) {
      return;
    }
    setState(() {
      _epoch++;
      document = null;
      differences = null;
      comparisonName = null;
      error = null;
      searchController.clear();
      _linePage = 0;
      _csvPage = 0;
    });
  }

  Rect _shareAnchor(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _exportCopy(BuildContext context) async {
    final current = document;
    if (current == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final base = current.fileName.replaceAll(
        RegExp(r'\.(json|csv|txt|log)$', caseSensitive: false),
        '',
      );
      final name = '${base}_checked.${current.kind.name}';
      await gateway.shareFile(
        name,
        current.exportBytes(),
        _shareAnchor(context),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportReport(BuildContext context) async {
    final current = document;
    if (current == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final report = current.buildReport(
        languageCode: zh ? 'zh' : 'en',
        filter: searchController.text,
        differences: differences,
      );
      await gateway.shareFile(
        'filepeek_report.txt',
        Uint8List.fromList(utf8.encode(report)),
        _shareAnchor(context),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sharedSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F6868),
        surface: const Color(0xFFF6F8F7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8F7),
    );
    final dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF69C6C1),
        brightness: Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'FilePeek',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: themeMode,
      locale: Locale(zh ? 'zh' : 'en'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (pageContext) {
          uiContext = pageContext;
          return Scaffold(
            appBar: AppBar(
              title: const Text('FilePeek'),
              actions: [
                IconButton(
                  tooltip: t('切换语言', 'Switch language'),
                  onPressed: () => setState(() => zh = !zh),
                  icon: const Icon(Icons.translate),
                ),
                PopupMenuButton<String>(
                  tooltip: t('更多', 'More'),
                  onSelected: (value) {
                    if (value == 'theme') {
                      setState(
                        () => themeMode = themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      );
                    }
                    if (value == 'reset') unawaited(_confirmReset());
                    if (value == 'clear') unawaited(_closeFile());
                    if (value == 'privacy') _showPrivacy();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'theme',
                      child: Text(t('切换明暗模式', 'Switch appearance')),
                    ),
                    if (document != null)
                      PopupMenuItem(
                        value: 'reset',
                        child: Text(t('恢复原件', 'Restore original')),
                      ),
                    if (document != null)
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(t('关闭文件', 'Close file')),
                      ),
                    PopupMenuItem(
                      value: 'privacy',
                      child: Text(t('隐私说明', 'Privacy note')),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: document == null ? _emptyScreen() : _workspace(),
            ),
            bottomNavigationBar: document == null
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (buttonContext) => FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _exportCopy(buttonContext),
                                icon: const Icon(Icons.ios_share),
                                label: Text(t('导出副本', 'Export copy')),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (buttonContext) => OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _exportReport(buttonContext),
                                icon: const Icon(Icons.description_outlined),
                                label: Text(t('检查报告', 'Report')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  void _showPrivacy() {
    showDialog<void>(
      context: uiContext,
      builder: (context) => AlertDialog(
        title: Text(t('隐私说明', 'Privacy note')),
        content: SingleChildScrollView(
          child: Text(
            t(
              '文件只在本机检查，不发送至开发者服务器。只有你主动导出时，处理副本或报告才交给系统分享目标。系统文件提供方及设备备份可能另有处理规则。临时导出文件会在下次启动时清理。',
              'Files are inspected on this device and are not sent to a developer server. A working copy or report reaches a share destination only when you export it. File providers and device backups may have their own handling. Temporary exports are cleared at the next launch.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('关闭', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _emptyScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rule_folder_outlined,
                size: 56,
                color: Theme.of(uiContext).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                t('文件快检', 'Inspect a file'),
                style: Theme.of(uiContext).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  '在手机上确认格式、定位问题并导出处理副本。原文件始终保留。',
                  'Check format, find issues and export a working copy on your phone. The original stays intact.',
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('JSON')),
                  Chip(label: Text('CSV')),
                  Chip(label: Text('TXT')),
                  Chip(label: Text('LOG')),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(t('打开文件', 'Open file')),
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  'UTF-8 · 单文件最多 5 MiB · 无账号与自动上传',
                  'UTF-8 · Up to 5 MiB per file · No account or automatic upload',
                ),
                style: Theme.of(uiContext).textTheme.bodySmall,
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: LinearProgressIndicator(),
                ),
              if (error != null) _errorCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      color: Theme.of(uiContext).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(uiContext).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(
                  color: Theme.of(uiContext).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: t('关闭', 'Close'),
              onPressed: () => setState(() => error = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _workspace() {
    final doc = document!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) _errorCard(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.fileName,
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                      style: Theme.of(uiContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: t('打开其他文件', 'Open another file'),
                    onPressed: busy ? null : _pickFile,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _tag(doc.kind.name.toUpperCase()),
                  _tag('UTF-8${doc.hasUtf8Bom ? ' BOM' : ''}'),
                  _tag('${doc.byteSize} B'),
                  _tag(
                    doc.isModified
                        ? t('副本已修改', 'Copy modified')
                        : t('原始状态', 'Original state'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        doc.isValid
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: doc.isValid
                            ? Colors.teal
                            : Theme.of(uiContext).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.isValid
                                  ? t('检查通过', 'Inspection passed')
                                  : t('发现格式问题', 'Format issue found'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            for (final issue in doc.diagnostics.take(3))
                              Text(_diagnosticText(issue)),
                            if (doc.diagnostics.length > 3)
                              TextButton(
                                onPressed: () => _showAllDiagnostics(doc),
                                child: Text(
                                  t(
                                    '查看全部 ${doc.diagnostics.length} 项',
                                    'View all ${doc.diagnostics.length} issues',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {
                  _linePage = 0;
                  _csvPage = 0;
                }),
                maxLength: 200,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  labelText: doc.kind == FileKind.csv
                      ? t('筛选表格', 'Filter table')
                      : t('搜索内容', 'Search content'),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t('清除搜索', 'Clear search'),
                          onPressed: () => setState(() {
                            searchController.clear();
                            _linePage = 0;
                            _csvPage = 0;
                          }),
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (doc.kind == FileKind.json)
                    ActionChip(
                      avatar: const Icon(Icons.format_align_left, size: 18),
                      label: Text(t('格式化 JSON', 'Format JSON')),
                      onPressed: doc.isValid && !busy ? _format : null,
                    ),
                  if (doc.kind == FileKind.json)
                    ActionChip(
                      avatar: const Icon(Icons.compare_arrows, size: 18),
                      label: Text(t('比较 JSON', 'Compare JSON')),
                      onPressed: doc.isValid && !busy ? _compare : null,
                    ),
                  if (doc.kind == FileKind.json || doc.kind == FileKind.csv)
                    ActionChip(
                      avatar: const Icon(Icons.edit_note, size: 18),
                      label: Text(t('编辑原文副本', 'Edit raw copy')),
                      onPressed: busy ? null : _editRaw,
                    ),
                  if (doc.canUndo)
                    ActionChip(
                      avatar: const Icon(Icons.undo, size: 18),
                      label: Text(t('撤销', 'Undo')),
                      onPressed: _undo,
                    ),
                  if (doc.isModified)
                    ActionChip(
                      avatar: const Icon(Icons.restore, size: 18),
                      label: Text(t('恢复原件', 'Restore original')),
                      onPressed: _confirmReset,
                    ),
                ],
              ),
              if (differences != null) _differenceCard(),
              const SizedBox(height: 12),
              Text(
                t('内容', 'Content'),
                style: Theme.of(
                  uiContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _contentCaption(doc),
                style: Theme.of(uiContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _contentView(doc),
            ],
          ),
        ),
      ],
    );
  }

  String _diagnosticText(Diagnostic issue) {
    final location = issue.line == null
        ? ''
        : ' (${issue.line}:${issue.column ?? 1})';
    if (!zh) return '${issue.message}$location';
    final message = switch (issue.code) {
      DiagnosticCode.invalidJson => 'JSON 格式错误',
      DiagnosticCode.csvUnexpectedQuote => 'CSV 未加引号的单元格中出现引号',
      DiagnosticCode.csvUnexpectedTextAfterQuote => 'CSV 引号结束后出现多余文本',
      DiagnosticCode.csvUnclosedQuote => 'CSV 引号未闭合',
      DiagnosticCode.csvMissingHeader => 'CSV 缺少表头',
      DiagnosticCode.csvEmptyHeader => 'CSV 表头含空列名',
      DiagnosticCode.csvDuplicateHeader => 'CSV 表头有重复列名',
      DiagnosticCode.csvColumnMismatch =>
        'CSV 列数不匹配：应有 ${issue.expectedColumns} 列，实际 ${issue.actualColumns} 列',
    };
    return '$message$location';
  }

  void _showAllDiagnostics(FilePeekDocument doc) {
    showDialog<void>(
      context: uiContext,
      builder: (context) => AlertDialog(
        title: Text(t('全部诊断', 'All diagnostics')),
        content: SizedBox(
          width: 500,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: doc.diagnostics.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.report_outlined),
              title: Text(_diagnosticText(doc.diagnostics[index])),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('关闭', 'Close')),
          ),
        ],
      ),
    );
  }

  String _contentCaption(FilePeekDocument doc) {
    if (doc.kind == FileKind.csv && doc.csvTable != null) {
      final table = doc.csvTable!;
      return t(
        '${table.rows.length} 行 · ${table.headers.length} 列 · 点击单元格编辑副本',
        '${table.rows.length} rows · ${table.headers.length} columns · Tap a cell to edit the copy',
      );
    }
    return t(
      '${doc.lines.length} 行 · 按行查看',
      '${doc.lines.length} lines · Line view',
    );
  }

  Widget _tag(String label) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);

  Widget _differenceCard() {
    final items = differences!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('对比：$comparisonName', 'Compared with: $comparisonName'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              items.isEmpty
                  ? t('结构和值相同', 'Structure and values match')
                  : t('${items.length} 处差异', '${items.length} differences'),
            ),
            for (final item in items.take(30))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  '${item.kind.name.toUpperCase()} ${item.path}\n${item.before ?? '∅'} → ${item.after ?? '∅'}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            if (items.length > 30)
              Text(
                t(
                  '这里只显示前 30 项；报告包含全部差异。',
                  'Showing 30 here; the report includes all differences.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageBar(int total, int pageSize, int page, ValueChanged<int> onPage) {
    final maxPage = (total - 1) ~/ pageSize;
    final first = page * pageSize + 1;
    final last = (first + pageSize - 1) > total ? total : first + pageSize - 1;
    return Row(
      children: [
        IconButton(
          tooltip: t('上一页', 'Previous page'),
          onPressed: page == 0 ? null : () => onPage(page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(t('$first–$last / 共 $total', '$first–$last of $total')),
        ),
        TextButton(
          onPressed: () => _jumpToPage(maxPage + 1, page, onPage),
          child: Text(t('跳转', 'Jump')),
        ),
        IconButton(
          tooltip: t('下一页', 'Next page'),
          onPressed: page == maxPage ? null : () => onPage(page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _jumpToPage(
    int count,
    int page,
    ValueChanged<int> onPage,
  ) async {
    int? requested = page + 1;
    final result = await showDialog<int>(
      context: uiContext,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(t('跳转页面', 'Jump to page')),
          content: TextFormField(
            initialValue: '${page + 1}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: t('页码（1–$count）', 'Page (1–$count)'),
            ),
            onChanged: (value) => update(() => requested = int.tryParse(value)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed:
                  requested != null && requested! >= 1 && requested! <= count
                  ? () => Navigator.pop(context, requested! - 1)
                  : null,
              child: Text(t('跳转', 'Jump')),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) onPage(result);
  }

  Widget _contentView(FilePeekDocument doc) {
    if (doc.kind == FileKind.csv && doc.csvTable != null) return _csvView(doc);
    final query = searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? doc.lines
        : doc.lines
              .where((line) => line.text.toLowerCase().contains(query))
              .toList();
    const pageSize = 200;
    final maxPage = visible.isEmpty ? 0 : (visible.length - 1) ~/ pageSize;
    final page = _linePage > maxPage ? maxPage : _linePage;
    final shown = visible.skip(page * pageSize).take(pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t('没有匹配内容', 'No matches')),
          ),
        if (maxPage > 0)
          _pageBar(
            visible.length,
            pageSize,
            page,
            (next) => setState(() => _linePage = next),
          ),
        Container(
          height: 420,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(uiContext).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final line = shown[index];
              Color? color;
              if (line.severity == LogSeverity.error) {
                color = Theme.of(uiContext).colorScheme.error;
              }
              if (line.severity == LogSeverity.warning) {
                color = Colors.orange.shade800;
              }
              if (line.severity == LogSeverity.info) color = Colors.teal;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${line.number}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Theme.of(uiContext).colorScheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        line.text.isEmpty ? ' ' : line.text,
                        style: TextStyle(fontFamily: 'monospace', color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _csvView(FilePeekDocument doc) {
    final table = doc.csvTable!;
    final query = searchController.text.trim();
    final indexed = <({int index, CsvRow row})>[
      for (var i = 0; i < table.rows.length; i++)
        if (query.isEmpty ||
            table.rows[i].cells.any(
              (cell) => cell.toLowerCase().contains(query.toLowerCase()),
            ))
          (index: i, row: table.rows[i]),
    ];
    var pageSize = 1200 ~/ (table.headers.length + 1);
    if (pageSize < 5) pageSize = 5;
    if (pageSize > 100) pageSize = 100;
    final maxPage = indexed.isEmpty ? 0 : (indexed.length - 1) ~/ pageSize;
    final page = _csvPage > maxPage ? maxPage : _csvPage;
    final shown = indexed.skip(page * pageSize).take(pageSize).toList();
    if (indexed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(t('没有匹配行', 'No matching rows')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxPage > 0)
          _pageBar(
            indexed.length,
            pageSize,
            page,
            (next) => setState(() => _csvPage = next),
          ),
        SizedBox(
          height: 420,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 84,
                columns: [
                  DataColumn(label: Text('#')),
                  for (final header in table.headers)
                    DataColumn(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(header, softWrap: true),
                      ),
                    ),
                ],
                rows: [
                  for (final item in shown)
                    DataRow(
                      cells: [
                        DataCell(Text('${item.row.sourceLine}')),
                        for (
                          var column = 0;
                          column < table.headers.length;
                          column++
                        )
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                item.row.cells[column],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: () => _editCsv(
                              item.index,
                              column,
                              item.row.cells[column],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RawEditorPage extends StatefulWidget {
  const _RawEditorPage({
    required this.initialText,
    required this.zh,
    required this.onDraftChanged,
  });
  final String initialText;
  final bool zh;
  final ValueChanged<bool> onDraftChanged;

  @override
  State<_RawEditorPage> createState() => _RawEditorPageState();
}

class _RawEditorPageState extends State<_RawEditorPage> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialText,
  );
  bool tooLarge = false;

  Future<void> _cancel() async {
    if (controller.text == widget.initialText) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('丢弃未应用的编辑？', 'Discard unapplied edits?')),
        content: Text(
          t(
            '原文草稿还没有应用到工作副本。',
            'The raw draft has not been applied to the working copy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('继续编辑', 'Keep editing')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('丢弃草稿', 'Discard draft')),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  String t(String cn, String en) => widget.zh ? cn : en;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: controller.text == widget.initialText,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_cancel());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('编辑原文副本', 'Edit raw copy')),
        leading: IconButton(
          tooltip: t('取消', 'Cancel'),
          icon: const Icon(Icons.close),
          onPressed: () => unawaited(_cancel()),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (utf8.encode(controller.text).length > 128 * 1024) {
                setState(() => tooLarge = true);
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: Text(t('应用修改', 'Apply edit')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                t(
                  '这里只修改工作副本。应用后会重新检查格式；导出副本才会生成文件。',
                  'This changes only the working copy. Format is checked again after applying; export to create a file.',
                ),
              ),
              if (tooLarge) ...[
                const SizedBox(height: 8),
                Text(
                  t('原文编辑最多 128 KiB。', 'Raw editing is limited to 128 KiB.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (text) {
                    widget.onDraftChanged(text != widget.initialText);
                    setState(() => tooLarge = false);
                  },
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  maxLength: 131072,
                  keyboardType: TextInputType.multiline,
                  smartQuotesType: SmartQuotesType.disabled,
                  smartDashesType: SmartDashesType.disabled,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: t('文件内容', 'File content'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
