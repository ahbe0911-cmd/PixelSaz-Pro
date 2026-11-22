import '../entities/image_compression_options.dart';
import '../entities/image_processing_progress.dart';
import '../entities/image_processing_result.dart';

abstract interface class ImageProcessingRepository {
  Future<ImageProcessingResult> compressToJpeg({
    required String inputPath,
    ImageCompressionOptions options = const ImageCompressionOptions(),
    ImageProcessingProgressCallback? onProgress,
  });

  Future<ImageProcessingResult> createIdPhotoJpeg({
    required String inputPath,
    IdPhotoOptions options = const IdPhotoOptions(),
    ImageProcessingProgressCallback? onProgress,
  });
}
