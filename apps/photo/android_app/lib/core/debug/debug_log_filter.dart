import 'dart:async';

import 'package:flutter/foundation.dart';

/// 临时调试开关：为 true 时仅输出 WebView 相关日志，其余 `print` / `debugPrint` 静默。
/// WebView 调试完成后改回 [false] 即可恢复全量日志。
const bool kWebViewLogsOnly = false;

/// WebView 调试期间允许输出的日志前缀（包含即放行）。
const List<String> kWebViewLogAllowPrefixes = [
  '[WebView]',
  '[STMiniApi]',
  '[STBridge]',
];

const bool kForceTradeAccountSwitchLogs = bool.fromEnvironment(
  'TRADE_ACCOUNT_SWITCH_LOGS',
);

bool tradeAccountSwitchDiagnosticsEnabled({
  bool isReleaseMode = kReleaseMode,
  bool forceEnabled = kForceTradeAccountSwitchLogs,
}) {
  return forceEnabled || !isReleaseMode;
}

/// 安装全局日志过滤（Debug 模式 + [kWebViewLogsOnly] 时生效）。
void installDebugLogFilter() {
  if (!kDebugMode || !kWebViewLogsOnly) return;

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && _allowLogLine(message)) {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
    }
  };
}

/// 在 Zone 内运行 App，拦截裸 `print`。
void runAppWithLogFilter(void Function() body) {
  if (!kDebugMode || !kWebViewLogsOnly) {
    body();
    return;
  }

  runZonedGuarded(
    body,
    (error, stack) {
      // 未捕获异常始终输出，避免调试 WebView 时漏掉崩溃信息
      debugPrintThrottled('Uncaught error: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (_allowLogLine(line)) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

bool _allowLogLine(String line) {
  if (!kWebViewLogsOnly) return true;
  for (final prefix in kWebViewLogAllowPrefixes) {
    if (line.contains(prefix)) return true;
  }
  return false;
}

String debugSecretFingerprint(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw.toLowerCase() == 'null') return 'empty';
  final lower = raw.toLowerCase();
  final hasBearer = lower.startsWith('bearer ');
  final body = hasBearer ? raw.substring(7).trim() : raw;
  var hash = 0;
  for (final code in body.codeUnits) {
    hash = ((hash * 31) + code) & 0x3fffffff;
  }
  final fp = hash.toRadixString(16).padLeft(8, '0');
  return 'present(len=${body.length}, bearer=$hasBearer, fp=$fp)';
}
