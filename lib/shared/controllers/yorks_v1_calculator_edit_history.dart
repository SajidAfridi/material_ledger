import 'dart:convert';

import '../models/yorks_v1_calculator_workspace.dart';

/// Session-only history. It never changes a saved server revision or pending
/// command. A byte cap also bounds memory for large imported ESP calculations.
class YorksCalculatorEditHistory {
  YorksCalculatorEditHistory({
    this.maximumEntries = 100,
    this.maximumBytes = 8 * 1024 * 1024,
  });
  final int maximumEntries;
  final int maximumBytes;
  final List<String> _entries = [];
  int _cursor = -1;
  int _bytes = 0;
  DateTime? _lastEdit;
  String? _group;
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor >= 0 && _cursor < _entries.length - 1;
  int get depth => _entries.length;
  int get bytes => _bytes;

  void reset(Map<String, dynamic> snapshot) {
    _entries.clear();
    _bytes = 0;
    _cursor = -1;
    _group = null;
    _lastEdit = null;
    _append(jsonEncode(snapshot));
  }

  void record(
    Map<String, dynamic> snapshot, {
    DateTime? now,
    bool atomic = false,
  }) {
    if (_cursor < 0) return reset(snapshot);
    final old = jsonDecode(_entries[_cursor]) as Map<String, dynamic>;
    if (YorksCalculatorFiles.fingerprint(old) ==
        YorksCalculatorFiles.fingerprint(snapshot)) {
      return;
    }
    while (_entries.length > _cursor + 1) {
      _bytes -= utf8.encode(_entries.removeLast()).length;
    }
    final changes = <String>[];
    _changedLeaves(old, snapshot, '', changes);
    final group = !atomic && changes.length == 1 ? changes.single : null;
    final time = now ?? DateTime.now();
    final encoded = jsonEncode(snapshot);
    if (group != null &&
        group == _group &&
        _cursor > 0 &&
        _lastEdit != null &&
        time.difference(_lastEdit!) < const Duration(milliseconds: 650)) {
      _bytes -= utf8.encode(_entries.removeLast()).length;
      _cursor--;
    }
    _append(encoded);
    _group = group;
    _lastEdit = time;
  }

  void checkpoint() {
    _group = null;
    _lastEdit = null;
  }

  Map<String, dynamic>? undo() {
    checkpoint();
    return canUndo
        ? jsonDecode(_entries[--_cursor]) as Map<String, dynamic>
        : null;
  }

  Map<String, dynamic>? redo() {
    checkpoint();
    return canRedo
        ? jsonDecode(_entries[++_cursor]) as Map<String, dynamic>
        : null;
  }

  void _append(String encoded) {
    _entries.add(encoded);
    _bytes += utf8.encode(encoded).length;
    _cursor = _entries.length - 1;
    while (_entries.length > 1 &&
        (_entries.length > maximumEntries || _bytes > maximumBytes)) {
      _bytes -= utf8.encode(_entries.removeAt(0)).length;
      _cursor--;
    }
  }

  static void _changedLeaves(
    Object? a,
    Object? b,
    String path,
    List<String> changes,
  ) {
    if (a is Map && b is Map) {
      for (final key in {...a.keys, ...b.keys}) {
        if (key == 'savedAt') continue;
        _changedLeaves(a[key], b[key], '$path.$key', changes);
      }
    } else if (a is List && b is List && a.length == b.length) {
      for (var i = 0; i < a.length; i++) {
        _changedLeaves(a[i], b[i], '$path[$i]', changes);
      }
    } else if (a != b) {
      changes.add(path);
    }
  }
}
