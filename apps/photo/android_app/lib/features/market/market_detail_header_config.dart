/// 行情详情顶栏行为（对齐 iOS `STMarketDetailHeaderView` / 服务端下发开关）
///
/// **全局**：`ConfigDataManager.appConfigDic` / `h5_config` 中可配置是否展示「合约规格」入口。
/// **品种**：`get_symbol_detail` 拍平后的字段可单独覆盖（显隐优先于全局）。
///
/// 支持的键名（与常见蛇形/驼峰及嵌套结构兼容，按优先级扫描）：
///
/// * 全局 `show`：
///   - `market_detail_show_contract_spec`
///   - `show_contract_spec_button`
///   - `show_contract_spec_entrance`
///   - `contract_spec_button_visible`
///   - 嵌套对象 `market_detail` / `MarketDetail` / `GlobalConfig` 内的 `show_contract_spec`、`show_contract_specifications`
/// * 全局 `hide`（为真则隐藏，且不与品种显式 `show` 混用时优先判 hide）：
///   - `market_detail_hide_contract_spec`
/// * 品种级：
///   - `show_contract_spec` / `showContractSpec` / `show_contract_specifications`
///   - `contract_spec_visible` / `contractSpecVisible`
///   - `hide_contract_spec` / `hideContractSpec`（为真则隐藏）
abstract final class MarketDetailHeaderConfig {
  MarketDetailHeaderConfig._();

  /// 是否展示右上角「合约规格」按钮。
  static bool contractSpecButtonVisible({
    required Map<String, dynamic>? appConfigDic,
    required Map<String, dynamic>? h5Config,
    bool? symbolOverride,
  }) {
    if (symbolOverride != null) return symbolOverride;

    final globalHide = _globalContractSpecHidden(
      appConfigDic: appConfigDic,
      h5Config: h5Config,
    );
    if (globalHide == true) return false;

    final globalShow = _globalContractSpecShowFlag(
      appConfigDic: appConfigDic,
      h5Config: h5Config,
    );
    return globalShow ?? true;
  }

  /// 从品种详情 Map 解析是否覆盖全局；`null` 表示接口未下发，沿用全局。
  static bool? parseSymbolContractSpecOverride(Map<String, dynamic> m) {
    const hideKeys = [
      'hide_contract_spec',
      'hideContractSpec',
      'contract_spec_hidden',
      'contractSpecHidden',
    ];
    for (final k in hideKeys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      if (v != null && _truthy(v)) return false;
    }

    const showKeys = [
      'show_contract_spec',
      'showContractSpec',
      'show_contract_specifications',
      'contract_spec_visible',
      'contractSpecVisible',
    ];
    for (final k in showKeys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      if (v != null) return _truthy(v);
    }
    return null;
  }

  static bool? _globalContractSpecHidden({
    required Map<String, dynamic>? appConfigDic,
    required Map<String, dynamic>? h5Config,
  }) {
    const keys = [
      'market_detail_hide_contract_spec',
      'hide_contract_spec_entrance',
    ];
    final layers = <Map<String, dynamic>?>[
      appConfigDic,
      h5Config,
      _asStringKeyedMap(appConfigDic?['GlobalConfig']),
      _asStringKeyedMap(appConfigDic?['market_detail']),
      _asStringKeyedMap(appConfigDic?['MarketDetail']),
      _asStringKeyedMap(h5Config?['market_detail']),
    ];
    return _firstTruthyKey(layers, keys);
  }

  static bool? _globalContractSpecShowFlag({
    required Map<String, dynamic>? appConfigDic,
    required Map<String, dynamic>? h5Config,
  }) {
    const keys = [
      'market_detail_show_contract_spec',
      'show_contract_spec_button',
      'show_contract_spec_entrance',
      'contract_spec_button_visible',
    ];
    final nestedShowKeys = ['show_contract_spec', 'show_contract_specifications'];

    final layers = _configLayers(appConfigDic, h5Config);
    final direct = _firstBoolFromKeys(layers, keys);
    if (direct != null) return direct;

    for (final nestName in ['market_detail', 'MarketDetail', 'GlobalConfig']) {
      final nestedApp = _asStringKeyedMap(appConfigDic?[nestName]);
      final nestedH5 = _asStringKeyedMap(h5Config?[nestName]);
      final v = _firstBoolFromKeys(
        [nestedApp, nestedH5],
        nestedShowKeys,
      );
      if (v != null) return v;
    }
    return null;
  }

  static List<Map<String, dynamic>?> _configLayers(
    Map<String, dynamic>? appConfigDic,
    Map<String, dynamic>? h5Config,
  ) {
    return [
      appConfigDic,
      h5Config,
    ];
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }

  static bool? _firstBoolFromKeys(
    List<Map<String, dynamic>?> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      if (map == null) continue;
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = map[k];
        if (v != null) return _truthy(v);
      }
    }
    return null;
  }

  /// 任一键为真则返回 true（用于 hide 检测）
  static bool? _firstTruthyKey(
    List<Map<String, dynamic>?> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      if (map == null) continue;
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = map[k];
        if (v != null && _truthy(v)) return true;
      }
    }
    return null;
  }

  static bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s.isEmpty) return false;
      if (s == '1' || s == 'true' || s == 'yes' || s == 'on') return true;
      if (s == '0' || s == 'false' || s == 'no' || s == 'off') return false;
      final n = num.tryParse(s);
      if (n != null) return n != 0;
    }
    return false;
  }
}
