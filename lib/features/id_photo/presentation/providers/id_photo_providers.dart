import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/id_photo_image_preparation_service.dart';
import '../../data/services/id_photo_rotation_service.dart';

final idPhotoImagePreparationServiceProvider =
    Provider<IdPhotoImagePreparationService>(
  (ref) => IdPhotoImagePreparationService(),
);

final idPhotoRotationServiceProvider = Provider<IdPhotoRotationService>(
  (ref) => IdPhotoRotationService(),
);
