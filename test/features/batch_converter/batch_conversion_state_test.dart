import 'package:flutter_test/flutter_test.dart';
import 'package:pixelsaz_pro/features/batch_converter/domain/entities/batch_image_item.dart';
import 'package:pixelsaz_pro/features/batch_converter/presentation/controllers/batch_conversion_state.dart';

void main() {
  group('BatchConversionState', () {
    test('uses 495 KiB as the default target size', () {
      final state = BatchConversionState();
      expect(state.targetBytes, 495 * 1024);
    });

    test('counts successful and failed items independently', () {
      final state = BatchConversionState(
        items: const <BatchImageItem>[
          BatchImageItem(
            id: 'one',
            path: '/one.png',
            originalName: 'one.png',
            sourceSizeBytes: 1000,
            status: BatchImageStatus.completed,
            outputSizeBytes: 500,
          ),
          BatchImageItem(
            id: 'two',
            path: '/two.png',
            originalName: 'two.png',
            sourceSizeBytes: 1000,
            status: BatchImageStatus.failed,
          ),
          BatchImageItem(
            id: 'three',
            path: '/three.png',
            originalName: 'three.png',
            sourceSizeBytes: 1000,
          ),
        ],
      );

      expect(state.totalCount, 3);
      expect(state.successfulCount, 1);
      expect(state.failedCount, 1);
      expect(state.pendingCount, 1);
      expect(state.totalSavedBytes, 500);
    });

    test('does not report negative savings when an output is larger', () {
      final state = BatchConversionState(
        items: const <BatchImageItem>[
          BatchImageItem(
            id: 'one',
            path: '/one.png',
            originalName: 'one.png',
            sourceSizeBytes: 500,
            status: BatchImageStatus.completed,
            outputSizeBytes: 700,
          ),
        ],
      );

      expect(state.totalSavedBytes, 0);
    });
  });
}
