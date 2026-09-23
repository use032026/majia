import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:trip_cost/core/platform/photo_library_gateway.dart';

abstract interface class TripSummaryImageSaving {
  Future<void> captureAndSave(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 3,
  });
}

final class TripSummaryImageService implements TripSummaryImageSaving {
  const TripSummaryImageService({required PhotoLibraryGateway photoLibrary})
    : _photoLibrary = photoLibrary;

  final PhotoLibraryGateway _photoLibrary;

  @override
  Future<void> captureAndSave(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 3,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
      throw const PhotoLibrarySaveException(
        PhotoLibrarySaveException.invalidImage,
      );
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const PhotoLibrarySaveException(
          PhotoLibrarySaveException.invalidImage,
        );
      }
      await _photoLibrary.savePng(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }
}
