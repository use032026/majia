/// 解析 iOS `requestRegisterConfig` 返回的动态注册配置
class RegisterFieldSpec {
  RegisterFieldSpec({
    required this.code,
    required this.visible,
    required this.required,
    required this.editable,
    this.options = const [],
  });

  final String code;
  final bool visible;
  final bool required;
  final bool editable;
  final List<String> options;
}

class RegisterUiState {
  RegisterUiState({
    this.mobileEnabled = true,
    this.emailEnabled = true,
    this.showPhoneTabFirst = true,
    this.showModeTabs = true,
    this.showGoogleOAuth = false,
    this.showAppleOAuth = false,
    this.phoneFields = const [],
    this.emailFields = const [],
    this.phoneSteps = const [],
    this.emailSteps = const [],
    this.thirdSteps = const [],
  });

  final bool mobileEnabled;
  final bool emailEnabled;
  final bool showPhoneTabFirst;
  final bool showModeTabs;
  final bool showGoogleOAuth;
  final bool showAppleOAuth;
  final List<RegisterFieldSpec> phoneFields;
  final List<RegisterFieldSpec> emailFields;
  final List<Map<String, dynamic>> phoneSteps;
  final List<Map<String, dynamic>> emailSteps;
  final List<Map<String, dynamic>> thirdSteps;

  List<Map<String, dynamic>> identityFieldsForPhone() =>
      _identityFieldsFromSteps(phoneSteps);

  List<Map<String, dynamic>> identityFieldsForEmail() =>
      _identityFieldsFromSteps(emailSteps);

  List<Map<String, dynamic>> identityFieldsForThird() =>
      _identityFieldsFromSteps(thirdSteps);

  bool get showThirdLogin => showGoogleOAuth || showAppleOAuth;

  bool fieldVisible(List<RegisterFieldSpec> fields, String code) {
    for (final f in fields) {
      if (f.code == code && f.visible) return true;
    }
    return false;
  }

  bool fieldRequired(List<RegisterFieldSpec> fields, String code) {
    for (final f in fields) {
      if (f.code == code && f.visible) return f.required;
    }
    return false;
  }

  bool fieldEditable(List<RegisterFieldSpec> fields, String code) {
    for (final f in fields) {
      if (f.code == code && f.visible) return f.editable;
    }
    return true;
  }

  RegisterFieldSpec? spec(List<RegisterFieldSpec> fields, String code) {
    for (final f in fields) {
      if (f.code == code && f.visible) return f;
    }
    return null;
  }
}

const _fieldOrder = [
  'country',
  'tel',
  'email',
  'code',
  'password',
  'confirm_password',
  'name',
  'id_type',
  'id_number',
];

