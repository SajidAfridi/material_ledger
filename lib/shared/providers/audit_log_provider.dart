import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import 'session_provider.dart';

const _kAuditKey = 'activity_log_v1';
const _uuid = Uuid();

/// The append-only activity log (newest first). Mutating notifiers across every
/// module call `ref.read(auditLogProvider.notifier).log(...)` so the trail
/// captures actor + role + timestamp for each action.
final auditLogProvider =
    StateNotifierProvider<AuditLogNotifier, List<AuditEntry>>((ref) {
      return AuditLogNotifier(
        ref.watch(storageProvider).collection<AuditEntry>(
          _kAuditKey,
          toJson: (e) => e.toJson(),
          fromJson: AuditEntry.fromJson,
        ),
      );
    });

class AuditLogNotifier extends StateNotifier<List<AuditEntry>> {
  AuditLogNotifier(this._store)
    : super(_store.isSeeded ? _store.readAll() : _seed()) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final CollectionStore<AuditEntry> _store;

  Future<void> _persist() => _store.writeAll(state);

  /// Append a new entry. The trail is never edited or deleted from the client.
  Future<void> log({
    required String action,
    required String actorName,
    required UserRole actorRole,
    required AuditModule module,
    String? refId,
    String? detail,
  }) async {
    final entry = AuditEntry(
      id: 'log-${_uuid.v4().substring(0, 8)}',
      action: action,
      actorName: actorName,
      actorRole: actorRole,
      module: module,
      timestamp: DateTime.now(),
      refId: refId,
      detail: detail,
    );
    state = [entry, ...state];
    await _persist();
  }

  /// Entries scoped to a single module (for module-specific trails).
  List<AuditEntry> forModule(AuditModule module) =>
      state.where((e) => e.module == module).toList();

  /// A small, realistic history so the trail isn't empty on first launch.
  static List<AuditEntry> _seed() {
    final base = DateTime.now();
    return [
      AuditEntry(
        id: 'log-seed-03',
        action: 'Plan submitted for approval',
        actorName: 'Ahmed Khan',
        actorRole: UserRole.engineer,
        module: AuditModule.materials,
        timestamp: base.subtract(const Duration(hours: 3)),
        refId: 'proj-001',
        detail: 'Villa 12 — Al Reem · 14 line items',
      ),
      AuditEntry(
        id: 'log-seed-02',
        action: 'Goods received into store',
        actorName: 'Bilal Procurement',
        actorRole: UserRole.procurement,
        module: AuditModule.materials,
        timestamp: base.subtract(const Duration(days: 1, hours: 2)),
        refId: 'grn-204',
        detail: 'Copper pipe 1/2" ×120 @ AED 9.50',
      ),
      AuditEntry(
        id: 'log-seed-01',
        action: 'Rent payment recorded',
        actorName: 'Owner (Admin)',
        actorRole: UserRole.admin,
        module: AuditModule.rentals,
        timestamp: base.subtract(const Duration(days: 2)),
        refId: 'unit-shop-02',
        detail: 'AED 4,500 · SHOP-02 · 2026-06',
      ),
    ];
  }
}

/// One-liner audit logging from any screen. Reads the acting role/name from the
/// session and appends an entry — keeps every call site to a single line and
/// stamps actor + role + timestamp consistently. When real auth lands the
/// actor comes from the signed-in user instead of the dev session.
extension AuditLogX on WidgetRef {
  Future<void> logAudit({
    required String action,
    required AuditModule module,
    String? refId,
    String? detail,
  }) {
    return read(auditLogProvider.notifier).log(
      action: action,
      actorName: read(actorNameProvider),
      actorRole: read(currentRoleProvider),
      module: module,
      refId: refId,
      detail: detail,
    );
  }
}
