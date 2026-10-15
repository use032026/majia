/// 钱包模型
class WalletModel {
  final double balance;
  final double frozenBalance;
  final String walletId;
  final String currency;
  final List<WalletTransactionModel> recentTransactions;

  /// 接口可能单独下发美元口径余额，用于与 iOS 总资产展示对齐
  final double? usdEquivalent;
  final String marginUsed;
  final String marginFree;
  final String equity;
  final String canDraw;
  final String lockedAmount;
  final String freezeAmount;
  final String upfrontBonusFrozen;
  final int status;
  final bool isEnable;

  WalletModel({
    required this.balance,
    this.frozenBalance = 0,
    this.walletId = '',
    this.currency = 'CNY',
    this.recentTransactions = const [],
    this.usdEquivalent,
    this.marginUsed = '0',
    this.marginFree = '',
    this.equity = '',
    this.canDraw = '',
    this.lockedAmount = '0',
    this.freezeAmount = '0',
    this.upfrontBonusFrozen = '0',
    this.status = 0,
    this.isEnable = false,
  });

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final rawUsd = _parseDouble(
      json['balance_usd'] ??
          json['usd_balance'] ??
          json['usd_equivalent'] ??
          json['quote_balance'] ??
          json['total_usd'],
    );
    final rawWalletId = '${json['wallet_id'] ?? json['id'] ?? ''}';
    final balance = _parseDouble(json['balance']) ?? 0;
    final marginUsed = _stringFrom(json, const ['margin_used', 'marginUsed']);
    final marginFree = _stringFrom(json, const [
      'margin_free',
      'marginFree',
    ], fallback: '$balance');
    final equity = _stringFrom(json, const ['equity'], fallback: '$balance');
    return WalletModel(
      balance: balance,
      frozenBalance:
          _parseDouble(json['frozen_balance'] ?? json['freeze_amount']) ?? 0,
      walletId: rawWalletId,
      currency: (json['currency'] ?? 'CNY').toString(),
      recentTransactions: (json['recent_transactions'] as List<dynamic>? ?? [])
          .map(
            (e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      usdEquivalent: rawUsd,
      marginUsed: marginUsed,
      marginFree: marginFree,
      equity: equity,
      canDraw: _stringFrom(json, const [
        'can_draw',
        'canDraw',
      ], fallback: marginFree),
      lockedAmount: _stringFrom(json, const ['locked_amount', 'lockedAmount']),
      freezeAmount: _stringFrom(json, const ['freeze_amount', 'freezeAmount']),
      upfrontBonusFrozen: _stringFrom(json, const [
        'upfront_bonus_fronten',
        'upfront_bonus_frozen',
        'upfront_bonus_frozen_amount',
        'upfront_bonus',
      ]),
      status: int.tryParse('${json['status'] ?? 0}') ?? 0,
      isEnable:
          json['is_enable'] == true ||
          json['isEnable'] == true ||
          json['is_enable']?.toString() == '1' ||
          json['isEnable']?.toString() == '1',
    );
  }

  static String _stringFrom(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '0',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// 用于「我的」总资产：`usdEquivalent` 优先；否则对 USD/USDT 钱包累加 `balance`
  static String summarizeTotalUsdLine(List<WalletModel> wallets) {
    double sumExplicit = 0;
    var hasExplicit = false;
    double sumUsdTicker = 0;
    for (final w in wallets) {
      if (w.usdEquivalent != null && w.usdEquivalent!.abs() > 1e-12) {
        sumExplicit += w.usdEquivalent!;
        hasExplicit = true;
        continue;
      }
      final ccy = w.currency.trim().toUpperCase();
      if (ccy == 'USD' ||
          ccy == 'USDT' ||
          ccy == 'UST' ||
          ccy == 'DUSD' ||
          ccy == 'TUSD') {
        sumUsdTicker += w.balance;
      }
    }
    if (hasExplicit) {
      return sumExplicit.toStringAsFixed(2);
    }
    if (sumUsdTicker.abs() > 1e-12) {
      return sumUsdTicker.toStringAsFixed(2);
    }
    if (wallets.isEmpty) return '';
    return wallets.first.balance.toStringAsFixed(2);
  }
}

/// 钱包流水模型
class WalletTransactionModel {
  final String id;
  final String type; // 'deposit', 'withdraw', 'transfer_in', 'transfer_out'
  final double amount;
  final String? remark;
  final DateTime? createdAt;
  final String status; // 'success', 'pending', 'failed'

  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.remark,
    this.createdAt,
    this.status = 'success',
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      remark: json['remark'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      status: json['status'] ?? 'success',
    );
  }
}
