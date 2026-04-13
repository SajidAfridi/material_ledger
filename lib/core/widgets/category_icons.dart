import 'package:flutter/material.dart';

import '../../shared/models/material_item.dart';

/// Maps [MaterialCategory] to Flutter icons.
/// Keeps icon dependency out of the model layer.
///
/// Icons optimized for HVAC supply materials.
abstract final class CategoryIcons {
  static IconData icon(MaterialCategory category) {
    return switch (category) {
      MaterialCategory.valves => Icons.toll_rounded,
      MaterialCategory.pipes => Icons.plumbing_rounded,
      MaterialCategory.fittings => Icons.hub_rounded,
      MaterialCategory.fasteners => Icons.hardware_rounded,
      MaterialCategory.ducts => Icons.air_rounded,
      MaterialCategory.insulation => Icons.layers_rounded,
      MaterialCategory.electrical => Icons.electrical_services_rounded,
      MaterialCategory.copper => Icons.circle_outlined,
      MaterialCategory.tools => Icons.build_rounded,
      MaterialCategory.other => Icons.category_rounded,
    };
  }
}
