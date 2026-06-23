import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_request.dart';
import '../models/project.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'inventory_provider.dart';

const _kRequestsKey = 'material_requests_list_v2';

/// All material requests for the engineer.
final materialRequestsProvider =
    StateNotifierProvider<MaterialRequestsNotifier, List<MaterialRequest>>((
      ref,
    ) {
      return MaterialRequestsNotifier(
        ref,
        ref.watch(storageProvider).collection<MaterialRequest>(
          _kRequestsKey,
          toJson: (r) => r.toJson(),
          fromJson: MaterialRequest.fromJson,
        ),
      );
    });

/// Notifier that manages the list of material requests with persistence.
class MaterialRequestsNotifier extends StateNotifier<List<MaterialRequest>> {
  MaterialRequestsNotifier(this._ref, this._store)
    : super(_store.isSeeded ? _store.readAll() : _seedRequests) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<MaterialRequest> _store;
  static const _uuid = Uuid();

  MaterialsNotifier get _inventory => _ref.read(materialsProvider.notifier);

  /// Reserve stock only for lines that map to a REAL inventory material
  /// (FR-094). Custom / not-yet-stocked items (no matching [MaterialItem]) hold
  /// no reservation — they must be received into inventory before they can be
  /// reserved or dispatched.
  Future<void> _reserveLines(List<RequestLineItem> lines) async {
    for (final l in lines) {
      if (_inventory.byId(l.materialId) == null) continue;
      await _inventory.reserve(l.materialId, l.quantity);
    }
  }

  /// Release reservations for every line that holds one (cancel / supersede).
  /// Only the still-reserved outstanding quantity is freed, and only for real
  /// inventory items — so this never over-releases or touches custom items.
  Future<void> _releaseLines(List<RequestLineItem> lines) async {
    for (final l in lines) {
      if (_inventory.byId(l.materialId) == null) continue;
      await _inventory.release(l.materialId, l.qtyOutstanding);
    }
  }

  Future<void> _persist() => _store.writeAll(state);

  /// Route a request write through the durable outbox so it survives offline,
  /// retries until the server confirms, and can never be duplicated on resend
  /// (idempotent on the client-generated [MaterialRequest.id]). [transactional]
  /// marks writes that move stock/reservations so the backend applies them in an
  /// atomic Firestore transaction.
  Future<void> _sync(
    MaterialRequest r, {
    required String kind,
    required String label,
    bool transactional = false,
  }) {
    return _ref.enqueueSync(
      collection: 'materialRequests',
      docId: r.id,
      kind: kind,
      label: label,
      payload: r.toJson(),
      transactional: transactional,
    );
  }

  /// Add a new material request (submitted). Returns the created request so the
  /// caller can deep-link a notification to it (FR-064).
  Future<MaterialRequest> addRequest({
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
    // Submitting commits the stock — reserve it so it can't be promised twice.
    await _reserveLines(lineItems);
    await _sync(
      request,
      kind: 'request.create',
      label: 'Material request',
      transactional: true, // reserves stock
    );
    return request;
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
    await _sync(request, kind: 'request.draft', label: 'Draft request');
  }

  /// Statuses that are actively holding a stock reservation.
  static const _holdingStatuses = {
    RequestStatus.pending,
    RequestStatus.sourcing,
    RequestStatus.partial,
    RequestStatus.onHold,
    RequestStatus.dispatched,
  };

  MaterialRequest? _byId(String id) {
    for (final r in state) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Submit a draft request (change status to pending) and reserve its stock.
  Future<void> submitDraft(String id) async {
    final req = _byId(id);
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(status: RequestStatus.pending) else r,
    ];
    await _persist();
    if (req != null && req.status == RequestStatus.draft) {
      await _reserveLines(req.lineItems);
    }
    final updated = _byId(id);
    if (updated != null) {
      await _sync(
        updated,
        kind: 'request.submit',
        label: 'Material request',
        transactional: true, // reserves stock
      );
    }
  }

  /// Remove a request by ID, releasing any reservation it still holds.
  Future<void> removeRequest(String id) async {
    final req = _byId(id);
    state = state.where((r) => r.id != id).toList();
    await _persist();
    if (req != null && _holdingStatuses.contains(req.status)) {
      await _releaseLines(req.lineItems);
    }
  }

  /// Update status of a request. Cancelling releases the held reservation.
  Future<void> updateStatus(String id, RequestStatus newStatus) async {
    final req = _byId(id);
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(status: newStatus) else r,
    ];
    await _persist();
    if (req != null &&
        newStatus == RequestStatus.cancelled &&
        _holdingStatuses.contains(req.status)) {
      await _releaseLines(req.lineItems);
    }
    final updated = _byId(id);
    if (updated != null) {
      await _sync(
        updated,
        kind: 'request.status',
        label: 'Material request',
        transactional: newStatus == RequestStatus.cancelled, // releases stock
      );
    }
  }

