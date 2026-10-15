import 'dart:math' as math;

/// 分类行情 `get_symbols_data` 的 `limit` / 每页条数。
///
/// 与 iOS `STConfigDataManager.categoryMarketPageSize`、`STService` 列表兜底
/// `pageSize`（merged PRD §8.1.4 / supplement §1.11）默认 **20** 一致。
const int kCategoryMarketSymbolsPageDefault = 20;

/// 从接口 `data` 层解析服务端下发的页大小（若存在则后续请求沿用，对齐 iOS 读配置/回包）。
int? categoryMarketPageSizeFromServerMap(Map<String, dynamic> data) {
  for (final k in ['page_size', 'pageSize', 'limit', 'page_limit']) {
    final v = data[k];
    if (v is int && v > 0) return v;
    if (v is num && v.toInt() > 0) return v.toInt();
  }
  return null;
}

/// 列表接近底部时提前触发「加载更多」的距离（逻辑像素）。
/// 约 **两行**列表高度，贴近 iOS `MJRefreshAutoNormalFooter` 提前触发量。
double categoryMarketScrollPrefetchPx(double rowHeight) {
  return math.max(80.0, rowHeight * 2);
}
