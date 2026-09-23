import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

final class PhotoLibrarySaveException implements Exception {
  const PhotoLibrarySaveException(this.code);

  static const String permissionDenied = 'photo-permission-denied';
  static const String invalidImage = 'invalid-image';
  static const String unavailable = 'photo-save-unavailable';

  final String code;
}

abstract interface class PhotoLibraryGateway {
  Future<void> savePng(Uint8List bytes);
}

final class MethodChannelPhotoLibraryGateway implements PhotoLibraryGateway {
  const MethodChannelPhotoLibraryGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('trip_cost/photos');

  final MethodChannel _channel;

  @override
  Future<void> savePng(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const PhotoLibrarySaveException(
        PhotoLibrarySaveException.invalidImage,
      );
    }
    try {
      await _channel.invokeMethod<void>('savePng', bytes);
    } on PlatformException catch (error) {
      throw PhotoLibrarySaveException(error.code);
    } on MissingPluginException {
      throw const PhotoLibrarySaveException(
        PhotoLibrarySaveException.unavailable,
      );
    }
  }
}
