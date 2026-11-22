class ImageProcessingException implements Exception {
  const ImageProcessingException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageProcessingException($code): $message';
}
