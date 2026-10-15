import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_language_option.dart';
import '../network/st_service.dart';

/// 已解析的可用语言列表（对齐 iOS：只消费已缓存的 `languageList`）。
class AvailableLanguagesNotifier
    extends StateNotifier<List<AppLanguageOption>> {
  AvailableLanguagesNotifier(this._ref) : super(const []);

  final Ref _ref;

  /// 启动期预取后写入；语言页本身不主动刷新，缓存为空时保持空列表。
  void applyFromRawResponse(List<dynamic> rawLanguages) {
    final next = AppLanguageOption.fromAvailableLanguagesPayload(rawLanguages);
    if (next.isEmpty) return;
    state = next;
  }

  Future<void> refreshFromNetwork() async {
    try {
      final raw = await _ref.read(stServiceProvider).getAvailableLanguages();
      applyFromRawResponse(raw);
    } catch (_) {
      /* 对齐 iOS：请求失败时保留当前缓存；没有缓存则为空列表。 */
    }
  }
}

final availableLanguagesProvider =
    StateNotifierProvider<AvailableLanguagesNotifier, List<AppLanguageOption>>((
      ref,
    ) {
      return AvailableLanguagesNotifier(ref);
    });
