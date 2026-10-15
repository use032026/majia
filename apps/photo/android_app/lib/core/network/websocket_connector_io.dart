import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
  Duration? connectTimeout,
}) {
  return IOWebSocketChannel.connect(
    uri,
    headers: headers,
    connectTimeout: connectTimeout,
  );
}
