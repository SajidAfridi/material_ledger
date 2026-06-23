import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/rent_payment.dart';
import '../models/rental_unit.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';

const _kRentalUnitsKey = 'rental_units_v1';
const _kRentPaymentsKey = 'rent_payments_v1';
const _uuid = Uuid();

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ─── Rental Units ────────────────────────────────────────────────

final rentalUnitsProvider =
    StateNotifierProvider<RentalUnitsNotifier, List<RentalUnit>>((ref) {
      return RentalUnitsNotifier(
        ref,
        ref.watch(storageProvider).collection<RentalUnit>(
          _kRentalUnitsKey,
          toJson: (u) => u.toJson(),
          fromJson: RentalUnit.fromJson,
        ),
      );
    });

class RentalUnitsNotifier extends StateNotifier<List<RentalUnit>> {
  RentalUnitsNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seedUnits();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<RentalUnit> _store;

  RentalUnit? byId(String id) {
    for (final u in state) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<RentalUnit> addUnit({
    required String unitName,
    required RentalType type,
    required String location,
    required double monthlyRentAED,
    String? tenantName,
    String? tenantContact,
    DateTime? leaseStart,
    DateTime? leaseEnd,
    String? notes,
    required String createdBy,
  }) async {
    final occupied = (tenantName ?? '').trim().isNotEmpty;
    final unit = RentalUnit(
      id: 'unit-${_uuid.v4().substring(0, 8)}',
      unitName: unitName,
      type: type,
      location: location,
      monthlyRentAED: monthlyRentAED,
      tenantName: tenantName,
      tenantContact: tenantContact,
      leaseStart: leaseStart,
      leaseEnd: leaseEnd,
      status: occupied ? RentalStatus.active : RentalStatus.vacant,
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    state = [unit, ...state];
    await _store.writeAll(state);
    await _syncUnit(unit, kind: 'rentalUnit.create');
    return unit;
  }

  Future<void> updateUnit(RentalUnit updated) async {
    state = [
      for (final u in state)
        if (u.id == updated.id) updated else u,
    ];
    await _store.writeAll(state);
    await _syncUnit(updated, kind: 'rentalUnit.update');
  }

  Future<void> _syncUnit(RentalUnit u, {required String kind}) {
    return _ref.enqueueSync(
      collection: 'rentalUnits',
      docId: u.id,
      kind: kind,
      label: 'Rental unit',
      payload: u.toJson(),
    );
  }

  static List<RentalUnit> _seedUnits() {
    final now = DateTime.now();
    return [
      RentalUnit(
        id: 'unit-shop-01',
        unitName: 'SHOP-01',
        type: RentalType.shop,
        location: 'Mussafah M-9, Shop 1',
        monthlyRentAED: 3800,
        tenantName: 'Al Noor Spare Parts',
        tenantContact: '+971 50 123 4567',
        leaseStart: DateTime(now.year - 1, 3, 1),
        leaseEnd: DateTime(now.year + 1, 2, 28),
        status: RentalStatus.active,
        createdBy: 'Owner (Admin)',
        createdAt: DateTime(now.year - 1, 2, 20),
      ),
      RentalUnit(
        id: 'unit-shop-02',
        unitName: 'SHOP-02',
        type: RentalType.shop,
        location: 'Mussafah M-9, Shop 2',
        monthlyRentAED: 4500,
        tenantName: 'Gulf Tyres & Service',
        tenantContact: '+971 55 987 6543',
        leaseStart: DateTime(now.year - 1, 6, 1),
        leaseEnd: DateTime(now.year + 1, 5, 31),
        status: RentalStatus.active,
        createdBy: 'Owner (Admin)',
        createdAt: DateTime(now.year - 1, 5, 25),
      ),
      RentalUnit(
        id: 'unit-ws-01',
        unitName: 'WORKSHOP-A',
        type: RentalType.workshop,
        location: 'Mussafah M-11, Workshop A',
        monthlyRentAED: 9000,
        status: RentalStatus.vacant,
        createdBy: 'Owner (Admin)',
        createdAt: DateTime(now.year - 1, 1, 10),
        notes: 'Available — last tenant lease ended.',
      ),
    ];
  }
}

// ─── Rent Payments ───────────────────────────────────────────────

final rentPaymentsProvider =
    StateNotifierProvider<RentPaymentsNotifier, List<RentPayment>>((ref) {
      return RentPaymentsNotifier(
        ref,
        ref.watch(storageProvider).collection<RentPayment>(
          _kRentPaymentsKey,
          toJson: (p) => p.toJson(),
          fromJson: RentPayment.fromJson,
        ),
      );
    });

class RentPaymentsNotifier extends StateNotifier<List<RentPayment>> {
  RentPaymentsNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seedPayments();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<RentPayment> _store;

  List<RentPayment> forUnit(String unitId) =>
      state.where((p) => p.unitId == unitId).toList()
        ..sort((a, b) => b.periodMonth.compareTo(a.periodMonth));

  /// Record (or top up) a payment for a unit + billing month. If a record for
  /// that period exists, the paid amount is increased; otherwise a new record
  /// is created. Returns the resulting payment.
  Future<RentPayment> recordPayment({
    required String unitId,
    required String periodMonth,
    required double amountDueAED,
    required double amountPaidAED,
    String? method,
    String? note,
    required String recordedBy,
  }) async {
    final idx = state.indexWhere(
      (p) => p.unitId == unitId && p.periodMonth == periodMonth && !p.isVoided,
    );
    late RentPayment result;
    if (idx >= 0) {
      // Top up: accumulate the paid amount but PRESERVE the period's original
      // total due — re-recording must never reset/double the charge. The new
      // [amountDueAED] only matters when creating a fresh period record below.
      result = state[idx].copyWith(
        amountPaidAED: state[idx].amountPaidAED + amountPaidAED,
        paidDate: DateTime.now(),
        method: method,
        note: note,
      );
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx) result else state[i],
      ];
    } else {
      result = RentPayment(
        id: 'rent-${_uuid.v4().substring(0, 8)}',
        unitId: unitId,
        periodMonth: periodMonth,
        amountDueAED: amountDueAED,
        amountPaidAED: amountPaidAED,
        paidDate: DateTime.now(),
        method: method,
        note: note,
        recordedBy: recordedBy,
        recordedAt: DateTime.now(),
      );
      state = [result, ...state];
    }
    await _store.writeAll(state);
    // Money movement / balance change → transactional (atomic on the server).
    await _ref.enqueueSync(
      collection: 'rentPayments',
      docId: result.id,
      kind: 'rentPayment.record',
      label: 'Rent payment',
      payload: result.toJson(),
      transactional: true,
    );
    return result;
  }

