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
                (entry) => entry.code == _draft && entry.parentCode == _parent,
              )) {
                _draft = '';
              }
            }
          }),
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

  Widget _codeRow(AddressCode entry) => ListTile(
    key: ValueKey('address.code.${entry.code}'),
    title: Text(_name(entry)),
    subtitle: Text(_codeDescription(entry)),
    selected: _draft == entry.code,
    trailing: _draft == entry.code
        ? const Icon(CupertinoIcons.check_mark, size: 19)
        : null,
    onTap: () {
      FocusScope.of(context).unfocus();
      setState(() => _draft = entry.code);
    },
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: inset),
      child: Material(
        key: const ValueKey('address.picker'),
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: math.max(180, size.height * .94 - inset),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('address.back'),
                        onPressed: () {
                          if (_parent != null) {
                            _change(() => _parent = null);
                          } else if (_group != null) {
                            _change(() => _group = null);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(CupertinoIcons.back, size: 18),
                        label: Text(_t(context, '返回', 'Back')),
                      ),
                      TextButton(
                        key: const ValueKey('address.cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: Text(_t(context, '取消', 'Cancel')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('address.results'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          _t(context, '选择编码地区', 'Choose a coding area'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (widget.profile.id == 'cn-id')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Text(
                            _t(
                              context,
                              '按省、市、区县浏览，或直接搜索地名与代码。',
                              'Browse province, city and county, or search a code. Place names retain their official original text.',
                            ),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      if (_vietnam)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Text(
                            _t(
                              context,
                              '先按当前34个省级单位查找，再选择其公开历史编码地。导航分组不是号码中使用的历史编码。',
                              'Find one of the 34 current provinces, then choose its published historical coding area. The current navigation group is not the historical code encoded in the number.',
                            ),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      if (_taiwan)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                key: const ValueKey('address.current'),
                                label: Text(
                                  _t(context, '当前地区', 'Current areas'),
                                ),
                                selected: !_historical,
                                onSelected: (_) => _change(() {
                                  _historical = false;
                                  if (!_codes.any(
                                    (entry) =>
                                        entry.code == _draft && entry.current,
                                  )) {
                                    _draft = '';
                                  }
                                }),
                              ),
                              ChoiceChip(
                                key: const ValueKey('address.history'),
                                label: Text(
                                  _t(context, '历史前缀', 'Historical prefixes'),
                                ),
                                selected: _historical,
                                onSelected: (_) => _change(() {
                                  _historical = true;
                                  if (!_codes.any(
                                    (entry) =>
                                        entry.code == _draft && !entry.current,
                                  )) {
                                    _draft = '';
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                      if (group != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Text(
                            '${_groupName(group)}${parent == null ? '' : ' / ${_parentName(parent)}'}',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          key: const ValueKey('address.search'),
                          controller: _search,
                          autocorrect: false,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: _t(
                              context,
                              '搜索地名或代码',
                              'Search original name or code',
                            ),
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              size: 19,
                            ),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    key: const ValueKey('address.search.clear'),
                                    onPressed: () => setState(_search.clear),
                                    icon: const Icon(
                                      CupertinoIcons.clear_circled,
                                      size: 18,
                                    ),
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _t(context, '没有匹配的地区', 'No matching areas'),
                          ),
                        ),
                      ...rows,
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    math.max(16, MediaQuery.viewPaddingOf(context).bottom),
                  ),
                  child: FilledButton(
                    key: const ValueKey('address.confirm'),
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(context, _draft),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _t(
                          context,
                          selected == null
                              ? '请选择编码地区'
                              : '确认 · ${_name(selected)} · $_draft',
                          selected == null
                              ? 'Choose a coding area'
                              : 'Confirm · ${_name(selected)} · $_draft',
                        ),
                      ),
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
