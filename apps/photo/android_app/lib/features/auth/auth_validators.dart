/// 登录/注册表单校验（对齐 iOS `STLoginManager`）
class AuthValidatorMessages {
  const AuthValidatorMessages({
    required this.phoneRequired,
    required this.phoneInvalid,
    required this.phoneSizeInvalid,
    required this.passwordFormat,
    required this.passwordSpace,
    required this.idCard,
    required this.passport,
    required this.driverLicense,
  });

  factory AuthValidatorMessages.fromMap(Map<String, String> text) {
    return AuthValidatorMessages(
      phoneRequired: text['phone_number_input'] ?? '请输入手机号',
      phoneInvalid:
          text['phone_error'] ??
          text['phone_number_format_error'] ??
          '手机号格式不正确',
      phoneSizeInvalid: text['phone_size_error'] ?? '手机号长度不正确',
      passwordFormat: text['password_error_format_tips'] ?? '密码需为5-15位且包含字母和数字',
      passwordSpace: text['password_empty_error'] ?? '密码不能包含空格',
      idCard: text['id_card'] ?? '身份证',
      passport: text['passport'] ?? '护照',
      driverLicense: text['driver_license'] ?? '驾驶证',
    );
  }

  static const zhHans = AuthValidatorMessages(
    phoneRequired: '请输入手机号',
    phoneInvalid: '手机号格式不正确',
    phoneSizeInvalid: '手机号长度不正确',
    passwordFormat: '密码需为5-15位且包含字母和数字',
    passwordSpace: '密码不能包含空格',
    idCard: '身份证',
    passport: '护照',
    driverLicense: '驾驶证',
  );

  final String phoneRequired;
  final String phoneInvalid;
  final String phoneSizeInvalid;
  final String passwordFormat;
  final String passwordSpace;
  final String idCard;
  final String passport;
  final String driverLicense;
}

abstract final class AuthValidators {
  static final _emailRe = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static bool isEmailValid(String email) =>
      email.isNotEmpty && _emailRe.hasMatch(email);

  /// 返回错误文案；空字符串表示通过（对齐 `checkPhoneValid:areaCode:`）
  static String? phoneError(
    String phone,
    String areaCode, {
    AuthValidatorMessages messages = AuthValidatorMessages.zhHans,
  }) {
    final digits = phone.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) return messages.phoneRequired;
    final ac = areaCode.replaceAll('+', '');
    if (ac == '86') {
      if (!digits.startsWith('1')) return messages.phoneInvalid;
      if (digits.length != 11) return messages.phoneSizeInvalid;
    } else if (ac == '852' || ac == '853') {
      if (digits.length != 8) return messages.phoneSizeInvalid;
    } else if (ac == '81') {
      if (digits.length != 10 && digits.length != 11) {
        return messages.phoneSizeInvalid;
      }
    } else if (ac == '84' || ac == '60') {
      if (digits.length != 9 && digits.length != 10) {
        return messages.phoneSizeInvalid;
      }
    } else if (ac == '1') {
      if (digits.length != 10) return messages.phoneSizeInvalid;
    }
    return null;
  }

  static bool passwordLengthOk(String s) => s.length >= 5 && s.length <= 15;

  static bool containsLetter(String s) => RegExp(r'[A-Za-z]').hasMatch(s);

  static bool containsDigit(String s) => RegExp(r'\d').hasMatch(s);

  static bool containsSpace(String s) => s.contains(' ');

  /// 密码格式（对齐 iOS `nextAction` 校验）
  static String? passwordFormatError(
    String password, {
    AuthValidatorMessages messages = AuthValidatorMessages.zhHans,
  }) {
    if (!passwordLengthOk(password) ||
        !containsLetter(password) ||
        !containsDigit(password)) {
      return messages.passwordFormat;
    }
    if (containsSpace(password)) return messages.passwordSpace;
    return null;
  }

  static bool idCardValid({
    required String idcard,
    required String type,
    required String areaCode,
  }) {
    if (idcard.isEmpty || type.isEmpty || areaCode.isEmpty) return false;
    final ac = areaCode.replaceAll('+', '');
    if (type == 'ID_CARD') {
      if (ac == '86') {
        return RegExp(
          r'(^[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2]\d|3[0-1])\d{3}(\d|X|x)$)|(^[1-9]\d{5}\d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2]\d|3[0-1])\d{3}$)',
        ).hasMatch(idcard);
      }
      if (ac == '852') {
        return RegExp(
          r'^[A-Z]{1,2}[0-9]{6}(\([0-9A]\)|[0-9A])?$',
        ).hasMatch(idcard);
      }
      if (ac == '81' || ac == '84' || ac == '60') {
        return RegExp(r'^[0-9]{12}$').hasMatch(idcard);
      }
      if (ac == '853') {
        return RegExp(r'^[0-9]{7}[0-9A-Za-z]{1}$').hasMatch(idcard);
      }
      if (ac == '1') {
        return RegExp(
          r'^(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}$',
        ).hasMatch(idcard);
      }
      return true;
    }
    if (type == 'PASSPORT' && idcard.length > 16) return false;
    return true;
  }

  static String idTypeLabel(
    String code, {
    AuthValidatorMessages messages = AuthValidatorMessages.zhHans,
  }) {
    switch (code) {
      case 'ID_CARD':
        return messages.idCard;
      case 'PASSPORT':
        return messages.passport;
      case 'DRIVER_LICENSE':
        return messages.driverLicense;
      default:
        return code;
    }
  }

  static int defaultIdTypeIndex(List<String> options, String countryKey) {
    if (options.isEmpty) return 0;
    if (countryKey == 'CN') {
      final i = options.indexOf('ID_CARD');
      if (i >= 0) return i;
    }
    return 0;
  }
}
