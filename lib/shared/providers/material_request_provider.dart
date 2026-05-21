import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_request.dart';
import '../models/project.dart';
import 'language_provider.dart';

const _kRequestsKey = 'material_requests_list_v2';

/// All material requests for the engineer.
final materialRequestsProvider =
    StateNotifierProvider<MaterialRequestsNotifier, List<MaterialRequest>>((
      ref,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return MaterialRequestsNotifier(prefs);
    });

/// Notifier that manages the list of material requests with persistence.
class MaterialRequestsNotifier extends StateNotifier<List<MaterialRequest>> {
  MaterialRequestsNotifier(this._prefs) : super(_loadFromPrefs(_prefs));

  final dynamic _prefs; // SharedPreferences
  static const _uuid = Uuid();

  static List<MaterialRequest> _loadFromPrefs(dynamic prefs) {
    final json = prefs.getString(_kRequestsKey);
    if (json == null || json.isEmpty) return _seedRequests;
    return MaterialRequest.decodeList(json);
  }

  Future<void> _persist() async {
    await _prefs.setString(_kRequestsKey, MaterialRequest.encodeList(state));
  }

  /// Add a new material request (submitted).
  Future<void> addRequest({
    required String projectName,
    required String projectNameSecondary,
    required int itemCount,
    List<RequestLineItem> lineItems = const [],
    RequestPriority priority = RequestPriority.normal,
    String? siteLocation,
    String? notes,
  }) async {
    final request = MaterialRequest(
      id: 'req-${_uuid.v4().substring(0, 8)}',
      projectName: projectName,
      projectNameSecondary: projectNameSecondary,
      status: RequestStatus.pending,
      requestDate: DateTime.now(),
      itemCount: itemCount,
      lineItems: lineItems,
      priority: priority,
      siteLocation: siteLocation,
      notes: notes,
    );
    state = [request, ...state];
    await _persist();
  }

  /// Save a request as draft.
  Future<void> saveDraft({
    required String projectName,
    required String projectNameSecondary,
    required int itemCount,
    List<RequestLineItem> lineItems = const [],
    RequestPriority priority = RequestPriority.normal,
    String? siteLocation,
    String? notes,
  }) async {
    final request = MaterialRequest(
      id: 'req-${_uuid.v4().substring(0, 8)}',
      projectName: projectName,
      projectNameSecondary: projectNameSecondary,
      status: RequestStatus.draft,
      requestDate: DateTime.now(),
      itemCount: itemCount,
      lineItems: lineItems,
      priority: priority,
      siteLocation: siteLocation,
      notes: notes,
    );
    state = [request, ...state];
    await _persist();
  }

  /// Submit a draft request (change status to pending).
  Future<void> submitDraft(String id) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(status: RequestStatus.pending) else r,
    ];
    await _persist();
  }

  /// Remove a request by ID.
  Future<void> removeRequest(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }

  /// Update status of a request.
  Future<void> updateStatus(String id, RequestStatus newStatus) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(status: newStatus) else r,
    ];
    await _persist();
  }
}

/// Count of open (pending + available) requests across all projects —
/// used by the Engineer Dashboard "Open requests" stat tile.
final openRequestCountProvider = Provider<int>((ref) {
  final all = ref.watch(materialRequestsProvider);
  return all
      .where(
        (r) =>
            r.status == RequestStatus.pending ||
            r.status == RequestStatus.available,
      )
      .length;
});

// ─── Seed Data (used on first launch) ───────────────────────────────

