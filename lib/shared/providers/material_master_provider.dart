import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import '../models/material_master.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'audit_log_provider.dart';
import 'session_provider.dart';

const _categoriesKey = 'material_categories_v1';
const _unitsKey = 'material_units_v1';
const _uuid = Uuid();

final materialCategoriesProvider =
    StateNotifierProvider<
      MaterialCategoriesNotifier,
      List<MaterialCategoryMaster>
    >((ref) {
      return MaterialCategoriesNotifier(
        ref,
        ref
            .watch(storageProvider)
            .collection<MaterialCategoryMaster>(
              _categoriesKey,
              toJson: (value) => value.toJson(),
              fromJson: MaterialCategoryMaster.fromJson,
            ),
      );
    });

final materialUnitsProvider =
    StateNotifierProvider<MaterialUnitsNotifier, List<MaterialUnitMaster>>((
      ref,
    ) {
      return MaterialUnitsNotifier(
        ref,
        ref
            .watch(storageProvider)
            .collection<MaterialUnitMaster>(
              _unitsKey,
              toJson: (value) => value.toJson(),
              fromJson: MaterialUnitMaster.fromJson,
            ),
      );
    });

final activeMaterialCategoriesProvider = Provider<List<MaterialCategoryMaster>>(
  (ref) {
    return [
      for (final category in ref.watch(materialCategoriesProvider))
        if (!category.archived) category,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  },
);

final selectableMaterialUnitsProvider = Provider<List<MaterialUnitMaster>>((
  ref,
) {
  return [
    for (final unit in ref.watch(materialUnitsProvider))
      if (unit.isSelectable) unit,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

List<T> _mergeSeeds<T>(
  List<T> seeds,
  List<T> stored,
  String Function(T value) idOf,
) {
  final byId = <String, T>{for (final value in seeds) idOf(value): value};
  for (final value in stored) {
    byId[idOf(value)] = value;
  }
  return byId.values.toList();
}

mixin _MasterAudit {
  Ref get ref;

  void requireAdmin() {
    if (ref.read(currentRoleProvider) != UserRole.admin) {
      throw StateError('Only Admin can change material master data.');
    }
  }

  Future<void> audit(String action, String id, String detail) {
    return ref
        .read(auditLogProvider.notifier)
        .log(
          action: action,
          actorName: ref.read(actorNameProvider),
          actorRole: ref.read(currentRoleProvider),
          module: AuditModule.materials,
          refId: id,
          detail: detail,
        );
  }
}

class MaterialCategoriesNotifier
    extends StateNotifier<List<MaterialCategoryMaster>>
    with _MasterAudit {
  MaterialCategoriesNotifier(this.ref, this._store)
    : super(
        _mergeSeeds(
          _categorySeeds,
          _store.isSeeded ? _store.readAll() : const [],
          (value) => value.id,
        ),
      ) {
    _store.writeAll(state);
  }

  @override
  final Ref ref;
  final CollectionStore<MaterialCategoryMaster> _store;

  Future<void> _save(MaterialCategoryMaster value, String kind) async {
    state = [
      for (final item in state)
        if (item.id == value.id) value else item,
    ];
    await _store.writeAll(state);
    await ref.enqueueSync(
      collection: 'materialCategories',
      docId: value.id,
      kind: kind,
      label: 'Material category',
      payload: value.toJson(),
    );
  }

  Future<String> add({required String name, String secondaryName = ''}) async {
    requireAdmin();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
    if (state.any(
      (item) =>
          item.name.toLowerCase() == trimmed.toLowerCase() && !item.archived,
    )) {
      throw StateError('An active category with this name already exists.');
    }
    final value = MaterialCategoryMaster(
      id: 'cat-${_uuid.v4()}',
      name: trimmed,
      secondaryName: secondaryName.trim(),
      sortOrder: state.length + 100,
      isCustom: true,
      updatedAt: DateTime.now(),
      updatedBy: ref.read(actorNameProvider),
    );
    state = [...state, value];
    await _store.writeAll(state);
    await ref.enqueueSync(
      collection: 'materialCategories',
      docId: value.id,
      kind: 'material-category.create',
      label: 'Material category',
      payload: value.toJson(),
    );
    await audit('Material category created', value.id, value.name);
    return value.id;
  }

  Future<void> update(
    String id, {
    required String name,
    String secondaryName = '',
  }) async {
    requireAdmin();
    final current = byId(id);
    if (current == null) return;
    final next = current.copyWith(
      name: name.trim(),
      secondaryName: secondaryName.trim(),
      updatedBy: ref.read(actorNameProvider),
    );
    await _save(next, 'material-category.update');
    await audit('Material category updated', id, next.name);
  }

  Future<void> setArchived(String id, bool archived) async {
    requireAdmin();
    final current = byId(id);
    if (current == null) return;
    final next = current.copyWith(
      archived: archived,
      updatedBy: ref.read(actorNameProvider),
    );
    await _save(next, 'material-category.archive');
    await audit(
      archived ? 'Material category archived' : 'Material category restored',
      id,
      current.name,
    );
  }

  MaterialCategoryMaster? byId(String id) {
    for (final value in state) {
      if (value.id == id) return value;
    }
    return null;
  }
}

class MaterialUnitsNotifier extends StateNotifier<List<MaterialUnitMaster>>
    with _MasterAudit {
  MaterialUnitsNotifier(this.ref, this._store)
    : super(
        _mergeSeeds(
          _unitSeeds,
          _store.isSeeded ? _store.readAll() : const [],
          (value) => value.id,
        ),
      ) {
    _store.writeAll(state);
  }

  @override
  final Ref ref;
  final CollectionStore<MaterialUnitMaster> _store;

  Future<void> _save(MaterialUnitMaster value, String kind) async {
    state = [
      for (final item in state)
        if (item.id == value.id) value else item,
    ];
    await _store.writeAll(state);
    await ref.enqueueSync(
      collection: 'materialUnits',
      docId: value.id,
      kind: kind,
      label: 'Material unit',
      payload: value.toJson(),
    );
  }

  /// Admin-created units are approved immediately; Procurement proposals remain
  /// pending until Admin explicitly approves them.
  Future<String> add({
    required String name,
    required String symbol,
    String secondaryName = '',
  }) async {
    final role = ref.read(currentRoleProvider);
    if (role == UserRole.engineer) {
      throw StateError('Engineers cannot change material master data.');
    }
    final cleanName = name.trim();
    final cleanSymbol = symbol.trim();
    if (cleanName.isEmpty || cleanSymbol.isEmpty) {
      throw ArgumentError('Unit name and symbol are required.');
    }
    final existing = state.where(
      (unit) => unit.symbol.toLowerCase() == cleanSymbol.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first.id;
    final value = MaterialUnitMaster(
      id: 'custom-unit-${_uuid.v4()}',
      name: cleanName,
      symbol: cleanSymbol,
      secondaryName: secondaryName.trim(),
      sortOrder: state.length + 100,
      isCustom: true,
      status: role.isAdmin
          ? UnitReviewStatus.approved
          : UnitReviewStatus.pendingReview,
      updatedAt: DateTime.now(),
      updatedBy: ref.read(actorNameProvider),
    );
    state = [...state, value];
    await _store.writeAll(state);
    await ref.enqueueSync(
      collection: 'materialUnits',
      docId: value.id,
      kind: 'material-unit.create',
      label: 'Material unit',
      payload: value.toJson(),
    );
    await audit(
      role.isAdmin ? 'Material unit created' : 'Material unit proposed',
      value.id,
      '${value.name} (${value.symbol})',
    );
    return value.id;
  }

  Future<void> update(
    String id, {
    required String name,
    required String symbol,
    String secondaryName = '',
  }) async {
    requireAdmin();
    final current = byId(id);
    if (current == null) return;
    final next = current.copyWith(
      name: name.trim(),
      symbol: symbol.trim(),
      secondaryName: secondaryName.trim(),
      updatedBy: ref.read(actorNameProvider),
    );
    await _save(next, 'material-unit.update');
    await audit('Material unit updated', id, '${next.name} (${next.symbol})');
  }

  Future<void> setStatus(String id, UnitReviewStatus status) async {
    requireAdmin();
    final current = byId(id);
    if (current == null) return;
    final next = current.copyWith(
      status: status,
      updatedBy: ref.read(actorNameProvider),
    );
    await _save(next, 'material-unit.status');
    final action = switch (status) {
      UnitReviewStatus.approved => 'Material unit approved',
      UnitReviewStatus.pendingReview => 'Material unit returned for review',
      UnitReviewStatus.archived => 'Material unit archived',
    };
    await audit(action, id, '${current.name} (${current.symbol})');
  }

  MaterialUnitMaster? byId(String id) {
    for (final value in state) {
      if (value.id == id) return value;
    }
    return null;
  }
}

final _seededAt = DateTime.utc(2026, 7, 24);

final _categorySeeds = <MaterialCategoryMaster>[
  for (final entry in const [
    ('cat-air-terminals', 'Air Terminals', 'ہوا کے ٹرمینلز'),
    (
      'cat-dampers-fire-control',
      'Dampers & Fire Control',
      'ڈیمپرز اور فائر کنٹرول',
    ),
    ('cat-fans-equipment', 'Fans & Equipment', 'پنکھے اور آلات'),
    (
      'cat-ductwork-accessories',
      'Ductwork & Accessories',
      'ڈکٹ ورک اور لوازمات',
    ),
    ('cat-piping-drain', 'Piping & Drain', 'پائپنگ اور ڈرین'),
    (
      'cat-electrical-controls',
      'Electrical & Controls',
      'الیکٹریکل اور کنٹرولز',
    ),
    ('cat-supports-insulation', 'Supports & Insulation', 'سپورٹس اور انسولیشن'),
    ('cat-general-custom', 'General & Custom', 'عام اور کسٹم'),
  ].indexed)
    MaterialCategoryMaster(
      id: entry.$2.$1,
      name: entry.$2.$2,
      secondaryName: entry.$2.$3,
      sortOrder: entry.$1,
      updatedAt: _seededAt,
      updatedBy: 'V7 migration',
    ),
];

final _unitSeeds = <MaterialUnitMaster>[
  for (final entry in const [
    ('unit-nos', 'Nos', 'Nos', 'عدد'),
    ('unit-meter', 'Meter', 'm', 'میٹر'),
    ('unit-cm', 'Centimeter', 'cm', 'سینٹی میٹر'),
    ('unit-length', 'Length', 'Length', 'لمبائی'),
    ('unit-set', 'Set', 'Set', 'سیٹ'),
    ('unit-pairs', 'Pairs', 'Pairs', 'جوڑے'),
    ('unit-roll', 'Roll', 'Roll', 'رول'),
    ('unit-box', 'Box', 'Box', 'ڈبہ'),
    ('unit-ton', 'Ton', 'Ton', 'ٹن'),
    ('unit-boxes', 'Boxes', 'Boxes', 'ڈبے'),
  ].indexed)
    MaterialUnitMaster(
      id: entry.$2.$1,
      name: entry.$2.$2,
      symbol: entry.$2.$3,
      secondaryName: entry.$2.$4,
      sortOrder: entry.$1,
      status: UnitReviewStatus.approved,
      updatedAt: _seededAt,
      updatedBy: 'V7 migration',
    ),
  for (final entry in const [
    ('kg', 'Kilograms'),
    ('tons', 'Tons'),
    ('bags', 'Bags'),
    ('sqft', 'Square Feet'),
    ('L', 'Liters'),
    ('m³', 'Cubic Meters'),
    ('rods', 'Rods'),
    ('sheets', 'Sheets'),
    ('ft', 'Feet'),
    ('in', 'Inches'),
  ].indexed)
    MaterialUnitMaster(
      id: unitMasterIdForLegacySymbol(entry.$2.$1),
      name: entry.$2.$2,
      symbol: entry.$2.$1,
      sortOrder: 100 + entry.$1,
      isCustom: true,
      status: UnitReviewStatus.pendingReview,
      updatedAt: _seededAt,
      updatedBy: 'Legacy migration',
    ),
];
