import '../providers/project_cost_provider.dart';

class CommercialExportDenied implements Exception {
  const CommercialExportDenied();

  @override
  String toString() => 'Commercial export is not permitted for this session.';
}

abstract final class CommercialCsvExport {
  static String projectCosts(
    List<ProjectCostRow> rows, {
    required bool canViewCommercials,
  }) {
    if (!canViewCommercials) throw const CommercialExportDenied();
    final buffer = StringBuffer(
      'Project,Dispatched (AED),Returned (AED),Net (AED)\n',
    );
    for (final row in rows) {
      buffer.writeln(
        '${_cell(row.projectName)},'
        '${row.cost.dispatchedAED.toStringAsFixed(2)},'
        '${row.cost.returnedAED.toStringAsFixed(2)},'
        '${row.cost.netAED.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  static String _cell(String value) => '"${value.replaceAll('"', '""')}"';
}
