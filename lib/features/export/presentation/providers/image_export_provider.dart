import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/image_export_service.dart';
import '../../data/services/zip_export_service.dart';

final imageExportServiceProvider = Provider<ImageExportService>(
  (ref) => ImageExportService(),
);

final zipExportServiceProvider = Provider<ZipExportService>(
  (ref) => ZipExportService(),
);
