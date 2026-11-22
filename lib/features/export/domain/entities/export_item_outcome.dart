class ExportItemOutcome {
  const ExportItemOutcome({
    required this.itemId,
    required this.fileName,
    required this.success,
    this.errorMessage,
  });

  final String itemId;
  final String fileName;
  final bool success;
  final String? errorMessage;
}

class ExportBatchOutcome {
  const ExportBatchOutcome(this.items);

  final List<ExportItemOutcome> items;

  int get successCount => items.where((item) => item.success).length;
  int get failureCount => items.length - successCount;
}
