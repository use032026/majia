import '../../core/models/market_product_model.dart';

/// 自选推荐「换一批」逻辑，对齐 iOS `STOptionalEmptyView`。
///
/// - 首次展示：取推荐池前 [pageSize] 个（默认全选由调用方处理）
/// - 换一批：Commodities / Forex / Index / Crypto / Stock 各类最多 2 个，凑满 10 个
/// - 全部轮播完后清空已展示记录，重新开始
class OptionalRecommendBatch {
  static const int pageSize = 10;
  static const int perCategoryCap = 2;

  final List<MarketProductModel> _commodities = [];
  final List<MarketProductModel> _forex = [];
  final List<MarketProductModel> _index = [];
  final List<MarketProductModel> _crypto = [];
  final List<MarketProductModel> _stock = [];
  final Set<String> _shownSymbols = {};

  List<MarketProductModel> _visible = const [];

  List<MarketProductModel> get visible => _visible;

  int get poolTotal =>
      _commodities.length +
      _forex.length +
      _index.length +
      _crypto.length +
      _stock.length;

  bool get canChangeBatch => poolTotal > pageSize;

  /// 用完整推荐池初始化（对齐 iOS `handleOptionList:` + 首次 `collectionList`）
  void resetWithPool(List<MarketProductModel> pool) {
    _commodities.clear();
    _forex.clear();
    _index.clear();
    _crypto.clear();
    _stock.clear();
    _shownSymbols.clear();

    for (final p in pool) {
      _bucketFor(p).add(p);
    }

    final initial = <MarketProductModel>[];
    for (final p in pool) {
      if (initial.length >= pageSize) break;
      initial.add(p);
      _shownSymbols.add(p.symbol);
    }
    _visible = initial;
  }

  /// 换一批；若 [canChangeBatch] 为 false 则保持当前批次（对齐 iOS `nextBatch` 早退）
  List<MarketProductModel> changeBatch() {
    if (!canChangeBatch) return _visible;
    final next = _pickNextBatch(<MarketProductModel>[]);
    _visible = next;
    return next;
  }

  List<MarketProductModel> _pickNextBatch(List<MarketProductModel> partial) {
    final batch = List<MarketProductModel>.from(partial);

    void takeFrom(List<MarketProductModel> source) {
      var count = 0;
      for (final p in source) {
        if (count >= perCategoryCap) break;
        if (batch.length >= pageSize) break;
        if (_shownSymbols.contains(p.symbol)) continue;
        batch.add(p);
        _shownSymbols.add(p.symbol);
        count++;
      }
    }

    takeFrom(_commodities);
    takeFrom(_forex);
    takeFrom(_index);
    takeFrom(_crypto);
    takeFrom(_stock);

    if (batch.length < pageSize) {
      final remaining = poolTotal - _shownSymbols.length;
      if (remaining > 0) {
        return _pickNextBatch(batch);
      }
      _shownSymbols.clear();
      return batch;
    }
    return batch;
  }

  List<MarketProductModel> _bucketFor(MarketProductModel p) {
    final g = (p.symbolGroup ?? '').trim();
    if (g == 'Commodities') return _commodities;
    if (g == 'Forex') return _forex;
    if (g == 'Index') return _index;
    if (g == 'Crypto') return _crypto;
    if (g.endsWith('Stock')) return _stock;
    return _commodities;
  }
}
