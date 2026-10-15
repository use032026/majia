/// 用户信息模型
class UserModel {
  final String id;
  final String phone;
  final String? email;
  final String? nickname;
  final String? avatar;
  final String? realName;
  final bool isAuthenticated; // 是否实名
  final String? authStatus; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.phone,
    this.email,
    this.nickname,
    this.avatar,
    this.realName,
    this.isAuthenticated = false,
    this.authStatus,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      realName: json['real_name'],
      isAuthenticated: json['is_authenticated'] ?? false,
      authStatus: json['auth_status'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'nickname': nickname,
        'avatar': avatar,
        'real_name': realName,
        'is_authenticated': isAuthenticated,
        'auth_status': authStatus,
        'created_at': createdAt?.toIso8601String(),
      };
}
