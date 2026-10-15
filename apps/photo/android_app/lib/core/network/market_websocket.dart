import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/brand_config.dart';
import '../models/market_product_model.dart';
import 'st_service.dart';
import 'st_dio.dart';
import 'websocket_connector.dart';

/// WebSocket 连接状态
enum WSConnectionState { disconnected, connecting, connected, reconnecting }

/// 行情 WebSocket 服务
/// 对齐 iOS STMarketSocket
/// 协议路径: violet/marketdata/ws（由 API host 推导 ws/wss）
class MarketWebSocket {
  static const Set<String> _silentInboundLogTypes = {
    'TRANSACTION_UPDATE_SYMBOL_PRICE',
  };

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  WSConnectionState _state = WSConnectionState.disconnected;
  bool _disposed = false;
  bool _closedByClient = false;

  /// WebSocket URL（由 API host 推导）
  final String Function() wsUrlBuilder;
  final Map<String, dynamic> Function() headersBuilder;

  /// 已订阅的 symbols
  final Set<String> _subscribedSymbols = {};

  /// 连接状态 Stream
  final _stateController = StreamController<WSConnectionState>.broadcast();
  Stream<WSConnectionState> get stateStream => _stateController.stream;
  WSConnectionState get state => _state;

  /// 消息 Stream
  final _messageController = StreamController<MarketWSMessage>.broadcast();
  Stream<MarketWSMessage> get messageStream => _messageController.stream;

  /// 重连间隔（秒）
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 30;

  Map<String, dynamic>? _currentPageMessage;

  MarketWebSocket({required this.wsUrlBuilder, required this.headersBuilder});

  /// 获取 WebSocket URL
  String get _wsUrl => wsUrlBuilder();

  /// 构建 WebSocket URI，避免默认端口被解析为 0 导致连接失败。
  Uri _buildWsUri(String wsUrl) => normalizeMarketWebSocketUri(wsUrl);

  // ==================== 连接管理 ====================

  /// 建立连接
  void connect() {
    if (_disposed) return;
    if (_state == WSConnectionState.connected ||
        _state == WSConnectionState.connecting) {
      return;
    }
    _closedByClient = false;
    _setState(WSConnectionState.connecting);

    final wsUrl = _wsUrl;
    debugPrint('🔌 WS Connecting: $wsUrl');

    try {
      final uri = _buildWsUri(wsUrl);
      debugPrint(
        '🔌 WS URI scheme=${uri.scheme} host=${uri.host} port=${uri.hasPort ? uri.port : 'default'} path=${uri.path}',
      );
      final headers = Map<String, dynamic>.from(headersBuilder());
      headers.putIfAbsent('Origin', () => marketWebSocketOrigin(uri));
      final channel = connectWebSocket(
        uri,
        headers: headers,
        connectTimeout: const Duration(seconds: 10),
      );
      _channel = channel;

      channel.stream.listen(
        _onMessage,
        onError: (error) {
          debugPrint('⚠️ WS Error: $error');
          _onDisconnected();
        },
        onDone: () {
          debugPrint('⚠️ WS Closed');
          _onDisconnected();
        },
        cancelOnError: false,
      );

      channel.ready
          .then((_) {
            if (_disposed || !identical(_channel, channel)) return;
            _setState(WSConnectionState.connected);
            _reconnectAttempts = 0;
            _startHeartbeat();
            final current = _currentPageMessage;
            if (current != null && current.isNotEmpty) {
              _sendRaw(current);
            }
          })
          .catchError((Object error) {
            if (_disposed || !identical(_channel, channel)) return;
            debugPrint('⚠️ WS Ready failed: $error');
            _onDisconnected();
          });
    } catch (e) {
      debugPrint('❌ WS Connect failed: $e (url: $wsUrl)');
      _setState(WSConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect({bool permanently = false}) {
    _disposed = permanently;
    _closedByClient = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscribedSymbols.clear();
    _setState(WSConnectionState.disconnected);
  }

  /// 重置 disposed 标记（用于登录/登出后复用）
  void reset() {
    _disposed = false;
    _closedByClient = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }

  void _onDisconnected() {
    if (_state == WSConnectionState.reconnecting &&
        _reconnectTimer?.isActive == true) {
      return;
    }
    _setState(WSConnectionState.disconnected);
    _heartbeatTimer?.cancel();
    _channel = null;
    if (!_disposed && !_closedByClient) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _closedByClient) return;
    _reconnectTimer?.cancel();

    final delay = (_reconnectAttempts < 6)
        ? (1 << _reconnectAttempts) // 1, 2, 4, 8, 16, 32
        : _maxReconnectDelay;

    _setState(WSConnectionState.reconnecting);
    debugPrint(
      '🔄 WS reconnect in ${delay}s (attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectAttempts++;
      if (!_disposed) {
        connect();
      }
    });
  }

  void _setState(WSConnectionState newState) {
    _state = newState;
    if (!_disposed) {
      _stateController.add(newState);
    }
  }

  // ==================== 心跳 ====================

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _state == WSConnectionState.connected) {
        // 发送心跳 ping（保持长连接）
        try {
          _channel!.sink.add(jsonEncode({'type': 'PING'}));
        } catch (_) {}
      }
    });
  }

  // ==================== 消息发送（对齐 iOS 协议） ====================

  /// 发送 ENTER_EMPTY：清空订阅
  void sendEnterEmpty() {
    _send({'type': 'ENTER_EMPTY'}, clearCurrent: true);
    _subscribedSymbols.clear();
  }

  /// 发送 ENTER_MARKET_LIST：进入行情列表
  /// 对齐 iOS `STMarketSocket`：`{ type, message: { symbol_group } }`
  void sendEnterMarketList(int rankType) {
    _send({
      'type': 'ENTER_MARKET_LIST',
      'message': {'symbol_group': symbolGroupParam(rankType)},
    }, rememberCurrent: true);
  }

  /// 发送 ENTER_SYMBOL_DETAIL：进入行情详情
  /// `chart` 为服务端周期串（如 `1MIN`），与 [STService.chartParam] 一致；负载在 `message` 内（同 iOS）。
  void sendEnterSymbolDetail(String symbol, {required String chart}) {
    _send({
      'type': 'ENTER_SYMBOL_DETAIL',
      'message': {'symbol': symbol, 'chart': chart},
    }, rememberCurrent: true);
  }

  /// 发送 SWITCH_KLINE_CHART：切换 K 线周期
  void sendSwitchKlineChart(String symbol, String chart) {
    _send({
      'type': 'SWITCH_KLINE_CHART',
      'message': {'symbol': symbol, 'chart': chart},
    }, rememberCurrent: true);
  }

  /// 发送 ENTER_TRANSACTION_PAGE：进入交易页
  void sendEnterTransactionPage(String symbol) {
    _send({
      'type': 'ENTER_TRANSACTION_PAGE',
      'message': {'symbol': symbol},
    }, rememberCurrent: true);
  }

  /// 发送 LOGOUT：登出
  void sendLogout() {
    _send({'type': 'LOGOUT'});
    _subscribedSymbols.clear();
  }

  void _send(
    Map<String, dynamic> message, {
    bool rememberCurrent = false,
    bool clearCurrent = false,
  }) {
    if (clearCurrent) {
      _currentPageMessage = null;
    } else if (rememberCurrent) {
      _currentPageMessage = Map<String, dynamic>.from(message);
    }
    if (_channel != null && _state == WSConnectionState.connected) {
      _sendRaw(message);
    }
  }

  void _sendRaw(Map<String, dynamic> message) {
    _channel!.sink.add(jsonEncode(message));
  }

  // ==================== 消息接收 ====================

  void _onMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> json;
      if (rawMessage is String) {
        json = jsonDecode(rawMessage) as Map<String, dynamic>;
      } else if (rawMessage is List<int>) {
        json = jsonDecode(utf8.decode(rawMessage)) as Map<String, dynamic>;
      } else {
        return;
      }

      final message = MarketWSMessage.fromJson(json);
      _messageController.add(message);

      // 收到 PONG 忽略（心跳响应）
      if (message.type == 'PONG') return;

      if (!_silentInboundLogTypes.contains(message.type)) {
        debugPrint('📡 WS << ${message.type}');
      }
    } catch (e) {
      debugPrint('⚠️ WS parse error: $e');
    }
  }

  /// 重新连接（登录/登出后调用）
  void reConnect() {
    disconnect();
    reset();
    connect();
  }

  void dispose() {
    disconnect(permanently: true);
    _stateController.close();
    _messageController.close();
  }
}

