import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/data/text_import_service.dart';

void main() {
  test('decodes UTF-8 text', () {
    expect(decodeTextBytes([0x48, 0x69]), 'Hi');
  });

  test('decodes UTF-16 little-endian text with a BOM', () {
    expect(decodeTextBytes([0xFF, 0xFE, 0x60, 0x4F, 0x7D, 0x59]), '你好');
  });

  test('rejects malformed UTF-16 text', () {
    expect(() => decodeTextBytes([0xFF, 0xFE, 0x41]), throwsFormatException);
  });
}