  /// True when a line's full outstanding quantity is physically on hand and so
  /// can be dispatched. A custom/un-stocked line (no material) or one with less
  /// stock than outstanding is NOT dispatchable — the shortfall must be arranged
  /// (restocked) or the engineer must reduce the request first.
  bool canDispatchLine(RequestLineItem line) {
    if (line.qtyOutstanding <= 0) return false;
    final item = _inventory.byId(line.materialId);
    return item != null && item.quantity >= line.qtyOutstanding;
  }

  /// Procurement dispatches a request to site. Stock physically leaves the store
  /// here: on-hand decrements and the matching reservation is freed for the
  /// dispatched quantity. A request can be fulfilled across several dispatches
  /// (some lines now, others once arranged), so it lands in `partial` until
  /// every line is out.
  ///
  /// IMPORTANT — a line is all-or-nothing against availability: it ships only
  /// when the full outstanding quantity is on hand (see [canDispatchLine]). We
  /// never ship a short quantity for an under-stocked line; that shortfall must
  /// be arranged or the engineer must edit the request down. [dispatchByIndex]
  /// is the quantity per line; omit/short to default each line to its
  /// outstanding quantity.
  Future<void> dispatch(String id, [List<double>? dispatchByIndex]) async {
    final req = _byId(id);
    if (req == null) return;

    var movedAny = false;
    final newLines = <RequestLineItem>[];
    for (var i = 0; i < req.lineItems.length; i++) {
      final line = req.lineItems[i];
      final item = _inventory.byId(line.materialId);
      var requested = (dispatchByIndex != null && i < dispatchByIndex.length)
          ? dispatchByIndex[i]
          : line.qtyOutstanding;
      requested = requested.clamp(0, line.qtyOutstanding).toDouble();

      double d;
      if (item == null || item.quantity < line.qtyOutstanding) {
        // Blocked: not stocked, or not enough on hand to cover the full
        // outstanding qty. Never ship a short line — leave it outstanding.
        d = 0;
      } else {
        // Fully available — ship what's asked (≤ outstanding ≤ on-hand).
        d = requested;
      }
      if (d > 0) {
        await _inventory.adjustQuantity(line.materialId, -d); // leave the store
        await _inventory.release(line.materialId, d); // free that reservation
        movedAny = true;
      }
      newLines.add(
        line.copyWith(qtyDispatched: (line.qtyDispatched ?? 0) + d),
      );
    }

    // Nothing could be dispatched (every line blocked) → leave the request as
    // it was so it stays in the queue; don't fake a "partial".
    if (!movedAny) return;

    final fullyDispatched =
        newLines.every((l) => (l.qtyDispatched ?? 0) >= l.quantity);
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(
            status: fullyDispatched
                ? RequestStatus.dispatched
                : RequestStatus.partial,
            lineItems: newLines,
          )
        else
          r,
    ];
    await _persist();
    final updated = _byId(id);
    if (updated != null) {
      // Stock physically left the store — atomic (transactional). Coalescing on
      // docId means repeated partial dispatches sync the latest cumulative state
      // without duplicating or losing any.
      await _sync(
        updated,
        kind: 'request.dispatch',
        label: 'Dispatch',
        transactional: true,
      );
    }
  }

  /// Re-point a request line from a custom/placeholder material id onto a REAL
  /// inventory material that procurement just created & stocked, then reserve the
  /// outstanding quantity. After this the line is a normal, dispatchable item.
  Future<void> relinkLine(
    String requestId,
    String oldMaterialId, {
    required String newMaterialId,
    required String newName,
  }) async {
    final req = _byId(requestId);
    if (req == null) return;
    RequestLineItem? relinked;
    final newLines = <RequestLineItem>[];
    for (final l in req.lineItems) {
      if (l.materialId == oldMaterialId) {
        final nl = l.copyWith(materialId: newMaterialId, materialName: newName);
        relinked = nl;
        newLines.add(nl);
      } else {
        newLines.add(l);
      }
    }
    if (relinked == null) return;
    state = [
      for (final r in state)
        if (r.id == requestId) r.copyWith(lineItems: newLines) else r,
    ];
    await _persist();
    // Reserve the now-real material for what's still outstanding on this line.
    await _inventory.reserve(newMaterialId, relinked.qtyOutstanding);
    final updated = _byId(requestId);
    if (updated != null) {
      await _sync(
        updated,
        kind: 'request.relink',
        label: 'Material request',
        transactional: true,
      );
    }
  }

  /// Append a comment to a request's discussion thread (engineer ↔ procurement).
  Future<void> addRequestComment(
    String id, {
    required String text,
    required String authorName,
    required String authorRole,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final comment = RequestComment(
      authorName: authorName,
      authorRole: authorRole,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(comments: [...r.comments, comment])
        else
          r,
    ];
    await _persist();
    final updated = _byId(id);
    if (updated != null) {
      await _sync(updated, kind: 'request.comment', label: 'Material request');
    }
  }

  /// Engineer edits an outstanding line's quantity (e.g. reduce to what's
  /// available). Never below what's already been dispatched. The reservation is
  /// adjusted by the delta so stock promises stay accurate.
  Future<void> updateRequestLine(
    String id,
    String materialId,
    double newQuantity,
  ) async {
    final req = _byId(id);
    if (req == null) return;
    final newLines = <RequestLineItem>[];
    for (final l in req.lineItems) {
      if (l.materialId == materialId) {
        final dispatched = l.qtyDispatched ?? 0;
        final q = newQuantity.clamp(dispatched, double.infinity).toDouble();
        final delta = l.quantity - q; // > 0 means reduced
        if (delta != 0 && _inventory.byId(materialId) != null) {
          if (delta > 0) {
            await _inventory.release(materialId, delta);
          } else {
            await _inventory.reserve(materialId, -delta);
          }
        }
        newLines.add(l.copyWith(quantity: q));
      } else {
        newLines.add(l);
      }
    }
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(lineItems: newLines) else r,
    ];
    await _persist();
    final updated = _byId(id);
    if (updated != null) {
      await _sync(
        updated,
        kind: 'request.edit',
        label: 'Material request',
        transactional: true, // adjusts reservation
      );
    }
  }

  /// Engineer drops a line from the request entirely, releasing its remaining
  /// reservation.
  Future<void> removeRequestLine(String id, String materialId) async {
    final req = _byId(id);
    if (req == null) return;
    RequestLineItem? target;
    for (final l in req.lineItems) {
      if (l.materialId == materialId) {
        target = l;
        break;
      }
    }
    if (target == null) return;
    final newLines = req.lineItems
        .where((l) => l.materialId != materialId)
        .toList();
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(lineItems: newLines, itemCount: newLines.length)
        else
          r,
    ];
    await _persist();
    if (_holdingStatuses.contains(req.status) &&
        _inventory.byId(materialId) != null) {
      await _inventory.release(materialId, target.qtyOutstanding);
    }
    final updated = _byId(id);
    if (updated != null) {
      await _sync(
        updated,
        kind: 'request.edit',
        label: 'Material request',
        transactional: true, // releases reservation
      );
    }
  }

  /// Procurement puts a request on hold with a note (FR). Reservation stays.
  Future<void> putOnHold(String id, String note) async {
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(
            status: RequestStatus.onHold,
            notes: note.trim().isEmpty ? r.notes : note.trim(),
          )
        else
          r,
    ];
    await _persist();
    final updated = _byId(id);
    if (updated != null) {
      await _sync(updated, kind: 'request.hold', label: 'Material request');
    }
  }

  /// Engineer confirms on-site receipt, recording the quantity actually
  /// received per line and flagging any shortfall (FR-088/FR-089). Stock and
  /// reservation were already settled at dispatch, so this only records.
  Future<void> confirmReceipt(String id, List<double> receivedByIndex) async {
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(
            status: RequestStatus.received,
            confirmedReceiptAt: DateTime.now(),
            lineItems: [
              for (var i = 0; i < r.lineItems.length; i++)
                r.lineItems[i].copyWith(
                  qtyReceived: i < receivedByIndex.length
                      ? receivedByIndex[i]
                      : r.lineItems[i].quantity,
                ),
            ],
          )
        else
          r,
    ];
    await _persist();
    final updated = _byId(id);
    if (updated != null) {
      // Records the on-site receipt only (stock already settled at dispatch).
      await _sync(updated, kind: 'request.receipt', label: 'Receipt confirmed');
    }
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
            r.status == RequestStatus.sourcing ||
            r.status == RequestStatus.partial ||
            r.status == RequestStatus.onHold ||
            r.status == RequestStatus.dispatched,
      )
      .length;
});

/// Statuses that put a request in procurement's dispatch queue (the same set
/// the procurement workspace lists). Single source of truth for the count.
const dispatchQueueStatuses = {
  RequestStatus.pending,
  RequestStatus.sourcing,
  RequestStatus.partial,
  RequestStatus.onHold,
};

/// Requests waiting on procurement to dispatch — drives the Home "Awaiting you"
/// KPI and the Materials-hub Procurement badge.
final dispatchQueueCountProvider = Provider<int>((ref) {
  return ref
      .watch(materialRequestsProvider)
      .where((r) => dispatchQueueStatuses.contains(r.status))
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
    status: RequestStatus.dispatched,
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
    status: RequestStatus.received,
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
    status: RequestStatus.dispatched,
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
    status: RequestStatus.received,
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
    status: RequestStatus.cancelled,
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
