import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_dispatch.dart';

/// Real-time material dispatches shown on the Engineer Dashboard.
///
/// In a production build this would stream from a backend.
/// For v1 we expose a curated mock list.
final dispatchesProvider = Provider<List<MaterialDispatch>>((ref) {
  final now = DateTime.now();
  return [
    MaterialDispatch(
      id: 'DISP-8802',
      materialName: 'Steel Girders',
      materialNameSecondary: 'سٹیل گرڈرز',
      quantity: 40,
      unitSymbol: 'pcs',
      status: DispatchStatus.inTransit,
      destination: 'Site Delta (Sector 9)',
      progress: 0.9,
      timestamp: now.subtract(const Duration(minutes: 4)),
    ),
    MaterialDispatch(
      id: 'DISP-8815',
      materialName: 'HVAC Units',
      materialNameSecondary: 'ایچ وی اے سی یونٹس',
      quantity: 5,
      unitSymbol: 'pcs',
      status: DispatchStatus.readyForInspection,
      assignedTo: 'Eng. Rahim Khan',
      note: 'Ready for secondary inspection at loading bay 4.',
      timestamp: now.subtract(const Duration(minutes: 28)),
    ),
    MaterialDispatch(
      id: 'DISP-8821',
      materialName: 'Concrete Mix B-12',
      materialNameSecondary: 'کنکریٹ مکس بی-12',
      quantity: 1,
      unitSymbol: 'load',
      status: DispatchStatus.delayed,
      delayReason: 'Expected delay: 45 minutes due to road closure on M-2.',
      timestamp: now.subtract(const Duration(hours: 1)),
    ),
  ];
});
