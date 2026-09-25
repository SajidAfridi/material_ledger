import '../models/yorks_v1_material_request.dart';

/// Presentation-only line commands shared by both MR composers. Implementations
/// retain their own draft model, persistence and authorization boundary.
abstract interface class YorksV1MaterialLineEditor {
  Future<void> updateLine(
    String lineId,
    YorksV1MaterialRequestLine Function(YorksV1MaterialRequestLine) transform,
  );
  Future<void> addCustomLine({String? afterLineId});
  Future<void> addSimilarLine({String? afterLineId});
  Future<void> removeLine(String lineId);
}
