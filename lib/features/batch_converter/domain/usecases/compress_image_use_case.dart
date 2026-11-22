import '../../../../core/image_processing/domain/entities/image_compression_options.dart';
import '../../../../core/image_processing/domain/entities/image_processing_progress.dart';
import '../../../../core/image_processing/domain/entities/image_processing_result.dart';
import '../../../../core/image_processing/domain/repositories/image_processing_repository.dart';

class CompressImageUseCase {
  const CompressImageUseCase(this._repository);

  final ImageProcessingRepository _repository;

  Future<ImageProcessingResult> call({
    required String inputPath,
    ImageCompressionOptions options = const ImageCompressionOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    return _repository.compressToJpeg(
      inputPath: inputPath,
      options: options,
      onProgress: onProgress,
    );
  }
}
