String formatFileSize(int bytes) {
  if (bytes < 0) return '—';
  if (bytes < 1024) return '${_toPersianDigits(bytes.toString())} بایت';

  final double kib = bytes / 1024;
  if (kib < 1024) {
    return '${_toPersianDigits(_formatNumber(kib))} کیلوبایت';
  }

  final double mib = kib / 1024;
  if (mib < 1024) {
    return '${_toPersianDigits(_formatNumber(mib))} مگابایت';
  }

  final double gib = mib / 1024;
  return '${_toPersianDigits(_formatNumber(gib))} گیگابایت';
}

String _formatNumber(double value) {
  final int decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return value.toStringAsFixed(decimals);
}

String toPersianDigits(String value) => _toPersianDigits(value);

String normalizeDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final output = StringBuffer();
  for (final character in value.split('')) {
    final persianIndex = persian.indexOf(character);
    final arabicIndex = arabic.indexOf(character);
    if (persianIndex >= 0) {
      output.write(persianIndex);
    } else if (arabicIndex >= 0) {
      output.write(arabicIndex);
    } else {
      output.write(character);
    }
  }
  return output.toString();
}

String _toPersianDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final output = StringBuffer();
  for (final character in value.split('')) {
    final index = english.indexOf(character);
    output.write(index < 0 ? character : persian[index]);
  }
  return output.toString();
}
