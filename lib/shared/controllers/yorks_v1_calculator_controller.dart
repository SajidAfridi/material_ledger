import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/yorks_v1_calculator_workspace.dart';
import '../repositories/yorks_v1_calculator_repository.dart';

class YorksCalculatorController extends ChangeNotifier {
  YorksCalculatorController(
    this.repository, {
    this.preferences,
    required this.identity,
  });
  final YorksCalculatorRepository repository;
  final SharedPreferences? preferences;
  final String identity;
  List<YorksCalculatorRecord> items = [];
  Map<String, dynamic> options = {};
  YorksCalculatorRecord? record;
  bool loading = false,
      busy = false,
      canCreate = false,
      canManage = false,
      hasMore = false,
      denied = false;
  String search = '', kind = 'all', scope = 'all';
  bool archived = false;
  Object? error;
  Map<String, dynamic>? _pending;
  int _generation = 0;
  bool _disposed = false;
  String get _key => 'yorks_calculator_pending_v1_$identity';
  bool get hasPending => _pending != null;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.list(
        search: search,
        offset: more ? items.length : 0,
        archived: archived,
        kind: kind,
        scope: scope,
      );
      if (_disposed || generation != _generation) return;
      final rows = (result['items'] as List)
          .map(
            (e) => YorksCalculatorRecord(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      items = [if (more) ...items, ...rows];
      hasMore = rows.length == 50;
      canCreate = result['can_create'] == true;
      canManage = result['can_manage'] == true;
    } catch (e) {
      if (generation == _generation) {
        error = e;
        items = [];
        canCreate = false;
        canManage = false;
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> open(String id) async {
    busy = true;
    error = null;
    record = null;
    denied = false;
    notifyListeners();
    try {
      final result = await repository.get(id);
      if (!_disposed) record = result;
    } catch (e) {
      if (!_disposed) {
        error = e;
        denied = e.toString().contains('ACCESS_DENIED');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadOptions() async {
    try {
      options = await repository.options();
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> checkAccess() async {
    final old = record;
    if (old == null || busy) return;
    try {
      final latest = await repository.get(old.id);
      if (_disposed || record?.id != old.id) return;
      // Refresh permissions only. The editor owns an explicit loaded revision;
      // never replace unsaved inputs or pretend a changed version was loaded.
      record = YorksCalculatorRecord({
        ...old.json,
        'can_edit': latest.canEdit,
        'can_manage': latest.canManage,
        'archived': latest.archived,
      });
      denied = false;
      error = null;
    } catch (e) {
      if (record?.id == old.id) {
        denied = e.toString().contains('ACCESS_DENIED');
        error = e;
      }
    }
    notifyListeners();
  }

  Future<YorksCalculatorRecord?> save(Map<String, dynamic> payload) async {
    if (busy || denied) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      _pending ??= {
        'payload': jsonDecode(jsonEncode(payload)),
        'key': const Uuid().v4(),
      };
      final prefs = preferences;
      if (prefs != null && !await prefs.setString(_key, jsonEncode(_pending))) {
        throw StateError('CALCULATOR_LOCAL_SAVE_FAILED');
      }
      final result = await repository.save(
        Map<String, dynamic>.from(_pending!['payload'] as Map),
        _pending!['key'] as String,
      );
      if (!_disposed) record = result;
      _pending = null;
      await prefs?.remove(_key);
      return result;
    } catch (e) {
      error = e;
      // Definitive server validation/permission/conflict responses did not commit.
      final message = e.toString();
      if ((e is FormatException ||
              message.contains('CALCULATOR_') ||
              message.contains('V1_')) &&
          !message.contains('CONNECTION') &&
          !message.contains('LOCAL_SAVE')) {
        _pending = null;
        await preferences?.remove(_key);
        if (message.contains('ACCESS_DENIED')) denied = true;
      }
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? recoverPending() {
    final raw = preferences?.getString(_key);
    if (raw == null) return null;
    try {
      _pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return Map<String, dynamic>.from(_pending!['payload'] as Map);
    } catch (e) {
      error = e;
      return null;
    }
  }

  Future<bool> manage(Map<String, dynamic> change) async {
    final current = record;
    if (current == null || busy || !current.canManage) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final intent = {
        'id': current.id,
        'expected_version': current.version,
        ...change,
      };
      final key = const Uuid().v5(
        Namespace.url.value,
        'calculator:$identity:${YorksCalculatorFiles.fingerprint(intent)}',
      );
      final result = await repository.manage(intent, key);
      if (!_disposed) record = result;
      return true;
    } catch (e) {
      error = e;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
