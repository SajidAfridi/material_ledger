import 'package:flutter/material.dart';

import '../../shared/models/material_item.dart';

/// Maps [MaterialCategory] to Flutter icons.
/// Keeps icon dependency out of the model layer.
///
/// Icons optimized for HVAC supply materials.
abstract final class CategoryIcons {
  static IconData icon(MaterialCategory category) {
    return switch (category) {
      MaterialCategory.airInletOutlet => Icons.grid_on_rounded,
      MaterialCategory.supplyGrille => Icons.grid_view_rounded,
      MaterialCategory.returnGrille => Icons.grid_4x4_rounded,
      MaterialCategory.diffusers => Icons.blur_on_rounded,
      MaterialCategory.volumeDamper => Icons.tune_rounded,
      MaterialCategory.fireSmokeDamper => Icons.local_fire_department_rounded,
      MaterialCategory.ducts => Icons.air_rounded,
      MaterialCategory.flexibleDuct => Icons.waves_rounded,
      MaterialCategory.ductAccessories => Icons.settings_input_component_rounded,
      MaterialCategory.sheetMetal => Icons.dashboard_rounded,
      MaterialCategory.fans => Icons.cyclone_rounded,
      MaterialCategory.ductHeaters => Icons.whatshot_rounded,
      MaterialCategory.units => Icons.hvac_rounded,
      MaterialCategory.filters => Icons.filter_alt_rounded,
      MaterialCategory.valves => Icons.toll_rounded,
      MaterialCategory.pipes => Icons.plumbing_rounded,
      MaterialCategory.fittings => Icons.hub_rounded,
      MaterialCategory.copper => Icons.circle_outlined,
      MaterialCategory.refrigerant => Icons.ac_unit_rounded,
      MaterialCategory.insulation => Icons.layers_rounded,
      MaterialCategory.sealants => Icons.opacity_rounded,
      MaterialCategory.supports => Icons.architecture_rounded,
      MaterialCategory.fasteners => Icons.hardware_rounded,
      MaterialCategory.electrical => Icons.electrical_services_rounded,
      MaterialCategory.gauges => Icons.speed_rounded,
      MaterialCategory.tools => Icons.build_rounded,
      MaterialCategory.other => Icons.category_rounded,
    };
  }
}
