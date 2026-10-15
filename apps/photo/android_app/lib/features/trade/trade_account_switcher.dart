import 'package:flutter/material.dart';

import '../../core/debug/debug_log_filter.dart';
import '../../core/localization/st_localizations.dart';

class TradeAccountEntry {
  const TradeAccountEntry({
    required this.id,
    required this.label,
    required this.platform,
    required this.balance,
    required this.currency,
    required this.status,
    required this.type,
  });

  factory TradeAccountEntry.fromMap(Map<String, dynamic> map) {
    final type = _typeFromMap(map);
    return TradeAccountEntry(
      id: _pickString(map, const ['account_id', 'id', 'accountId']) ?? '',
      label:
          _pickString(map, const ['account_type', 'accountType', 'name']) ??
          _labelForType(type),
      platform: _pickString(map, const ['platform']) ?? 'MT5',
      balance:
          _pickString(map, const ['balance', 'raw_balance', 'rawBalance']) ??
          '',
      currency: _pickString(map, const ['currency']) ?? '',
      status: _toInt(map['status']),
      type: type,
    );
  }

  final String id;
  final String label;
  final String platform;
  final String balance;
  final String currency;
  final int status;
  final int type;

  String get iconAsset => tradeAccountIconAssetForType(type);

  Map<String, dynamic> get switchPayload => {
    'account': {
      'id': int.tryParse(id) ?? id,
      'platform': platform,
      'balance': balance,
      'currency': currency,
      'status': status,
      'type': type,
    },
    'app_id': 1,
    'platform': 'mobile',
    'login_type': 0,
  };
}

String tradeAccountDisplayLabel({
  required int type,
  String rawLabel = '',
  required String Function(String key) text,
}) {
  final trimmed = rawLabel.trim();
  if (trimmed.isNotEmpty && !_shouldLocalizeTradeAccountLabel(trimmed, type)) {
    return trimmed;
  }
  return _localizedTradeAccountLabel(type, text);
}

void logTradeAccountSwitchDebug(String stage, Map<String, Object?> details) {
  if (!tradeAccountSwitchDiagnosticsEnabled()) return;
  debugPrint('[TradeAccountSwitch][$stage] $details');
}

Map<String, Object?> tradeAccountSwitchDebugSnapshot(
  Map<String, dynamic> rawAccount,
  TradeAccountEntry entry,
) {
  return {
    'selected_id': entry.id,
    'selected_label': entry.label,
    'parsed_type': entry.type,
    'raw_type_fields': {
      'type': rawAccount['type'],
      'account_type': rawAccount['account_type'],
      'accountType': rawAccount['accountType'],
      'account_type_num': rawAccount['account_type_num'],
      'account_type_code': rawAccount['account_type_code'],
      'transaction_account_type': rawAccount['transaction_account_type'],
    },
    'switch_payload': entry.switchPayload,
  };
}

Map<String, Object?> tradeAccountSwitchResponseDebugSnapshot(
  Map<String, dynamic> response,
) {
  final data = response['data'];
  final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
  return {
    'code': response['code'],
    'message': response['message'],
    'data_type': data.runtimeType.toString(),
    'data_keys': dataMap?.keys.toList(growable: false),
    'token': debugSecretFingerprint(dataMap?['token']),
    'refresh_token': debugSecretFingerprint(dataMap?['refresh_token']),
    'transaction_account':
        dataMap?['transaction_account'] ?? dataMap?['transactionAccount'],
    'transaction_account_type':
        dataMap?['transaction_account_type'] ??
        dataMap?['transactionAccountType'],
    'is_active': dataMap?['is_active'] ?? dataMap?['isActive'],
  };
}

Map<String, Object?> tradeAccountCurrentDebugSnapshot(
  Map<String, dynamic>? currentAccount,
) {
  if (currentAccount == null) return {'current': null};
  var data = currentAccount;
  final inner = currentAccount['data'];
  if (inner is Map) {
    data = Map<String, dynamic>.from(inner);
  }
  return {
    'current_id': data['id'] ?? data['account_id'] ?? data['accountId'],
    'current_type':
        data['type'] ??
        data['account_type_num'] ??
        data['account_type_code'] ??
        data['transaction_account_type'],
    'current_account_type_text':
        data['account_type'] ?? data['accountType'] ?? data['name'],
    'is_active': data['is_active'] ?? data['isActive'],
    'data_keys': data.keys.toList(growable: false),
  };
}

