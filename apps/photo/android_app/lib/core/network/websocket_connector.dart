import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_connector_stub.dart'
    if (dart.library.html) 'websocket_connector_html.dart'
    if (dart.library.io) 'websocket_connector_io.dart'
    as platform;

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
  Duration? connectTimeout,
}) {
  return platform.connectWebSocket(
    uri,
    headers: headers,
    connectTimeout: connectTimeout,
  );
}
