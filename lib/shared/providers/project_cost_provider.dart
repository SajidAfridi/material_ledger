import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_request.dart';
import 'inventory_provider.dart';
import 'material_request_provider.dart';
import 'material_return_provider.dart';

/// Cost roll-up for one project: value dispatched to site, value returned to
/// store, and the net consumed cost. Costs are valued at the inventory unit
/// cost (weighted average). Visible to Admin only (finance — FR-091/092).
class ProjectCost {
  const ProjectCost({
    required this.dispatchedAED,
    required this.returnedAED,
  });

  final double dispatchedAED;
  final double returnedAED;

  /// Net material cost consumed by the project.
  double get netAED =>
      (dispatchedAED - returnedAED).clamp(0, double.infinity).toDouble();
}

/// Statuses that mean stock has physically left the store for a project.
const _dispatchedStatuses = {
  RequestStatus.partial,
  RequestStatus.dispatched,
  RequestStatus.received,
};

/// Per-project cost roll-up, keyed by project name (requests/returns key on it).
final projectCostProvider = Provider.family<ProjectCost, String>((
  ref,
  projectName,
) {
  final materials = ref.watch(materialsProvider);
  final requests = ref.watch(materialRequestsProvider);
  final returns = ref.watch(returnsProvider);

  double costOf(String materialId) {
    for (final m in materials) {
      if (m.id == materialId) return m.unitCostAED;
    }
    return 0;
  }

  var dispatched = 0.0;
  for (final r in requests) {
    if (r.projectName != projectName) continue;
    if (!_dispatchedStatuses.contains(r.status)) continue;
    for (final line in r.lineItems) {
      final qty = line.qtyReceived ?? line.quantity;
      dispatched += qty * costOf(line.materialId);
    }
  }

  var returned = 0.0;
  for (final ret in returns) {
    if (ret.projectName != projectName) continue;
    for (final item in ret.items) {
      if (item.materialId == null) continue;
      returned += item.quantity * costOf(item.materialId!);
    }
  }

  return ProjectCost(dispatchedAED: dispatched, returnedAED: returned);
});

/// Total net material cost across every project (accountant dashboard figure).
final totalProjectCostProvider = Provider<double>((ref) {
  final requests = ref.watch(materialRequestsProvider);
  final names = <String>{for (final r in requests) r.projectName};
  var total = 0.0;
  for (final name in names) {
    total += ref.watch(projectCostProvider(name)).netAED;
  }
  return total;
});

/// One CSV-ready cost row per project (used by the accountant export).
class ProjectCostRow {
  const ProjectCostRow({
    required this.projectName,
    required this.cost,
  });
  final String projectName;
  final ProjectCost cost;
}

final projectCostRowsProvider = Provider<List<ProjectCostRow>>((ref) {
  final requests = ref.watch(materialRequestsProvider);
  final names = <String>{for (final r in requests) r.projectName}.toList()
    ..sort();
  return [
    for (final name in names)
      ProjectCostRow(
        projectName: name,
        cost: ref.watch(projectCostProvider(name)),
      ),
  ];
});