final _seedRequests = [
  MaterialRequest(
    id: 'req-001',
    projectName: 'Al-Burj Tower — HVAC Fit-Out',
    projectNameSecondary: 'البرج ٹاور — ایچ وی اے سی',
    status: RequestStatus.pending,
    requestDate: DateTime(2025, 10, 24),
    itemCount: 5,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-001',
        materialName: 'Gate Valve 2" (Brass)',
        materialNameSecondary: 'گیٹ والو 2 انچ (پیتل)',
        quantity: 24,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-010',
        materialName: 'GI Pipe 1" (Schedule 40)',
        materialNameSecondary: 'جی آئی پائپ 1 انچ',
        quantity: 600,
        unitSymbol: 'ft',
      ),
      RequestLineItem(
        materialId: 'mat-020',
        materialName: 'Elbow 90° 1" (GI)',
        materialNameSecondary: 'ایلبو 90 ڈگری 1 انچ',
        quantity: 80,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-030',
        materialName: 'Hex Bolt M10 x 40mm (SS)',
        materialNameSecondary: 'ہیکس بولٹ M10 (سٹینلیس)',
        quantity: 10,
        unitSymbol: 'boxes',
      ),
      RequestLineItem(
        materialId: 'mat-050',
        materialName: 'Pipe Insulation 1" (Armaflex)',
        materialNameSecondary: 'پائپ انسولیشن 1 انچ',
        quantity: 150,
        unitSymbol: 'm',
      ),
    ],
    siteLocation: 'Block A, Floors 12-18',
  ),
  MaterialRequest(
    id: 'req-002',
    projectName: 'Marina Bay Mall — Chiller Plant',
    projectNameSecondary: 'مرینا بے مال — چلر پلانٹ',
    status: RequestStatus.available,
    requestDate: DateTime(2025, 10, 22),
    itemCount: 8,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-003',
        materialName: 'Butterfly Valve 4" (Wafer)',
        materialNameSecondary: 'بٹر فلائی والو 4 انچ',
        quantity: 12,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-014',
        materialName: 'Black Steel Pipe 3" (Sch 40)',
        materialNameSecondary: 'بلیک سٹیل پائپ 3 انچ',
        quantity: 200,
        unitSymbol: 'ft',
      ),
      RequestLineItem(
        materialId: 'mat-023',
        materialName: 'Flange 2" (150# RF)',
        materialNameSecondary: 'فلینج 2 انچ',
        quantity: 24,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-034',
        materialName: 'U-Bolt 2" (GI)',
        materialNameSecondary: 'یو بولٹ 2 انچ',
        quantity: 50,
        unitSymbol: 'pcs',
      ),
    ],
    siteLocation: 'Basement B2, Plant Room',
  ),
  MaterialRequest(
    id: 'req-003',
    projectName: 'Green Valley Hospital — AHU Installation',
    projectNameSecondary: 'گرین ویلی ہسپتال — اے ایچ یو',
    status: RequestStatus.deployed,
    requestDate: DateTime(2025, 10, 19),
    itemCount: 6,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-040',
        materialName: 'GI Duct Sheet 24G (4x8 ft)',
        materialNameSecondary: 'جی آئی ڈکٹ شیٹ 24 گیج',
        quantity: 40,
        unitSymbol: 'sheets',
      ),
      RequestLineItem(
        materialId: 'mat-042',
        materialName: 'Volume Damper 12" (Round)',
        materialNameSecondary: 'والیوم ڈیمپر 12 انچ',
        quantity: 15,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-044',
        materialName: 'Supply Grille 24"x6" (Aluminium)',
        materialNameSecondary: 'سپلائی گرل 24x6 انچ',
        quantity: 30,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-051',
        materialName: 'Duct Insulation Board 25mm',
        materialNameSecondary: 'ڈکٹ انسولیشن بورڈ 25mm',
        quantity: 60,
        unitSymbol: 'sheets',
      ),
    ],
    siteLocation: 'Medical Wing, Floors 1-3',
  ),
  MaterialRequest(
    id: 'req-004',
    projectName: 'Heritage Hotel — Ductwork',
    projectNameSecondary: 'ہیریٹیج ہوٹل — ڈکٹ ورک',
    status: RequestStatus.pending,
    requestDate: DateTime(2025, 10, 25),
    itemCount: 4,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-041',
        materialName: 'Flexible Duct 8" (25ft roll)',
        materialNameSecondary: 'فلیکسبل ڈکٹ 8 انچ',
        quantity: 12,
        unitSymbol: 'rolls',
      ),
      RequestLineItem(
        materialId: 'mat-043',
        materialName: 'Fire Damper 24"x12"',
        materialNameSecondary: 'فائر ڈیمپر',
        quantity: 8,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-045',
        materialName: 'Return Air Diffuser 24"x24"',
        materialNameSecondary: 'ریٹرن ائیر ڈفیوزر',
        quantity: 20,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-036',
        materialName: 'Self-Tapping Screw #10 x 1"',
        materialNameSecondary: 'سیلف ٹیپنگ سکرو',
        quantity: 15,
        unitSymbol: 'boxes',
      ),
    ],
    siteLocation: 'Floors 4-8, Guest Rooms',
  ),
  MaterialRequest(
    id: 'req-005',
    projectName: 'City Centre — Piping & Valves',
    projectNameSecondary: 'سٹی سنٹر — پائپنگ اور والوز',
    status: RequestStatus.available,
    requestDate: DateTime(2025, 10, 20),
    itemCount: 7,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-002',
        materialName: 'Ball Valve 1" (SS 304)',
        materialNameSecondary: 'بال والو 1 انچ (سٹینلیس)',
        quantity: 16,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-012',
        materialName: 'Copper Pipe 3/4" (Type L)',
        materialNameSecondary: 'تانبے کا پائپ 3/4 انچ',
        quantity: 300,
        unitSymbol: 'ft',
      ),
      RequestLineItem(
        materialId: 'mat-070',
        materialName: 'Copper Elbow 3/4" (90°)',
        materialNameSecondary: 'تانبے کی ایلبو 3/4 انچ',
        quantity: 60,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-073',
        materialName: 'Brazing Rod (Silver, 2mm)',
        materialNameSecondary: 'بریزنگ راڈ (سلور)',
        quantity: 5,
        unitSymbol: 'kg',
      ),
    ],
    siteLocation: 'Central Utility Corridor',
  ),
  MaterialRequest(
    id: 'req-006',
    projectName: 'Industrial Zone — Boiler Room',
    projectNameSecondary: 'صنعتی زون — بوائلر روم',
    status: RequestStatus.deployed,
    requestDate: DateTime(2025, 10, 15),
    itemCount: 9,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-005',
        materialName: 'Globe Valve 3" (CI)',
        materialNameSecondary: 'گلوب والو 3 انچ (کاسٹ آئرن)',
        quantity: 6,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-006',
        materialName: 'Pressure Relief Valve 2"',
        materialNameSecondary: 'پریشر ریلیف والو 2 انچ',
        quantity: 4,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-063',
        materialName: 'Pressure Gauge 0-100 PSI',
        materialNameSecondary: 'پریشر گیج',
        quantity: 8,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-060',
        materialName: 'Thermostat (Digital, 24V)',
        materialNameSecondary: 'تھرموسٹیٹ (ڈیجیٹل)',
        quantity: 4,
        unitSymbol: 'pcs',
      ),
    ],
    siteLocation: 'Plant Room, Ground Floor',
  ),
  MaterialRequest(
    id: 'req-007',
    projectName: 'Al-Burj Tower — HVAC Fit-Out',
    projectNameSecondary: 'البرج ٹاور — ایچ وی اے سی',
    status: RequestStatus.rejected,
    requestDate: DateTime(2025, 10, 18),
    itemCount: 3,
    lineItems: const [
      RequestLineItem(
        materialId: 'mat-060',
        materialName: 'Thermostat (Digital, 24V)',
        materialNameSecondary: 'تھرموسٹیٹ (ڈیجیٹل)',
        quantity: 50,
        unitSymbol: 'pcs',
      ),
      RequestLineItem(
        materialId: 'mat-061',
        materialName: 'Contactor 3-Pole 40A',
        materialNameSecondary: 'کنٹیکٹر 3 پول 40A',
        quantity: 25,
        unitSymbol: 'pcs',
      ),
    ],
    siteLocation: 'Floors 1-25',
    notes:
        'Quantities exceed project allocation — resubmit with revised counts',
  ),
];
