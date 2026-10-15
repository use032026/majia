import 'package:flutter/widgets.dart';

import '../network/st_service.dart';
import 'version_update_service.dart';

/// 对齐 iOS `applicationDidBecomeActive:`：App 回到前台时重新检查版本更新。
class AppLifecycleVersionRefresher {
  bool _checking = false;

  Future<void> didChangeAppLifecycleState(
    AppLifecycleState state, {
    required BuildContext context,
    required STService stService,
    required VersionUpdateService versionUpdateService,
    String? customerServiceUrl,
    Future<void> Function()? onNeedUpdatePassword,
  }) async {
    if (state != AppLifecycleState.resumed || _checking || !context.mounted) {
      return;
    }

    _checking = true;
    try {
      await versionUpdateService.checkVersionUpdate(
        context: context,
        stService: stService,
        customerServiceUrl: customerServiceUrl,
        onNeedUpdatePassword: onNeedUpdatePassword,
      );
    } finally {
      _checking = false;
    }
  }
}
