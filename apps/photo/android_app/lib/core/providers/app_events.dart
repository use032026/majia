import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录成功事件提供者
/// 对齐 iOS: NSNotification "loginPreSuccess"
///
/// 计数递增，监听方通过 ref.listen 检测变化后刷新数据
/// 使用方式:
///   ref.listen(loginSuccessProvider, (prev, next) {
///     if (prev != next) { /* 刷新数据 */ }
///   });
///
/// 触发方式（在登录成功后调用）:
///   ref.read(loginSuccessProvider.notifier).increment();
final loginSuccessProvider = StateNotifierProvider<LoginSuccessNotifier, int>((ref) {
  return LoginSuccessNotifier();
});

class LoginSuccessNotifier extends StateNotifier<int> {
  LoginSuccessNotifier() : super(0);

  void increment() => state++;
}

/// 自选列表数据变更（对齐 iOS `STOptionListDidUpdateNotification`）。
/// 一键添加、编辑/删除自选、详情页加减自选后递增；[CardListPage] 与 [OptionalListPage] 监听后刷新。
final selfMarketListRefreshTickProvider = StateProvider<int>((ref) => 0);

/// 通知自选列表已变更（跨页刷新首页 `selfmarket_*` 与行情 Tab 自选页）
void notifyWatchlistChanged(WidgetRef ref) {
  ref.read(selfMarketListRefreshTickProvider.notifier).state++;
}
