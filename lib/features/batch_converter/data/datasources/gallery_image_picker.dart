import 'package:image_picker/image_picker.dart';

class PickedImageFile {
  const PickedImageFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Uses the operating system's photo picker instead of broad gallery access.
class GalleryImagePicker {
  GalleryImagePicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<List<PickedImageFile>> pickImages({required int limit}) async {
    if (limit <= 0) return const <PickedImageFile>[];
    final files = await _imagePicker.pickMultiImage(limit: limit);
    return _mapFiles(files);
  }

  /// Recovers files returned by Android after the system recreated the app
  /// while the external photo-picker activity was open.
  Future<List<PickedImageFile>> retrieveLostImages() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return const <PickedImageFile>[];
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    if (files == null || files.isEmpty) return const <PickedImageFile>[];
    return _mapFiles(files);
  }

  Future<List<PickedImageFile>> _mapFiles(Iterable<XFile> files) async {
    final picked = <PickedImageFile>[];
    for (final file in files) {
      final size = await file.length();
      picked.add(
        PickedImageFile(
          path: file.path,
          name: file.name,
          sizeBytes: size,
        ),
      );
    }
    return picked;
  }
}
