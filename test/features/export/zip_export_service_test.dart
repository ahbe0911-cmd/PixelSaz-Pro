import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/features/batch_converter/domain/entities/batch_image_item.dart';
import 'package:pixelsaz_pro/features/export/data/services/zip_export_service.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pixelsaz_zip_test_');
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  BatchImageItem completed(String id, String path, String name) {
    return BatchImageItem(
      id: id,
      path: path,
      originalName: name,
      sourceSizeBytes: 200,
      status: BatchImageStatus.completed,
      outputPath: path,
      outputSizeBytes: 8,
      exportBaseName: name,
    );
  }

  test('ZIP contains all selected JPEGs with Persian names unchanged', () async {
    final one = File(temporary.path + '/first.jpg');
    final two = File(temporary.path + '/second.jpg');
    await one.writeAsBytes(<int>[0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]);
    await two.writeAsBytes(<int>[0xFF, 0xD8, 4, 5, 6, 0xFF, 0xD9]);
    final service = ZipExportService(
      temporaryDirectoryProvider: () async => temporary,
    );

    final result = await service.createZip(<BatchImageItem>[
      completed('1', one.path, 'مدارک_علی_1'),
      completed('2', two.path, 'مدارک_علی_2.jpg'),
    ]);
    expect(result.imageCount, 2);
    expect(result.fileName, 'PixelSaz-Pro_2-photos.zip');
    expect(result.sizeBytes, greaterThan(0));

    final archive = ZipDecoder().decodeBytes(
      await File(result.path).readAsBytes(),
    );
    expect(archive.files.length, 2);
    expect(
      archive.files.map((file) => file.name).toList(growable: false),
      <String>['مدارک_علی_1.jpg', 'مدارک_علی_2.jpg'],
    );
  });

  test('existing source files remain unchanged after ZIP creation', () async {
    final original = File(temporary.path + '/photo.jpg');
    const bytes = <int>[0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9];
    await original.writeAsBytes(bytes);
    final service = ZipExportService(
      temporaryDirectoryProvider: () async => temporary,
    );
    await service.createZip(<BatchImageItem>[
      completed('a', original.path, 'رزومه'),
    ]);
    expect(await original.readAsBytes(), bytes);
  });

  test('invalid, duplicated and missing files cannot produce ZIP', () async {
    final original = File(temporary.path + '/a.jpg');
    await original.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
    final service = ZipExportService(
      temporaryDirectoryProvider: () async => temporary,
    );
    await expectLater(
      service.createZip(<BatchImageItem>[]),
      throwsA(isA<ZipExportException>()),
    );
    await expectLater(
      service.createZip(<BatchImageItem>[
        completed('a', original.path, 'مدرک'),
        completed('b', original.path, 'مدرک.jpg'),
      ]),
      throwsFormatException,
    );
    await expectLater(
      service.createZip(<BatchImageItem>[
        completed('a', temporary.path + '/missing.jpg', 'مدرک'),
      ]),
      throwsA(isA<ZipExportException>()),
    );
  });

  test('ZIP writer rejects unsafe archive entry paths', () async {
    final original = File(temporary.path + '/a.jpg');
    await original.writeAsBytes(<int>[1, 2, 3]);
    await expectLater(
      writeZipFiles(temporary.path + '/bad.zip', <ZipInputFile>[
        ZipInputFile(original.path, '../escape.jpg'),
      ]),
      throwsA(isA<ZipExportException>()),
    );
  });
}
