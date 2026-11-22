import '../../domain/entities/image_compression_options.dart';
import '../../domain/entities/image_processing_progress.dart';
import '../../domain/entities/image_processing_result.dart';
import '../../domain/repositories/image_processing_repository.dart';
import 'image_processing_service.dart';

/// Explicit repository adapter retained as the Clean Architecture boundary.
class ImageProcessingRepositoryImpl implements ImageProcessingRepository {
  ImageProcessingRepositoryImpl({ImageProcessingService? service})
      : _service = service ?? ImageProcessingService();

  final ImageProcessingService _service;

  @override
  Future<ImageProcessingResult> compressToJpeg({
    required String inputPath,
    ImageCompressionOptions options = const ImageCompressionOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    return _service.compressToJpeg(
      inputPath: inputPath,
      options: options,
      onProgress: onProgress,
    );
  }

  @override
  Future<ImageProcessingResult> createIdPhotoJpeg({
    required String inputPath,
    IdPhotoOptions options = const IdPhotoOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    return _service.createIdPhotoJpeg(
      inputPath: inputPath,
      options: options,
      onProgress: onProgress,
    );
  }
}
