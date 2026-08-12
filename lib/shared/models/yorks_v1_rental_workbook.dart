import 'dart:typed_data';

enum YorksV1RentalImportSeverity { warning, error }

class YorksV1RentalSelectedWorkbook {
  const YorksV1RentalSelectedWorkbook({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class YorksV1RentalImportIssue {
  const YorksV1RentalImportIssue({
    required this.sheet,
    required this.rowNumber,
    required this.message,
    this.severity = YorksV1RentalImportSeverity.error,
  });

  final String sheet;
  final int rowNumber;
  final String message;
  final YorksV1RentalImportSeverity severity;
}

class YorksV1RentalImportRow {
  const YorksV1RentalImportRow({
    required this.sheet,
    required this.rowNumber,
    required this.action,
    required this.label,
    required this.payload,
    this.issues = const [],
  });

  final String sheet;
  final int rowNumber;
  final String action;
  final String label;
  final Map<String, Object?> payload;
  final List<YorksV1RentalImportIssue> issues;

  bool get hasError => issues.any(
    (issue) => issue.severity == YorksV1RentalImportSeverity.error,
  );
}

class YorksV1RentalImportPreview {
  const YorksV1RentalImportPreview({
    required this.fileName,
    required this.commandId,
    required this.properties,
    required this.payments,
    required this.cheques,
    required this.issues,
  });

  final String fileName;
  final String commandId;
  final List<YorksV1RentalImportRow> properties;
  final List<YorksV1RentalImportRow> payments;
  final List<YorksV1RentalImportRow> cheques;
  final List<YorksV1RentalImportIssue> issues;

  List<YorksV1RentalImportRow> get rows => [
    ...properties,
    ...payments,
    ...cheques,
  ];

  int get newPropertyCount =>
      properties.where((row) => row.action == 'create').length;
  int get updatedPropertyCount =>
      properties.where((row) => row.action == 'update').length;
  int get warningCount => issues
      .where((issue) => issue.severity == YorksV1RentalImportSeverity.warning)
      .length;
  int get errorCount => issues
      .where((issue) => issue.severity == YorksV1RentalImportSeverity.error)
      .length;
  bool get canConfirm => rows.isNotEmpty && errorCount == 0;

  Map<String, Object?> toRpcPayload() => {
    'file_name': fileName,
    'properties': [for (final row in properties) row.payload],
    'payments': [for (final row in payments) row.payload],
    'cheques': [for (final row in cheques) row.payload],
  };
}

enum YorksV1RentalExportRegister {
  propertyLease,
  rentSchedule,
  payments,
  cheques,
  leaseExpiry,
}