RegisterUiState parseRegisterUiState({
  required List<dynamic> configs,
  required String countryKey,
  bool phoneFirstDefault = true,
}) {
  Map<String, dynamic>? current;
  for (final raw in configs) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if ('${m['scope']}' == 'GLOBAL') current = m;
  }
  for (final raw in configs) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if ('${m['scope']}' == countryKey) {
      current = m;
      break;
    }
  }

  var mobileEnabled = true;
  var emailEnabled = true;
  var showGoogle = false;
  var showApple = false;
  var phoneFields = <RegisterFieldSpec>[];
  var emailFields = <RegisterFieldSpec>[];
  var phoneSteps = <Map<String, dynamic>>[];
  var emailSteps = <Map<String, dynamic>>[];
  var thirdSteps = <Map<String, dynamic>>[];

  final entry = current?['entry'];
  if (entry is List) {
    for (final e in entry) {
      if (e is! Map) continue;
      final em = Map<String, dynamic>.from(e);
      final type = '${em['entry_type']}';
      final enabled = em['enabled'] == true || em['enabled'] == 1;
      final steps = em['steps'];
      if (type == 'EMAIL') {
        emailEnabled = enabled;
        if (steps is List) {
          emailSteps = _stepMaps(steps);
          emailFields = _fieldsFromSteps(steps);
        }
      } else if (type == 'MOBILE') {
        mobileEnabled = enabled;
        if (steps is List) {
          phoneSteps = _stepMaps(steps);
          phoneFields = _fieldsFromSteps(steps);
        }
      } else if (type == 'OAUTH') {
        if (enabled && steps is List) {
          thirdSteps = steps
              .whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
          final providers = em['providers'];
          if (providers is List) {
            for (final p in providers) {
              final ps = '$p'.toLowerCase();
              if (ps == 'google') showGoogle = true;
              if (ps == 'apple') showApple = true;
            }
          }
        }
      }
    }
  }

  final showTabs = mobileEnabled && emailEnabled;
  var phoneFirst = phoneFirstDefault;
  if (showTabs) {
    phoneFirst = phoneFirstDefault;
  } else if (emailEnabled) {
    phoneFirst = false;
  } else if (mobileEnabled) {
    phoneFirst = true;
  }

  return RegisterUiState(
    mobileEnabled: mobileEnabled,
    emailEnabled: emailEnabled,
    showPhoneTabFirst: phoneFirst,
    showModeTabs: showTabs,
    showGoogleOAuth: showGoogle,
    showAppleOAuth: showApple,
    phoneFields: phoneFields,
    emailFields: emailFields,
    phoneSteps: phoneSteps,
    emailSteps: emailSteps,
    thirdSteps: thirdSteps,
  );
}

List<Map<String, dynamic>> _stepMaps(List<dynamic> steps) {
  return steps
      .whereType<Map>()
      .map((s) => Map<String, dynamic>.from(s))
      .toList();
}

List<Map<String, dynamic>> _identityFieldsFromSteps(
  List<Map<String, dynamic>> steps,
) {
  for (final step in steps) {
    if ('${step['step_code']}' != 'IDENTITY') continue;
    final enabled = step['enabled'] == true || step['enabled'] == 1;
    if (!enabled) continue;
    final fields = step['fields'];
    if (fields is! List) return [];
    final visible = <Map<String, dynamic>>[];
    for (final f in fields) {
      if (f is! Map) continue;
      final m = Map<String, dynamic>.from(f);
      final v = m['visible'];
      if (v == true || v == 1) visible.add(m);
    }
    return visible;
  }
  return [];
}

List<RegisterFieldSpec> _fieldsFromSteps(List<dynamic> steps) {
  for (final step in steps) {
    if (step is! Map) continue;
    final sm = Map<String, dynamic>.from(step);
    if ('${sm['step_code']}' != 'BASIC') continue;
    final fields = sm['fields'];
    if (fields is! List) continue;
    return _sortFields(fields);
  }
  return [];
}

List<RegisterFieldSpec> _sortFields(List<dynamic> fields) {
  final visible = <Map<String, dynamic>>[];
  for (final f in fields) {
    if (f is! Map) continue;
    final m = Map<String, dynamic>.from(f);
    final v = m['visible'];
    if (v == true || v == 1) visible.add(m);
  }
  final sorted = <RegisterFieldSpec>[];
  for (final code in _fieldOrder) {
    for (final m in visible) {
      if ('${m['code']}' == code) {
        final opts = m['options'];
        sorted.add(
          RegisterFieldSpec(
            code: code,
            visible: true,
            required: m['required'] == true || m['required'] == 1,
            editable: m['editable'] != false && m['editable'] != 0,
            options: opts is List ? opts.map((e) => '$e').toList() : const [],
          ),
        );
        break;
      }
    }
  }
  return sorted;
}

/// 注册结果枚举（对齐 iOS `goResultWithResult:`）
enum RegisterOutcome { success, rejected, pending, inProgress }

RegisterOutcome? parseRegisterOutcome(String? result) {
  switch (result) {
    case 'SUCCESS':
      return RegisterOutcome.success;
    case 'REJECTED':
      return RegisterOutcome.rejected;
    case 'PENDING':
      return RegisterOutcome.pending;
    case 'IN_PROGRESS':
      return RegisterOutcome.inProgress;
    default:
      return null;
  }
}
