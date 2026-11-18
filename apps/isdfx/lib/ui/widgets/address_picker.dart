import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/fixture_engine.dart';

String _t(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

/// Owns a draft selection. The workbench is changed only by Confirm.
Future<String?> showAddressPicker(
  BuildContext context, {
  required RuleProfile profile,
  required String selectedCode,
}) => showCupertinoModalPopup<String>(
  context: context,
  builder: (_) => _AddressPicker(profile: profile, selectedCode: selectedCode),
);

class _AddressPicker extends StatefulWidget {
  const _AddressPicker({required this.profile, required this.selectedCode});
  final RuleProfile profile;
  final String selectedCode;

  @override
  State<_AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<_AddressPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _group;
  String? _parent;
  late String _draft;
  late bool _historical;

  bool get _vietnam => widget.profile.id == 'vn-id';
  bool get _taiwan => widget.profile.id == 'tw-id';
  bool get _hierarchical => widget.profile.id == 'cn-id' || _vietnam;
  List<AddressCode> get _codes => widget.profile.addressCodes;
  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String _name(AddressCode code) => _zh ? code.nameZh : code.nameEn;
  String _groupName(AddressCode code) =>
      _zh ? code.groupNameZh : code.groupNameEn;
  String _parentName(AddressCode code) =>
      _zh ? code.parentNameZh : code.parentNameEn;

  @override
  void initState() {
    super.initState();
    _draft = widget.selectedCode;
    _historical =
        _taiwan &&
        _codes.any((entry) => entry.code == _draft && !entry.current);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) {
    FocusScope.of(context).unfocus();
    setState(() {
      change();
      _search.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _matches(AddressCode entry, String query) =>
      '${entry.code} ${entry.nameZh} ${entry.nameEn} '
              '${entry.groupNameZh} ${entry.groupNameEn} '
              '${entry.parentNameZh} ${entry.parentNameEn}'
          .toLowerCase()
          .contains(query);

  List<Widget> _rows() {
    final query = _search.text.trim().toLowerCase();
    final pool = _taiwan
        ? _codes.where((entry) => entry.current != _historical).toList()
        : _codes;
    // Mainland search reaches a code directly. Vietnam retains the current
    // province group before showing the historical coding-area subset.
    if (!_hierarchical ||
        (!_vietnam && query.isNotEmpty) ||
        (_group != null && (_vietnam || _parent != null))) {
      final visible = pool.where((entry) {
        if (_hierarchical && (_vietnam || query.isEmpty)) {
          if (entry.groupCode != _group) return false;
          if (!_vietnam && entry.parentCode != _parent) return false;
        }
        return query.isEmpty || _matches(entry, query);
      });
      return [for (final entry in visible) _codeRow(entry)];
    }
    final grouped = <String, AddressCode>{};
    final direct = <AddressCode>[];
    for (final entry in pool) {
      if (_group != null && entry.groupCode != _group) continue;
      if (query.isNotEmpty && !_matches(entry, query)) continue;
      if (_group != null &&
          (entry.parentCode.isEmpty || entry.parentCode == _group)) {
        direct.add(entry);
      } else {
        grouped.putIfAbsent(
          _group == null ? entry.groupCode : entry.parentCode,
          () => entry,
        );
      }
    }
    return [
      for (final item in grouped.entries)
        _rowSurface(
          ListTile(
            key: ValueKey(
              'address.${_group == null ? 'group' : 'parent'}.${item.key}',
            ),
            title: Text(
              _group == null ? _groupName(item.value) : _parentName(item.value),
            ),
            subtitle: Text(item.key),
            trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
            onTap: () => _change(() {
              if (_group == null) {
                _group = item.key;
                if (!_codes.any(
                  (entry) => entry.code == _draft && entry.groupCode == _group,
                )) {
                  _draft = '';
                }
              } else {
                _parent = item.key;
                if (!_codes.any(
                  (entry) =>
                      entry.code == _draft && entry.parentCode == _parent,
                )) {
                  _draft = '';
                }
              }
            }),
          ),
        ),
      for (final entry in direct) _codeRow(entry),
    ];
  }

  String _codeDescription(AddressCode entry) {
    final parts = <String>[entry.code];
    if (widget.profile.id == 'cn-id') {
      parts.add(_groupName(entry));
      if (entry.parentCode != entry.groupCode && entry.parentCode.isNotEmpty) {
        parts.add(_parentName(entry));
      }
      if (entry.kind == 'prefecture_direct_reference') {
        parts.add(
          _t(
            context,
            '无县级区划的市级参考码；签发未知',
            'City reference without county divisions; issuance unknown',
          ),
        );
      } else if (entry.kind == 'official_reported_identity_prefix') {
        parts.add(
          _t(
            context,
            '公开报道的号码前缀；签发未知',
            'Publicly reported ID prefix; issuance unknown',
          ),
        );
      }
    }
    if (!entry.current) parts.add(_t(context, '历史编码', 'Historical code'));
    return parts.join(' · ');
  }

  Widget _codeRow(AddressCode entry) {
    final selected = _draft == entry.code;
    return _rowSurface(
      ListTile(
        key: ValueKey('address.code.${entry.code}'),
        title: Text(_name(entry)),
        subtitle: Text(_codeDescription(entry)),
        selected: selected,
        trailing: selected
            ? const Icon(CupertinoIcons.check_mark_circled_solid, size: 20)
            : null,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _draft = entry.code);
        },
      ),
      selected: selected,
    );
  }

  Widget _rowSurface(Widget row, {bool selected = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: .09),
                scheme.surface,
              )
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: .40)
                : scheme.outlineVariant.withValues(alpha: .56),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: row,
      ),
    );
  }

  void _refreshSearch() {
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _searchField(ColorScheme scheme) => TextField(
    key: const ValueKey('address.search'),
    controller: _search,
    autocorrect: false,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      labelText: _t(context, '搜索地名或代码', 'Search name or code'),
      filled: true,
      fillColor: scheme.surface,
      prefixIcon: const Icon(CupertinoIcons.search, size: 19),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              key: const ValueKey('address.search.clear'),
              tooltip: _t(context, '清除搜索', 'Clear search'),
              onPressed: () {
                _search.clear();
                _refreshSearch();
              },
              icon: const Icon(CupertinoIcons.clear_circled, size: 18),
            ),
    ),
    onChanged: (_) => _refreshSearch(),
    onSubmitted: (_) => FocusScope.of(context).unfocus(),
  );

  Widget _taiwanScope() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      ChoiceChip(
        key: const ValueKey('address.current'),
        label: Text(_t(context, '当前地区', 'Current areas')),
        selected: !_historical,
        onSelected: (_) => _change(() {
          _historical = false;
          if (!_codes.any((entry) => entry.code == _draft && entry.current)) {
            _draft = '';
          }
        }),
      ),
      ChoiceChip(
        key: const ValueKey('address.history'),
        label: Text(_t(context, '历史前缀', 'Historical prefixes')),
        selected: _historical,
        onSelected: (_) => _change(() {
          _historical = true;
          if (!_codes.any((entry) => entry.code == _draft && !entry.current)) {
            _draft = '';
          }
        }),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(0.0, size.height * .94 - inset);
    final compactHeading =
        size.width < 360 || MediaQuery.textScalerOf(context).scale(14) > 20;
    // On short windows the search shares the scroll area so it leaves space
    // for results above the keyboard. Keep its placement stable during typing.
    final pinSearch = size.height >= 620;
    final showSelection = inset == 0 && height >= 340;
    final searching = _search.text.trim().isNotEmpty;
    final selected = _codes.where((entry) => entry.code == _draft).firstOrNull;
    final group = _codes
        .where((entry) => entry.groupCode == _group)
        .firstOrNull;
    final parent = _codes
        .where(
          (entry) => entry.parentCode == _parent && entry.groupCode == _group,
        )
        .firstOrNull;
    final rows = _rows();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mainland = widget.profile.id == 'cn-id';
    final scopeHint = _vietnam
        ? _t(
            context,
            '从34个当前省级单位浏览，选择号码使用的公开历史编码。',
            'Browse the 34 current provinces to find the published historical code used in a number.',
          )
        : mainland
        ? _t(
            context,
            '按省、市、区县浏览，或直接搜索地名与代码。',
            'Browse province, city and county, or search a name or code.',
          )
        : null;
    final hierarchy = group == null
        ? null
        : parent == null
        ? _groupName(group)
        : '${_groupName(group)} / ${_parentName(parent)}';
    final title = Semantics(
      header: true,
      child: Text(
        _t(context, '选择编码地区', 'Choose a coding area'),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: inset),
      child: Material(
        key: const ValueKey('address.picker'),
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: math.min(size.width, 580),
          height: height,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                        child: Row(
                          children: [
                            if (group != null)
                              IconButton(
                                key: const ValueKey('address.back'),
                                tooltip: _t(context, '返回上一级', 'Back one level'),
                                onPressed: () => _change(() {
                                  if (_parent != null) {
                                    _parent = null;
                                  } else {
                                    _group = null;
                                  }
                                }),
                                icon: const Icon(CupertinoIcons.back, size: 20),
                              ),
                            if (compactHeading)
                              const Spacer()
                            else
                              Expanded(child: title),
                            TextButton(
                              key: const ValueKey('address.cancel'),
                              onPressed: () => Navigator.pop(context),
                              child: Text(_t(context, '取消', 'Cancel')),
                            ),
                          ],
                        ),
                      ),
                      if (pinSearch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                          child: _searchField(scheme),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListTileTheme(
                    data: ListTileThemeData(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 3,
                      ),
                      minTileHeight: 62,
                      horizontalTitleGap: 8,
                      selectedColor: scheme.primary,
                      iconColor: scheme.onSurfaceVariant,
                      titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: scheme.onSurface,
                      ),
                      subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    child: ListView(
                      key: const ValueKey('address.results'),
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      children: [
                        if (!pinSearch) ...[
                          _searchField(scheme),
                          const SizedBox(height: 10),
                        ],
                        if (compactHeading && !searching) ...[
                          title,
                          const SizedBox(height: 10),
                        ],
                        if (scopeHint != null && !searching) ...[
                          Text(
                            scopeHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (_taiwan) ...[
                          const SizedBox(height: 14),
                          _taiwanScope(),
                        ],
                        if (hierarchy != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                CupertinoIcons.location,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hierarchy,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              _t(context, '没有匹配的地区', 'No matching areas'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ...rows,
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      inset > 0
                          ? 10
                          : math.max(
                              14,
                              MediaQuery.viewPaddingOf(context).bottom,
                            ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selected != null && showSelection) ...[
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.check_mark_circled,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_name(selected)} · ${selected.code}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton(
                          key: const ValueKey('address.confirm'),
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(context, _draft),
                          child: Text(
                            _t(context, '确认选择', 'Confirm'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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
}