class TradeAccountSwitcherSheet extends StatefulWidget {
  const TradeAccountSwitcherSheet({
    super.key,
    required this.accounts,
    required this.currentAccountId,
    required this.onManage,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> accounts;
  final String currentAccountId;
  final VoidCallback onManage;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  State<TradeAccountSwitcherSheet> createState() =>
      _TradeAccountSwitcherSheetState();
}

class _TradeAccountSwitcherSheetState extends State<TradeAccountSwitcherSheet> {
  static const Map<String, String> _fallbackText = {
    'switch_account': '切换',
    'manage': '管理',
    'real_account': '真实账户',
    'simulation_account': '模拟账户',
    'trader_account': '交易员账户',
  };

  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = _fallbackText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    final token = ++_languageLoadToken;
    STLocalizations.ofContext(context).textMap(_fallbackText).then((text) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.accounts
        .map(TradeAccountEntry.fromMap)
        .toList(growable: false);
    return Container(
      key: const ValueKey('trade-account-switcher-sheet-shell'),
      constraints: const BoxConstraints.tightFor(height: 330),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              left: 15,
              top: 15,
              child: Text(
                _t('switch_account'),
                style: TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 8,
              child: TextButton(
                onPressed: widget.onManage,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _t('manage'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF00B57A),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              left: 15,
              right: 15,
              top: 40,
              bottom: 0,
              child: Padding(
                key: const ValueKey('trade-account-switcher-body'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected =
                          entry.id.isNotEmpty &&
                          entry.id == widget.currentAccountId;
                      return _TradeAccountSwitcherRow(
                        entry: entry,
                        label: _accountLabel(entry),
                        selected: selected,
                        onTap: () => widget.onSelect(widget.accounts[index]),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  String _accountLabel(TradeAccountEntry entry) {
    return tradeAccountDisplayLabel(
      type: entry.type,
      rawLabel: entry.label,
      text: _t,
    );
  }
}

class _TradeAccountSwitcherRow extends StatelessWidget {
  const _TradeAccountSwitcherRow({
    required this.entry,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TradeAccountEntry entry;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        key: ValueKey('trade-account-switcher-row-${entry.id}'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.id.isEmpty ? null : onTap,
          child: SizedBox(
            height: 63,
            child: Stack(
              children: [
                Positioned.fill(
                  left: 16,
                  right: 40,
                  child: Row(
                    children: [
                      Image.asset(entry.iconAsset, width: 24, height: 24),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? const Color(0xFF000000)
                                : const Color(0xFF9A9DA2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '(${entry.id})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: Color(0xFF9A9DA2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 22.5,
                  child: Image.asset(
                    selected
                        ? 'assets/images/st_mine_checked_sec.png'
                        : 'assets/images/st_mine_unchecked.png',
                    width: 18,
                    height: 18,
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

Map<String, dynamic>? tradeAccountStateFromSwitchResponse(
  Map<String, dynamic> response,
) {
  // iOS treats `/transaction/accounts/switch` as the trigger for
  // `requestGetUserInfo`, then the trade page waits for
  // `/transaction/accounts/current` before updating display/global account.
  // Keeping this helper as a no-op prevents callers from using switch response
  // data as a display fallback when `/current` is still stale.
  return null;
}

Map<String, dynamic>? resolveTradeAccountDisplayData({
  required Map<String, dynamic>? currentAccount,
  required List<Map<String, dynamic>> accounts,
  required String rememberedAccountId,
}) {
  // iOS `requestCurrentTransAccountWithCompletion` writes the current account
  // from `/transaction/accounts/current` into `STUserInfoManger`, then the
  // trade header renders that model. Do not fabricate a current account from
  // the account list when `/current` is stale or unavailable; that can display
  // a simulated account while the server still submits orders on another one.
  return currentAccount;
}

String tradeAccountIconAssetForType(int type) {
  return switch (type) {
    1 => 'assets/images/st_mine_simulate.png',
    3 => 'assets/images/st_mine_trans.png',
    _ => 'assets/images/st_mine_firm.png',
  };
}

String _labelForType(int type) {
  return switch (type) {
    1 => '模拟账户',
    3 => '交易员账户',
    _ => '真实账户',
  };
}

String _localizedTradeAccountLabel(int type, String Function(String key) text) {
  return switch (type) {
    1 => text('simulation_account'),
    3 => text('trader_account'),
    _ => text('real_account'),
  };
}

bool _shouldLocalizeTradeAccountLabel(String rawLabel, int type) {
  if (rawLabel.isEmpty) return true;
  if (int.tryParse(rawLabel) != null) return true;
  final normalized = rawLabel.toLowerCase();
  return switch (type) {
    1 =>
      rawLabel.contains('模拟') ||
      normalized.contains('demo') ||
      normalized.contains('simulation'),
    3 => rawLabel.contains('交易员') || normalized.contains('trader'),
    _ =>
      rawLabel.contains('真实') ||
      rawLabel.contains('实盘') ||
      normalized.contains('real') ||
      normalized.contains('live'),
  };
}

String? _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _typeFromMap(Map<String, dynamic> map) {
  final numeric =
      map['type'] ?? map['account_type_num'] ?? map['transaction_account_type'];
  final parsed = int.tryParse(numeric?.toString() ?? '');
  if (parsed != null) return parsed;
  final text =
      _pickString(map, const ['account_type', 'accountType', 'name']) ?? '';
  if (text.contains('模拟')) return 1;
  if (text.contains('交易员')) return 3;
  if (text.contains('体验金')) return 4;
  return 0;
}
