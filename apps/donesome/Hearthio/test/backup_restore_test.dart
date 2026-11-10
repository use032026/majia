import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearthio/main.dart';

void _writeUint32LittleEndian(List<int> bytes, int offset, int value) {
  for (var index = 0; index < 4; index++) {
    bytes[offset + index] = (value >> (index * 8)) & 0xff;
  }
}

void _understateZipEntryExpandedSize(List<int> bytes) {
  for (var offset = 0; offset <= bytes.length - 4; offset++) {
    final signature =
        bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
    if (signature == 0x04034b50) {
      _writeUint32LittleEndian(bytes, offset + 22, 1);
    } else if (signature == 0x02014b50) {
      _writeUint32LittleEndian(bytes, offset + 24, 1);
    }
  }
}

void main() {
  test('v2 backup round-trip preserves plans, records, and photo bytes', () {
    final item = CareItem(
      id: 'purifier',
      name: '净水器',
      category: '家电',
      location: '厨房',
      brand: '',
      model: '',
      notes: '',
      photos: const ['/device/水 filter#.jpg'],
      plans: [
        MaintenancePlan(
          id: 'filter',
          title: '更换滤芯',
          intervalDays: 180,
          dueDate: DateTime(2026, 9, 1),
        ),
        MaintenancePlan(
          id: 'clean',
          title: '清洗管路',
          intervalDays: 365,
          dueDate: DateTime(2027, 1, 1),
        ),
      ],
      records: [
        MaintenanceRecord(
          id: 'record-1',
          planId: 'filter',
          completedAt: DateTime(2026, 3, 1),
          cost: 120,
          materialName: 'PP 棉滤芯',
          note: '',
          beforePhotos: const ['/record/before.jpg'],
          afterPhotos: const ['/record/after.jpg'],
          kind: '更换滤芯',
        ),
      ],
    );

    final bytes = CareBackupCodec.encode(
      items: [item],
      photoBytesByPath: const {
        '/device/水 filter#.jpg': [1, 2, 3],
        '/record/before.jpg': [4, 5, 6],
        '/record/after.jpg': [7, 8, 9],
      },
    );
    final decoded = CareBackupCodec.decode(bytes);

    expect(decoded.items.single.plans, hasLength(2));
    expect(decoded.items.single.records.single.planId, 'filter');
    expect(decoded.items.single.photos.single, 'photos/0___filter_.jpg');
    expect(
      decoded.items.single.records.single.beforePhotos.single,
      startsWith('photos/'),
    );
    expect(
      decoded.items.single.records.single.afterPhotos.single,
      startsWith('photos/'),
    );
    expect(
      decoded.items.single.photos.single,
      isNot(decoded.items.single.records.single.beforePhotos.single),
    );
    expect(
      decoded.photos.values.map((value) => value.toList()),
      containsAll(<List<int>>[
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]),
    );
  });

  test('v1 backup data is migrated and its legacy photo is restored', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'data.json',
          jsonEncode([
            {
              'id': 'legacy',
              'name': '旧净水器',
              'category': '家电',
              'location': '厨房',
              'brand': '',
              'model': '',
              'notes': '',
              'photos': ['/old/location/photo.jpg'],
              'lastCareDate': DateTime(2026, 1, 1).toIso8601String(),
              'intervalDays': 180,
              'records': <Map<String, dynamic>>[],
            },
          ]),
        ),
      )
      ..add(ArchiveFile.bytes('photos/photo.jpg', const [7, 8, 9]));

    final decoded = CareBackupCodec.decode(ZipEncoder().encode(archive));

    expect(decoded.items.single.plans, hasLength(1));
    expect(decoded.items.single.photos, ['photos/photo.jpg']);
    expect(decoded.photos['photos/photo.jpg'], [7, 8, 9]);
  });

  test('backup rejects path traversal before reading file contents', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'data.json',
          const CareDataEnvelope(items: []).encode(),
        ),
      )
      ..add(ArchiveFile.bytes('../escape.jpg', const [1]));

    expect(
      () => CareBackupCodec.decode(ZipEncoder().encode(archive)),
      throwsA(isA<CareBackupException>()),
    );
  });

  test('backup rejects archives with too many files', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'data.json',
          const CareDataEnvelope(items: []).encode(),
        ),
      );
    for (var index = 0; index < CareBackupCodec.maxFiles; index++) {
      archive.add(ArchiveFile.bytes('photos/$index.jpg', const [1]));
    }

    expect(
      () => CareBackupCodec.decode(ZipEncoder().encode(archive)),
      throwsA(isA<CareBackupException>()),
    );
  });

  test('backup bounds actual output when ZIP headers understate size', () {
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'data.json',
          List<int>.filled(CareBackupCodec.maxDataFileBytes + 1, 0),
        ),
      );
    final encoded = ZipEncoder().encode(archive);
    _understateZipEntryExpandedSize(encoded);

    expect(
      () => CareBackupCodec.decode(encoded),
      throwsA(
        isA<CareBackupException>().having(
          (error) => error.message,
          'message',
          contains('解压时超过大小限制'),
        ),
      ),
    );
  });

  test('backup export fails closed when a referenced photo is missing', () {
    final item = CareItem(
      id: 'item',
      name: '物品',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const ['/missing/photo.jpg'],
    );

    expect(
      () => CareBackupCodec.encode(items: [item], photoBytesByPath: const {}),
      throwsA(
        isA<CareBackupException>().having(
          (error) => error.message,
          'message',
          contains('照片缺失'),
        ),
      ),
    );
  });

  test('backup restore rejects every missing data.json photo reference', () {
    final item = CareItem(
      id: 'item',
      name: '物品',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const ['photos/missing.jpg'],
    );
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'data.json',
          CareDataEnvelope(items: [item]).encode(),
        ),
      );

    expect(
      () => CareBackupCodec.decode(ZipEncoder().encode(archive)),
      throwsA(
        isA<CareBackupException>().having(
          (error) => error.message,
          'message',
          contains('缺失的照片'),
        ),
      ),
    );
  });
}