  /// Void a payment record (a correction). It's kept in history for the audit
  /// trail but excluded from all balances; recording again for the same period
  /// then creates a fresh record.
  Future<void> voidPayment(String id, {required String reason}) async {
    final now = DateTime.now();
    RentPayment? voided;
    state = [
      for (final p in state)
        if (p.id == id && !p.isVoided)
          voided = p.copyWith(voidedAt: now, voidReason: reason.trim())
        else
          p,
    ];
    if (voided == null) return;
    await _store.writeAll(state);
    await _ref.enqueueSync(
      collection: 'rentPayments',
      docId: voided.id,
      kind: 'rentPayment.void',
      label: 'Rent payment',
      payload: voided.toJson(),
      transactional: true,
    );
  }

  static List<RentPayment> _seedPayments() {
    final now = DateTime.now();
    final thisMonth = _monthKey(now);
    final prev = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    final lastMonth = _monthKey(prev);
    return [
      // SHOP-01 paid this month.
      RentPayment(
        id: 'rent-seed-01',
        unitId: 'unit-shop-01',
        periodMonth: thisMonth,
        amountDueAED: 3800,
        amountPaidAED: 3800,
        paidDate: now.subtract(const Duration(days: 4)),
        method: 'Bank transfer',
        recordedBy: 'Owner (Admin)',
        recordedAt: now.subtract(const Duration(days: 4)),
      ),
      // SHOP-02 due this month (nothing paid yet).
      RentPayment(
        id: 'rent-seed-02',
        unitId: 'unit-shop-02',
        periodMonth: thisMonth,
        amountDueAED: 4500,
        amountPaidAED: 0,
        recordedBy: 'Owner (Admin)',
        recordedAt: now.subtract(const Duration(days: 2)),
      ),
      // SHOP-02 last month unpaid → overdue.
      RentPayment(
        id: 'rent-seed-03',
        unitId: 'unit-shop-02',
        periodMonth: lastMonth,
        amountDueAED: 4500,
        amountPaidAED: 0,
        recordedBy: 'Owner (Admin)',
        recordedAt: prev,
      ),
    ];
  }
}

// ─── Derived: per-unit current status ────────────────────────────

/// The current-month rent status for a unit (Paid/Due/Overdue/Partial).
final unitRentStatusProvider = Provider.family<RentStatus, String>((
  ref,
  unitId,
) {
  final payments = ref.watch(rentPaymentsProvider);
  final now = DateTime.now();
  final thisMonth = _monthKey(now);

  // Any unpaid past period makes the unit overdue.
  for (final p in payments) {
    if (p.unitId != unitId || p.isVoided) continue;
    if (p.statusAsOf(now) == RentStatus.overdue) return RentStatus.overdue;
  }
  // Otherwise reflect this month's record.
  for (final p in payments) {
    if (p.unitId == unitId && p.periodMonth == thisMonth && !p.isVoided) {
      return p.statusAsOf(now);
    }
  }
  return RentStatus.due;
});

// ─── Derived: dashboard summary ──────────────────────────────────

class RentalsSummary {
  const RentalsSummary({
    required this.totalUnits,
    required this.occupied,
    required this.vacant,
    required this.monthlyRentRoll,
    required this.collectedThisMonth,
    required this.overdueTotal,
  });

  final int totalUnits;
  final int occupied;
  final int vacant;
  final double monthlyRentRoll;
  final double collectedThisMonth;
  final double overdueTotal;
}

final rentalsSummaryProvider = Provider<RentalsSummary>((ref) {
  final units = ref.watch(rentalUnitsProvider);
  final payments = ref.watch(rentPaymentsProvider);
  final now = DateTime.now();
  final thisMonth = _monthKey(now);

  final rentRoll = units
      .where((u) => u.isOccupied)
      .fold(0.0, (s, u) => s + u.monthlyRentAED);

  var collected = 0.0;
  var overdue = 0.0;
  for (final p in payments) {
    if (p.isVoided) continue;
    if (p.periodMonth == thisMonth) collected += p.amountPaidAED;
    if (p.statusAsOf(now) == RentStatus.overdue) overdue += p.outstandingAED;
  }

  return RentalsSummary(
    totalUnits: units.length,
    occupied: units.where((u) => u.isOccupied).length,
    vacant: units.where((u) => !u.isOccupied).length,
    monthlyRentRoll: rentRoll,
    collectedThisMonth: collected,
    overdueTotal: overdue,
  );
});

/// Current billing month key (`YYYY-MM`) for record-payment defaults.
String currentRentMonthKey() => _monthKey(DateTime.now());
