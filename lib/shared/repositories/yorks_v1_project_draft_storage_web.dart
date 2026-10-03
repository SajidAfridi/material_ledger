import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'yorks_v1_project_draft_store.dart';

ProjectDraftAtomicStorage createProjectDraftAtomicStorage(
  SharedPreferences preferences,
) => BrowserProjectDraftStorage();

/// Web Locks serialize the ownership check and the synchronous localStorage
/// commit across tabs. Persisted fencing epochs protect resumed former writers.
/// Broadcast delivery is not part of correctness. Browsers lacking Web Locks
/// fail closed rather than falling back to a read/check/write race.
class BrowserProjectDraftStorage implements ProjectDraftAtomicStorage {
  @override
  bool get supportsAtomicOwnership =>
      web.window.isSecureContext &&
      web.window.navigator.hasProperty('locks'.toJS).toDart;

  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  Future<T> transaction<T>(
    String lockKey,
    T Function(ProjectDraftAtomicTransaction transaction) work,
  ) async {
    if (!supportsAtomicOwnership) {
      throw const ProjectDraftStorageException('atomic_ownership_unavailable');
    }
    late T result;
    Object? failure;
    StackTrace? failureStack;
    await web.window.navigator.locks
        .request(
          lockKey,
          ((web.Lock lock) {
            try {
              final tx = _BrowserTransaction();
              result = work(tx);
              tx.commit();
            } catch (error, stack) {
              failure = error;
              failureStack = stack;
            }
            return null;
          }).toJS,
        )
        .toDart;
    if (failure != null) {
      Error.throwWithStackTrace(failure!, failureStack!);
    }
    return result;
  }
}

class _BrowserTransaction implements ProjectDraftAtomicTransaction {
  final Map<String, String?> _writes = {};

  @override
  String? read(String key) => _writes.containsKey(key)
      ? _writes[key]
      : web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) => _writes[key] = value;

  @override
  void remove(String key) => _writes[key] = null;

  void commit() {
    for (final entry in _writes.entries) {
      if (entry.value == null) {
        web.window.localStorage.removeItem(entry.key);
      } else {
        web.window.localStorage.setItem(entry.key, entry.value!);
      }
    }
  }
}
