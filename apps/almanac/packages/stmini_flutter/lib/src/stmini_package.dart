/// Validated local inventory metadata; no loading or rendering capability.
final class StminiPackage {
  const StminiPackage._({
    required this.miniId,
    required this.miniName,
    required this.version,
    required this.entry,
    required this.icon,
  });

  factory StminiPackage.fromMap(Map<Object?, Object?> value) {
    const fields = {'miniId', 'miniName', 'version', 'entry', 'icon'};
    if (value.length != fields.length ||
        value.keys.any((key) => !fields.contains(key)) ||
        value.values.any((item) => item is! String)) {
      throw const FormatException('Invalid local inventory fields.');
    }
    final id = value['miniId'] as String;
    final name = value['miniName'] as String;
    final version = value['version'] as String;
    final entry = value['entry'] as String;
    final icon = value['icon'] as String;
    if (id.isEmpty ||
        id.length > 64 ||
        !_fullMatch(RegExp(r'[a-z0-9][a-z0-9_-]*'), id) ||
        name.isEmpty ||
        name.length > 256 ||
        !_validVersion(version) ||
        !_validPath(entry) ||
        (icon.isNotEmpty && !_validPath(icon))) {
      throw const FormatException('Invalid local inventory metadata.');
    }
    return StminiPackage._(
      miniId: id,
      miniName: name,
      version: version,
      entry: entry,
      icon: icon,
    );
  }

  final String miniId;
  final String miniName;
  final String version;
  final String entry;
  final String icon;

  static bool _fullMatch(RegExp expression, String value) {
    final match = expression.matchAsPrefix(value);
    return match != null && match.end == value.length;
  }

  static bool _validVersion(String value) {
    if (value.isEmpty || value.length > 79) return false;
    final parts = value.split('.');
    return parts.length <= 8 &&
        parts.every(
          (part) =>
              part.isNotEmpty &&
              part.length <= 9 &&
              _fullMatch(RegExp(r'[0-9]+'), part),
        );
  }

  static bool _validPath(String value) {
    if (value.isEmpty ||
        value.length > 1024 ||
        value.codeUnits.any(
          (unit) => unit < 32 || (unit >= 127 && unit <= 159),
        ) ||
        value.contains(RegExp(r'[\\:?#%]'))) {
      return false;
    }
    final parts = value.split('/');
    return parts.length <= 16 &&
        parts.every(
          (part) =>
              part.isNotEmpty &&
              part.length <= 128 &&
              part != '.' &&
              part != '..',
        );
  }
}
