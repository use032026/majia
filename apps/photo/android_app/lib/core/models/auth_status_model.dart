/// 实名认证状态模型
class AuthStatusModel {
  final String status; // 'none', 'pending', 'approved', 'rejected'
  final String? realName;
  final String? idNumber; // 脱敏
  final String? rejectReason;
  final String? submitTime;
  final String? reviewTime;
  final int? identityStatus;
  final bool? bankCardStatus;
  final bool? eWalletStatus;
  final bool? fundPasswordStatus;
  final bool? telBindStatus;
  final bool? emailBindStatus;

  const AuthStatusModel({
    required this.status,
    this.realName,
    this.idNumber,
    this.rejectReason,
    this.submitTime,
    this.reviewTime,
    this.identityStatus,
    this.bankCardStatus,
    this.eWalletStatus,
    this.fundPasswordStatus,
    this.telBindStatus,
    this.emailBindStatus,
  });

  bool get isApproved =>
      identityStatus != null ? identityStatus == 2 : status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get needsAuth => status == 'none' || status == 'rejected';

  factory AuthStatusModel.fromJson(Map<String, dynamic> json) {
    final identityStatus = _parseInt(
      json['identity_status'] ?? json['identityStatus'],
    );
    return AuthStatusModel(
      status:
          _statusFromIdentityStatus(identityStatus) ??
          json['status']?.toString() ??
          'none',
      realName: json['real_name'],
      idNumber: json['id_number'],
      rejectReason: json['reject_reason'],
      submitTime: json['submit_time']?.toString(),
      reviewTime: json['review_time']?.toString(),
      identityStatus: identityStatus,
      bankCardStatus: _parseApiBoolOrNull(
        json['bank_card_status'] ?? json['bankCardStatus'],
      ),
      eWalletStatus: _parseApiBoolOrNull(
        json['e_wallet_status'] ??
            json['wallet_binding_status'] ??
            json['eWalletStatus'] ??
            json['walletBindingStatus'],
      ),
      fundPasswordStatus: _parseApiBoolOrNull(
        json['funds_password_status'] ??
            json['fundPasswordStatus'] ??
            json['fundsPasswordStatus'],
      ),
      telBindStatus: _parseApiBoolOrNull(
        json['tel_bind_status'] ?? json['telBindStatus'],
      ),
      emailBindStatus: _parseApiBoolOrNull(
        json['email_bind_status'] ?? json['emailBindStatus'],
      ),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _statusFromIdentityStatus(int? value) {
    switch (value) {
      case 0:
        return 'none';
      case 1:
        return 'pending';
      case 2:
        return 'approved';
      case 3:
        return 'rejected';
      default:
        return null;
    }
  }

  static bool? _parseApiBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return null;
  }
}
