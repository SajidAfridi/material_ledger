/// Real-time logistics dispatch shown on the Engineer Dashboard's
/// "Material Feed" panel.
library;

/// Status of a dispatch in transit.
enum DispatchStatus {
  inTransit('In Transit'),
  readyForInspection('Ready for Inspection'),
  delayed('Delayed in Traffic');

  const DispatchStatus(this.label);
  final String label;
}

/// A single dispatch item.
class MaterialDispatch {
  const MaterialDispatch({
    required this.id,
    required this.materialName,
    required this.materialNameSecondary,
    required this.quantity,
    required this.unitSymbol,
    required this.status,
    required this.timestamp,
    this.destination,
    this.assignedTo,
    this.note,
    this.delayReason,
    this.progress = 0.0,
  });

  final String id;
  final String materialName;
  final String materialNameSecondary;
  final int quantity;
  final String unitSymbol;
  final DispatchStatus status;
  final DateTime timestamp;
  final String? destination;
  final String? assignedTo;
  final String? note;
  final String? delayReason;

  /// 0.0 .. 1.0 — only meaningful for [DispatchStatus.inTransit].
  final double progress;
}
