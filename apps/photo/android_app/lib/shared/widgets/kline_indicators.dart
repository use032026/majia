import 'dart:math';

/// K 线衍生指标计算（对齐常见 TA 定义；用于 Flutter 自绘 MACD/RSI/KDJ 等）
abstract final class KlineIndicators {
  KlineIndicators._();

  static List<double?> sma(List<double> src, int period) {
    if (period <= 0 || src.length < period) {
      return List<double?>.filled(src.length, null);
    }
    final out = List<double?>.filled(src.length, null);
    double sum = 0;
    for (var i = 0; i < src.length; i++) {
      sum += src[i];
      if (i >= period) sum -= src[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  static List<double?> ema(List<double> src, int period) {
    if (period <= 0 || src.isEmpty) return List<double?>.filled(src.length, null);
    final out = List<double?>.filled(src.length, null);
    final k = 2.0 / (period + 1);
    double? prev;
    for (var i = 0; i < src.length; i++) {
      if (prev == null) {
        if (i >= period - 1) {
          double s = 0;
          for (var j = 0; j < period; j++) {
            s += src[i - period + 1 + j];
          }
          prev = s / period;
          out[i] = prev;
        }
      } else {
        prev = (src[i] - prev) * k + prev;
        out[i] = prev;
      }
    }
    return out;
  }

  /// MACD(12,26,9)：DIF = EMA12 − EMA26，DEA = EMA9(DIF)，柱 = 2*(DIF−DEA)
  static MacdSeries macd(List<double> closes, {int fast = 12, int slow = 26, int signal = 9}) {
    final n = closes.length;
    if (n == 0) {
      return MacdSeries(dif: [], dea: [], hist: []);
    }
    final emaFast = ema(closes, fast);
    final emaSlow = ema(closes, slow);
    final dif = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final a = emaFast[i];
      final b = emaSlow[i];
      if (a != null && b != null) dif[i] = a - b;
    }
    final difDense = <double>[];
    for (var i = 0; i < n; i++) {
      if (dif[i] != null) difDense.add(dif[i]!);
    }
    final deaDense = ema(difDense, signal);
    final dea = List<double?>.filled(n, null);
    final hist = List<double?>.filled(n, null);
    var k = 0;
    for (var i = 0; i < n; i++) {
      final d = dif[i];
      if (d != null && k < deaDense.length) {
        final e = deaDense[k];
        if (e != null) {
          dea[i] = e;
          hist[i] = 2 * (d - e);
        }
        k++;
      }
    }
    return MacdSeries(dif: dif, dea: dea, hist: hist);
  }

  /// RSI(14)
  static List<double?> rsi(List<double> closes, {int period = 14}) {
    final n = closes.length;
    final out = List<double?>.filled(n, null);
    if (n <= period || period <= 0) return out;
    double gain = 0;
    double loss = 0;
    for (var i = 1; i <= period; i++) {
      final ch = closes[i] - closes[i - 1];
      if (ch >= 0) {
        gain += ch;
      } else {
        loss -= ch;
      }
    }
    var avgG = gain / period;
    var avgL = loss / period;
    for (var i = period; i < n; i++) {
      if (i > period) {
        final ch = closes[i] - closes[i - 1];
        final g = ch > 0 ? ch : 0.0;
        final l = ch < 0 ? -ch : 0.0;
        avgG = (avgG * (period - 1) + g) / period;
        avgL = (avgL * (period - 1) + l) / period;
      }
      final rs = avgL < 1e-12 ? 100.0 : avgG / avgL;
      out[i] = 100.0 - (100.0 / (1.0 + rs));
    }
    return out;
  }

  /// KDJ(9,3,3) 简化实现
  static KdjSeries kdj(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int period = 9,
    int kSmooth = 3,
    int dSmooth = 3,
  }) {
    final n = closes.length;
    final rsv = List<double?>.filled(n, null);
    for (var i = period - 1; i < n; i++) {
      var hh = -double.infinity;
      var ll = double.infinity;
      for (var j = i - period + 1; j <= i; j++) {
        hh = max(hh, highs[j]);
        ll = min(ll, lows[j]);
      }
      final c = closes[i];
      final span = hh - ll;
      rsv[i] = span.abs() < 1e-12 ? 50.0 : (c - ll) / span * 100.0;
    }
    final k = List<double?>.filled(n, null);
    final d = List<double?>.filled(n, null);
    final j = List<double?>.filled(n, null);
    double? kPrev;
    double? dPrev;
    for (var i = 0; i < n; i++) {
      final rv = rsv[i];
      if (rv == null) continue;
      kPrev = kPrev == null ? rv : (kPrev * (kSmooth - 1) + rv) / kSmooth;
      k[i] = kPrev;
      dPrev = dPrev == null ? kPrev : (dPrev * (dSmooth - 1) + kPrev) / dSmooth;
      d[i] = dPrev;
      j[i] = 3 * kPrev - 2 * dPrev;
    }
    return KdjSeries(k: k, d: d, j: j);
  }

  /// BOLL(20,2)
  static BollSeries boll(List<double> closes, {int period = 20, double k = 2}) {
    final mid = sma(closes, period);
    final n = closes.length;
    final upper = List<double?>.filled(n, null);
    final lower = List<double?>.filled(n, null);
    for (var i = period - 1; i < n; i++) {
      final m = mid[i];
      if (m == null) continue;
      double sum = 0;
      for (var j = i - period + 1; j <= i; j++) {
        final d = closes[j] - m;
        sum += d * d;
      }
      final sd = sqrt(sum / period);
      upper[i] = m + k * sd;
      lower[i] = m - k * sd;
    }
    return BollSeries(mid: mid, upper: upper, lower: lower);
  }

  /// +DI / -DI / ADX 简化（DMI 副图常用柱状展示方向净额）
  static List<double?> dmiNet(List<double> highs, List<double> lows, List<double> closes, {int period = 14}) {
    final n = closes.length;
    final out = List<double?>.filled(n, null);
    if (n < 2) return out;
    final tr = List<double>.filled(n, 0);
    final plusDm = List<double>.filled(n, 0);
    final minusDm = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      final upMove = highs[i] - highs[i - 1];
      final downMove = lows[i - 1] - lows[i];
      plusDm[i] = (upMove > downMove && upMove > 0) ? upMove : 0;
      minusDm[i] = (downMove > upMove && downMove > 0) ? downMove : 0;
      final hl = (highs[i] - lows[i]).abs();
      final hc = (highs[i] - closes[i - 1]).abs();
      final lc = (lows[i] - closes[i - 1]).abs();
      tr[i] = max(hl, max(hc, lc));
    }
    double atr = 0;
    double pDm = 0;
    double mDm = 0;
    for (var i = 1; i < n; i++) {
      atr = (atr * (period - 1) + tr[i]) / period;
      pDm = (pDm * (period - 1) + plusDm[i]) / period;
      mDm = (mDm * (period - 1) + minusDm[i]) / period;
      if (i >= period && atr > 1e-12) {
        final diPlus = 100 * pDm / atr;
        final diMinus = 100 * mDm / atr;
        out[i] = diPlus - diMinus;
      }
    }
    return out;
  }
}

class MacdSeries {
  MacdSeries({required this.dif, required this.dea, required this.hist});
  final List<double?> dif;
  final List<double?> dea;
  final List<double?> hist;
}

class KdjSeries {
  KdjSeries({required this.k, required this.d, required this.j});
  final List<double?> k;
  final List<double?> d;
  final List<double?> j;
}

class BollSeries {
  BollSeries({required this.mid, required this.upper, required this.lower});
  final List<double?> mid;
  final List<double?> upper;
  final List<double?> lower;
}
