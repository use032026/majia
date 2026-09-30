import 'dart:convert';

import 'package:file_selector/file_selector.dart';

class ImportedTextFile {
  const ImportedTextFile({required this.name, required this.content});

  final String name;
  final String content;
}

abstract class TextImportService {
  Future<ImportedTextFile?> pickTextFile();
}

class FileSelectorTextImportService implements TextImportService {
  const FileSelectorTextImportService();

  static const int maxImportBytes = 8 * 1024 * 1024;

  static const _textTypes = XTypeGroup(
    label: 'Text and Markdown',
    extensions: ['txt', 'md', 'markdown'],
    mimeTypes: ['text/plain', 'text/markdown'],
    uniformTypeIdentifiers: [
      'public.plain-text',
      'net.daringfireball.markdown',
    ],
  );

  @override
  Future<ImportedTextFile?> pickTextFile() async {
    final file = await openFile(acceptedTypeGroups: const [_textTypes]);
    if (file == null) return null;
    if (await file.length() > maxImportBytes) {
      throw const FormatException('The selected text file is too large.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxImportBytes) {
      throw const FormatException('The selected text file is too large.');
    }
    final content = decodeTextBytes(bytes);
    return ImportedTextFile(name: file.name, content: content);
  }
}

String decodeTextBytes(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }
  return utf8.decode(bytes, allowMalformed: false);
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  if (bytes.length.isOdd) {
    throw const FormatException('Invalid UTF-16 text file.');
  }
  final codeUnits = <int>[];
  for (var index = 0; index < bytes.length; index += 2) {
    final first = bytes[index];
    final second = bytes[index + 1];
    codeUnits.add(littleEndian ? first | (second << 8) : (first << 8) | second);
  }
  return String.fromCharCodes(codeUnits);
}
