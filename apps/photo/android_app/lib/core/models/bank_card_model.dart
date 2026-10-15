/// 银行卡模型（对齐 iOS STBankCardModel：status 0 待审 / 1 已通过 / 2 失败）
class BankCardModel {
  final String id;
  final String bankName;
  final String cardNumber; // 脱敏后的卡号
  final String cardHolder;
  final String? branch;
  final String? bankLogo;
  final bool isDefault;

  /// 审核状态：0 审核中，1 已认证，2 审核失败
  final int status;

  /// 账户币种（部分接口返回）
  final String? currency;

  /// 审核失败原因
  final String? remark;

  BankCardModel({
    required this.id,
    required this.bankName,
    required this.cardNumber,
    required this.cardHolder,
    this.branch,
    this.bankLogo,
    this.isDefault = false,
    this.status = 1,
    this.currency,
    this.remark,
  });

  bool get isCertified => status == 1;
  bool get isPendingReview => status == 0;
  bool get isRejected => status == 2;
  String get displayBankName => bankName;
  String get branchDisplay {
    final raw = branch?.trim() ?? '';
    return raw.isEmpty ? '' : '支行名称：$raw';
  }

  BankCardModel copyWith({
    String? id,
    String? bankName,
    String? cardNumber,
    String? cardHolder,
    String? branch,
    String? bankLogo,
    bool? isDefault,
    int? status,
    String? currency,
    String? remark,
  }) {
    return BankCardModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolder: cardHolder ?? this.cardHolder,
      branch: branch ?? this.branch,
      bankLogo: bankLogo ?? this.bankLogo,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      remark: remark ?? this.remark,
    );
  }

  String get maskedCardNumber {
    final raw = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (raw.length < 8) return cardNumber;
    return '${raw.substring(0, 4)} **** **** ${raw.substring(raw.length - 4)}';
  }

  factory BankCardModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['card_id'];
    final rawDefault = json['is_default'] ?? json['default'];
    final def =
        rawDefault == true ||
        rawDefault == 1 ||
        rawDefault == '1' ||
        rawDefault == 'true';

    final sid = json['status'];
    int status = 1;
    if (sid is int) {
      status = sid;
    } else if (sid is String) {
      status = int.tryParse(sid) ?? 1;
    }

    return BankCardModel(
      id: rawId?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      cardNumber: json['card_number']?.toString() ?? '',
      cardHolder:
          json['holder_name']?.toString() ??
          json['card_holder']?.toString() ??
          '',
      branch: json['branch_name']?.toString() ?? json['branch']?.toString(),
      bankLogo: json['bank_logo']?.toString(),
      isDefault: def,
      status: status.clamp(0, 2),
      currency: json['currency']?.toString(),
      remark:
          json['remark']?.toString() ??
          json['reject_reason']?.toString() ??
          json['fail_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bank_name': bankName,
    'card_number': cardNumber,
    'card_holder': cardHolder,
    'branch': branch,
    'bank_logo': bankLogo,
    'is_default': isDefault,
    'status': status,
    'currency': currency,
    'remark': remark,
  };
}
