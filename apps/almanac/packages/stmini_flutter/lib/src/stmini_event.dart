/// The pinned main runtime's `{name, payload}` event contract.
class StminiEvent {
  StminiEvent({required this.name, required Map<String, dynamic> payload})
    : payload = _freezeMap(payload);

  factory StminiEvent.fromMap(Map<String, dynamic> value) {
    final name = value['name'];
    final payload = value['payload'];
    if (name is! String || name.isEmpty || payload is! Map) {
      throw const FormatException('Invalid STMini event.');
    }
    return StminiEvent(name: name, payload: _freezeMap(payload));
  }

  final String name;
  final Map<String, dynamic> payload;

  static Map<String, dynamic> _freezeMap(Map value) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid STMini event keys.');
    }
    return Map<String, dynamic>.unmodifiable(
      value.map((key, value) => MapEntry(key as String, _freeze(value))),
    );
  }

  static dynamic _freeze(dynamic value) {
    if (value is Map) return _freezeMap(value);
    if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw const FormatException('Invalid STMini event value.');
  }
}
