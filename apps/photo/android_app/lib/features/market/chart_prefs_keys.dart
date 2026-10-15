/// 行情详情 K 线图表相关 SharedPreferences 键（与 [MarketDetailPage] / [ChartSettingsPage] 共用）
abstract final class MarketChartPrefKeys {
  MarketChartPrefKeys._();

  static const klinePeriod = 'st_market_detail_kline_period';
  static const mainIndicator = 'st_market_detail_main_indicator';
  static const subIndicator = 'st_market_detail_sub_indicator';
  static const chartStyle = 'st_market_detail_chart_style';
  static const showGrid = 'st_market_detail_show_grid';
  static const crosshair = 'st_market_detail_crosshair';
  static const maPeriods = 'st_market_detail_ma_periods';
  static const emaPeriods = 'st_market_detail_ema_periods';
  static const maAllPeriods = 'st_market_detail_ma_all_periods';
  static const emaAllPeriods = 'st_market_detail_ema_all_periods';
  static const maSelectedMask = 'st_market_detail_ma_selected_mask';
  static const emaSelectedMask = 'st_market_detail_ema_selected_mask';

  /// 副图 MACD：快线,慢线,信号 — 如 `12,26,9`
  static const macdParams = 'st_market_detail_macd_params';

  /// 副图 KDJ：周期,K平滑,D平滑 — 如 `9,3,3`
  static const kdjParams = 'st_market_detail_kdj_params';
  static const rsiParams = 'st_market_detail_rsi_params';
  static const dmiParams = 'st_market_detail_dmi_params';

  static const mainIndicatorIds = ['MA', 'EMA', 'BOLL'];
  static const subIndicatorIds = ['MACD', 'KDJ', 'RSI'];
}
