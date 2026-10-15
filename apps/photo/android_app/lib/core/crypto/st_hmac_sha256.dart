import 'dart:convert';

import 'package:crypto/crypto.dart';

/// iOS `NSString+Tool.h`：`Sha256Secrect`
/// 与 `-[NSString hmacSHA256WithSecret:]` 一致：密钥按 ASCII 字节、`plainText` 按 UTF-8，输出小写十六进制。
const String kStHmacSha256Secret =
    'MEgCQQDJw3rgyWSkImlP0aPOKTNmSZQOzQhT1ihQzeXGH7VH8IfP0aOvGEThF6XoXkCm4rxrLQUAX4TxdbI3K+lG1LFlAgMBAAE=';

String stHmacSha256Hex(String plainText) {
  final key = ascii.encode(kStHmacSha256Secret);
  final bytes = utf8.encode(plainText);
  final digest = Hmac(sha256, key).convert(bytes);
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
