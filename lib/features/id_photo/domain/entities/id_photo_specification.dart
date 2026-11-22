import '../../../../core/constants/app_constants.dart';

/// Print specification used by the ID-photo export pipeline.
abstract final class IdPhotoSpecification {
  static const int width = AppConstants.idPhotoWidthPx;
  static const int height = AppConstants.idPhotoHeightPx;
  static const int dpi = AppConstants.idPhotoDpi;
  static const double aspectRatio = width / height;
}
