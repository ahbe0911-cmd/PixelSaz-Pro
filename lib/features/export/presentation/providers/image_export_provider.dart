import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/image_export_service.dart';

final imageExportServiceProvider = Provider<ImageExportService>(
  (ref) => ImageExportService(),
);
