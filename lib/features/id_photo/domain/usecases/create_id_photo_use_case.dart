import '../../../../core/image_processing/domain/entities/image_compression_options.dart';
import '../../../../core/image_processing/domain/entities/image_processing_progress.dart';
import '../../../../core/image_processing/domain/entities/image_processing_result.dart';
import '../../../../core/image_processing/domain/repositories/image_processing_repository.dart';

class CreateIdPhotoUseCase {
  const CreateIdPhotoUseCase(this._repository);

  final ImageProcessingRepository _repository;

  Future<ImageProcessingResult> call({
    required String inputPath,
    IdPhotoOptions options = const IdPhotoOptions(),
    ImageProcessingProgressCallback? onProgress,
  }) {
    return _repository.createIdPhotoJpeg(
      inputPath: inputPath,
      options: options,
      onProgress: onProgress,
    );
  }
}
