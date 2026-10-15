import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

typedef STNetworkImagePlaceholderBuilder =
    Widget Function(BuildContext context);

/// Lightweight network image loader for iOS parity screens.
///
/// iOS uses SDWebImage plus project-level cache layers. Flutter keeps this
/// smaller: bytes are cached on disk by URL, decoded images are cached by
/// Flutter's global [ImageCache], and callers can still provide their original
/// placeholder while loading or on failure.
class STNetworkImage extends StatefulWidget {
  const STNetworkImage({
    super.key,
    required this.imageUrl,
    this.placeholderBuilder,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  final String? imageUrl;
  final STNetworkImagePlaceholderBuilder? placeholderBuilder;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  static ImageCache get runtimeMemoryCache =>
      PaintingBinding.instance.imageCache;

  static final STNetworkImageDiskCache diskCache = STNetworkImageDiskCache();

  static Future<void> clearDiskCache() => diskCache.clear();

  @override
  State<STNetworkImage> createState() => _STNetworkImageState();
}

class _STNetworkImageState extends State<STNetworkImage> {
  static final _STNetworkImageMemoryPressureObserver _memoryPressureObserver =
      _STNetworkImageMemoryPressureObserver();

  FileImage? _imageProvider;
  String _activeUrl = '';
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _memoryPressureObserver.ensureAttached();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant STNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  void _loadImage() {
    final url = widget.imageUrl?.trim() ?? '';
    final token = ++_loadToken;
    _activeUrl = url;

    final hadProvider = _imageProvider != null;
    _imageProvider = null;
    if (hadProvider && mounted) {
      setState(() {});
    }
    if (url.isEmpty) return;

    _resolveCachedImage(url, token);
  }

  Future<void> _resolveCachedImage(String url, int token) async {
    try {
      final file =
          await STNetworkImage.diskCache.cachedFileForUrl(url) ??
          await STNetworkImage.diskCache.downloadAndCache(url);
      var provider = FileImage(file);
      try {
        await _decodeImage(provider);
      } catch (_) {
        await provider.evict(cache: STNetworkImage.runtimeMemoryCache);
        await STNetworkImage.diskCache.evict(url);
        final freshFile = await STNetworkImage.diskCache.downloadAndCache(url);
        provider = FileImage(freshFile);
        await provider.evict(cache: STNetworkImage.runtimeMemoryCache);
        await _decodeImage(provider);
      }
      if (!mounted || token != _loadToken || url != _activeUrl) return;
      setState(() => _imageProvider = provider);
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _imageProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUrl.isEmpty || _imageProvider == null) {
      return _placeholder(context);
    }

    return Image(
      image: _imageProvider!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.excludeFromSemantics,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _placeholder(context);
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child:
          widget.placeholderBuilder?.call(context) ??
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFF2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
    );
  }

  Future<void> _decodeImage(ImageProvider provider) {
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    final stream = provider.resolve(ImageConfiguration.empty);
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future.whenComplete(() {
      stream.removeListener(listener);
    });
  }
}

class STNetworkImageDiskCache {
  static const directoryName = 'st_network_image_cache';

  Future<File?> cachedFileForUrl(String url) async {
    final file = await fileForUrl(url);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> evict(String url) async {
    final file = await fileForUrl(url);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> downloadAndCache(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError.value(url, 'url', 'Invalid network image URL');
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Network image request failed: ${response.statusCode}',
          uri: uri,
        );
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.isEmpty) {
        throw const FormatException('Network image response is empty');
      }
      return writeBytes(url, bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<File> writeBytes(String url, Uint8List bytes) async {
    final file = await fileForUrl(url, createDirectory: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> fileForUrl(String url, {bool createDirectory = false}) async {
    final dir = await cacheDirectory(create: createDirectory);
    return File('${dir.path}/${cacheFileNameForUrl(url)}');
  }

  Future<Directory> cacheDirectory({bool create = false}) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$directoryName');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<int> sizeInBytes() async {
    final dir = await cacheDirectory();
    if (!await dir.exists()) return 0;

    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clear() async {
    final dir = await cacheDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String cacheFileNameForUrl(String url) {
    final digest = sha256.convert(utf8.encode(url.trim())).toString();
    final extension = _extensionForUrl(url);
    return extension.isEmpty ? digest : '$digest$extension';
  }

  String _extensionForUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';

    final extension = path.substring(dot).toLowerCase();
    final valid = RegExp(r'^\.[a-z0-9]{2,5}$').hasMatch(extension);
    return valid ? extension : '';
  }
}

class _STNetworkImageMemoryPressureObserver with WidgetsBindingObserver {
  bool _attached = false;

  void ensureAttached() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  @override
  void didHaveMemoryPressure() {
    STNetworkImage.runtimeMemoryCache.clear();
    STNetworkImage.runtimeMemoryCache.clearLiveImages();
  }
}
