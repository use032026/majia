/// 电子钱包列表项（对齐 iOS eWallet cell；status 0 / 1 / 2）
class EWalletItemModel {
  final String id;
  final String currency;
  final String displayName;
  final String addressRaw;
  final String? network;
  final bool isDefault;
  final int status;
  final String? remark;

  const EWalletItemModel({
    required this.id,
    required this.currency,
    required this.displayName,
    required this.addressRaw,
    this.network,
    this.isDefault = false,
    this.status = 1,
    this.remark,
  });

  bool get isCertified => status == 1;

  EWalletItemModel copyWith({
    String? id,
    String? currency,
    String? displayName,
    String? addressRaw,
    String? network,
    bool? isDefault,
    int? status,
    String? remark,
  }) {
    return EWalletItemModel(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      displayName: displayName ?? this.displayName,
      addressRaw: addressRaw ?? this.addressRaw,
      network: network ?? this.network,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      remark: remark ?? this.remark,
    );
  }

  factory EWalletItemModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return const EWalletItemModel(
        id: '',
        currency: '',
        displayName: '',
        addressRaw: '',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    final rawId = json['id']?.toString();
    final addr =
        json['payment_address']?.toString() ??
        json['wallet_address']?.toString() ??
        json['address']?.toString() ??
        '';
    final currencyName =
        json['currency']?.toString() ??
        json['cryptocurrency_name']?.toString() ??
        json['name']?.toString() ??
        '';
    final rawName = json['name']?.toString() ?? '';
    final displayName = rawName.trim().isNotEmpty
        ? rawName
        : (currencyName.isNotEmpty ? currencyName : '电子钱包');
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

    return EWalletItemModel(
      id: rawId?.toString() ?? '',
      currency: currencyName,
      displayName: displayName,
      addressRaw: addr,
      network: json['network']?.toString(),
      isDefault: def,
      status: status.clamp(0, 2),
      remark:
          json['remark']?.toString() ??
          json['reject_reason']?.toString() ??
          json['fail_reason']?.toString(),
    );
  }

  String get maskedAddress {
    final address = addressRaw;
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  String get currencyTitle {
    final currencyText = currency.trim();
    final networkText = (network ?? '').trim();
    if (currencyText.isNotEmpty &&
        networkText.isNotEmpty &&
        currencyText.contains(networkText)) {
      return currencyText;
    }
    if (currencyText.isNotEmpty && networkText.isNotEmpty) {
      return '$currencyText-$networkText';
    }
    if (currencyText.isNotEmpty) {
      return currencyText;
    }
    return displayName;
  }
}
