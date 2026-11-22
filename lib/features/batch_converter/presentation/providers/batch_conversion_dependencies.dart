import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/image_processing/data/repositories/image_processing_service.dart';
import '../../data/datasources/gallery_image_picker.dart';

final imageProcessingServiceProvider = Provider<ImageProcessingService>(
  (ref) => ImageProcessingService(),
);

final galleryImagePickerProvider = Provider<GalleryImagePicker>(
  (ref) => GalleryImagePicker(),
);
