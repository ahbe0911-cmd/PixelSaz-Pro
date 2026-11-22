import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/batch_conversion_controller.dart';
import '../controllers/batch_conversion_state.dart';

final batchConversionControllerProvider =
    NotifierProvider<BatchConversionController, BatchConversionState>(
  BatchConversionController.new,
);