// ==================== Provider ====================

@visibleForTesting
Uri normalizeMarketWebSocketUri(String wsUrl) {
  final parsed = Uri.parse(wsUrl);
  final host = parsed.host;
  if (host.isEmpty) return parsed;

  final scheme = parsed.scheme;
  final defaultPort = switch (scheme) {
    'wss' => 443,
    'ws' => 80,
    _ => null,
  };
  final port = parsed.hasPort && parsed.port > 0 ? parsed.port : defaultPort;

  return Uri(
    scheme: scheme,
    host: host,
    port: port,
    path: parsed.path,
    query: parsed.hasQuery ? parsed.query : null,
  );
}

@visibleForTesting
String marketWebSocketOrigin(Uri uri) {
  final scheme = switch (uri.scheme.toLowerCase()) {
    'wss' => 'https',
    'ws' => 'http',
    final value => value,
  };
  final isDefaultPort =
      (scheme == 'https' && uri.port == 443) ||
      (scheme == 'http' && uri.port == 80);
  final port = uri.hasPort && !isDefaultPort ? ':${uri.port}' : '';
  return '$scheme://${uri.host}$port';
}

/// 从 API host 推导 WebSocket URL
/// 对齐 iOS STMarketSocket.initWebSocket
///   NSURL *domain = [NSURL URLWithString:[STSDKUtility appRequestUrl]];
///   取 scheme → ws/wss，取 host → host，拼合 wss://host/violet/marketdata/ws
String _deriveWsUrl() {
  final brand = BrandConfig.jufu();
  var domain = brand.apiBaseUrlForBuildMode.trim();
  // 避免异常 URL 中出现 :0 端口（部分环境下解析或拼接会得到非法 ws 地址）
  domain = domain.replaceFirst(RegExp(r':0(?=/|\?|#|\$)'), '');
  final uri = Uri.parse(domain);
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  final host = uri.host;
  if (host.isEmpty) {
    debugPrint('⚠️ _deriveWsUrl: empty host, raw domain="$domain"');
  }
  return '$scheme://$host/violet/marketdata/ws';
}

/// Market WebSocket Provider（懒加载单例）
final marketWebSocketProvider = Provider<MarketWebSocket>((ref) {
  final dio = ref.watch(stDioProvider);
  final ws = MarketWebSocket(
    wsUrlBuilder: _deriveWsUrl,
    headersBuilder: dio.buildWebSocketHeaders,
  );
  ref.onDispose(() => ws.dispose());
  return ws;
});
