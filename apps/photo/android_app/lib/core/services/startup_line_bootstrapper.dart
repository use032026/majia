import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StartupLineBootstrapStage { anonymousLogin, versionCheck, appConfig }

class StartupLineBootstrapContext {
  const StartupLineBootstrapContext({
    required this.stage,
    required this.error,
    required this.attempt,
  });

  final StartupLineBootstrapStage stage;
  final Object error;
  final int attempt;
}

typedef StartupLineBootstrapHandler =
    Future<bool> Function(StartupLineBootstrapContext context);

/// 启动期线路 bootstrap 接缝。
///
/// iOS 在启动关键请求遇到 DNS/超时/连接/证书类错误时触发
/// `STStarbustLineRouting.bootstrapRemoteCatalogAfterStartup...`，成功切线后重跑
/// 当前启动阶段。Flutter 当前尚未拥有远端线路目录实现，因此这里先将启动重试
/// 语义收口为可注入服务，真实目录/切线实现接入后不需要再改启动流程。
class StartupLineBootstrapper {
  const StartupLineBootstrapper({
    this.bootstrapHandler,
    this.maxBootstrapAttempts = 6,
  });

  final StartupLineBootstrapHandler? bootstrapHandler;
  final int maxBootstrapAttempts;

  Future<T> run<T>({
    required StartupLineBootstrapStage stage,
    required Future<T> Function() request,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await request();
      } catch (e) {
        if (attempt >= maxBootstrapAttempts || !shouldBootstrapError(e)) {
          rethrow;
        }
        attempt += 1;
        final didSwitch =
            await bootstrapHandler?.call(
              StartupLineBootstrapContext(
                stage: stage,
                error: e,
                attempt: attempt,
              ),
            ) ??
            false;
        if (!didSwitch) {
          rethrow;
        }
      }
    }
  }

  bool shouldBootstrapError(Object error) {
    if (error is! DioException) return false;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.unknown:
        final inner = error.error;
        return inner is SocketException || inner is HandshakeException;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }
}

final startupLineBootstrapperProvider = Provider<StartupLineBootstrapper>((
  ref,
) {
  return const StartupLineBootstrapper();
});
