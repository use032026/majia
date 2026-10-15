import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
  Duration? connectTimeout,
}) {
  return HtmlWebSocketChannel.connect(uri);
}
