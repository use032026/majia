import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenedPackage {
  const OpenedPackage({required this.text, required this.name});
  final String text;
  final String name;
}

enum ShareOutcome { shared, dismissed, unavailable }

abstract class PlatformServices {
  Future<void> copyText(String text);
  Future<OpenedPackage?> openPackage();
  Future<ShareOutcome> sharePackage(
    String json, {
    required String filename,
    required Rect origin,
  });
  Future<void> openSource(String url);
}

class NativePlatformServices implements PlatformServices {
  const NativePlatformServices();
  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<OpenedPackage?> openPackage() async {
    const group = XTypeGroup(
      label: 'ID Fixture JSON',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    if (await file.length() > 1024 * 1024) {
      throw const FormatException('文件超过1MB上限 / File exceeds the 1MB limit');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > 1024 * 1024) {
        throw const FormatException('文件超过1MB上限 / File exceeds the 1MB limit');
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return OpenedPackage(text: utf8.decode(bytes), name: file.name);
  }

  @override
  Future<ShareOutcome> sharePackage(
    String json, {
    required String filename,
    required Rect origin,
  }) async {
    if (origin.isEmpty || !origin.isFinite) {
      throw const FormatException('分享位置无效 / Invalid share origin');
    }
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final temporary = await getTemporaryDirectory();
    final directory = Directory('${temporary.path}/id_fixture_exports');
    await directory.create(recursive: true);
    // Separate files protect a still-running share extension from later batches.
    final file = File(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-$safeName',
    );
    await file.writeAsString(json, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [safeName],
        sharePositionOrigin: origin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }

  @override
  Future<void> openSource(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('只允许HTTPS来源 / HTTPS sources only');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('无法打开来源页面 / Unable to open the source');
    }
  }
}
