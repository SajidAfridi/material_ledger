import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/material_line_draft.dart';

typedef MaterialLineAutosave =
    FutureOr<void> Function(
      List<MaterialLineDraft> lines,
      Map<String, MaterialLineCommercial> commercials,
    );

class MaterialLineGridController extends ChangeNotifier {
  MaterialLineGridController({
    List<MaterialLineDraft> lines = const [],
    Map<String, MaterialLineCommercial> commercials = const {},
    required this.commercialsEnabled,
    this.onAutosave,
    this.autosaveDelay = const Duration(milliseconds: 350),
    String Function()? idFactory,
  }) : _lines = List.of(lines),
       _commercials = commercialsEnabled ? Map.of(commercials) : {},
       _idFactory = idFactory ?? _nextGeneratedId;

  final bool commercialsEnabled;
  final MaterialLineAutosave? onAutosave;
  final Duration autosaveDelay;
  final String Function() _idFactory;

  List<MaterialLineDraft> _lines;
  Map<String, MaterialLineCommercial> _commercials;
  final List<_GridSnapshot> _undo = [];
  final List<_GridSnapshot> _redo = [];
  Timer? _autosaveTimer;

  List<MaterialLineDraft> get lines => List.unmodifiable(_lines);
  Map<String, MaterialLineCommercial> get commercials =>
      Map.unmodifiable(_commercials);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  MaterialLineCommercial? commercialFor(String lineId) =>
      commercialsEnabled ? _commercials[lineId] : null;

  MaterialLineDraft addBlankRow() {
    _checkpoint();
    final line = MaterialLineDraft(id: _idFactory());
    _lines = [..._lines, line];
    _changed();
    return line;
  }

  MaterialLineDraft addLine(MaterialLineDraft line) {
    _checkpoint();
    final id = line.id.trim().isEmpty ? _idFactory() : line.id;
    final next = line.id == id
        ? line
        : MaterialLineDraft(
            id: id,
            description: line.description,
            size: line.size,
            modelSerial: line.modelSerial,
            makeOrigin: line.makeOrigin,
            quantity: line.quantity,
            unitSymbol: line.unitSymbol,
            remarks: line.remarks,
          );
    _lines = [..._lines, next];
    _changed();
    return next;
  }

  MaterialLineDraft addSimilarRow({String? sourceLineId}) {
    final source = sourceLineId == null
        ? (_lines.isEmpty ? null : _lines.last)
        : _lines.cast<MaterialLineDraft?>().firstWhere(
            (line) => line?.id == sourceLineId,
            orElse: () => null,
          );
    if (source == null) return addBlankRow();

    _checkpoint();
    final line = MaterialLineDraft(
      id: _idFactory(),
      description: source.description,
      size: source.size,
      makeOrigin: source.makeOrigin,
      unitSymbol: source.unitSymbol,
      remarks: source.remarks,
    );
    _lines = [..._lines, line];
    // Model/Serial, quantity and commercials intentionally remain clear.
    _changed();
    return line;
  }

  void removeLine(String lineId) {
    final index = _lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;
    _checkpoint();
    _lines = [..._lines]..removeAt(index);
    _commercials = {..._commercials}..remove(lineId);
    _changed();
  }

  void updateField(String lineId, MaterialLineField field, String rawValue) {
    final index = _lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;
    final before = _lines[index];
    MaterialLineDraft after = before;

    switch (field) {
      case MaterialLineField.description:
        after = before.copyWith(description: rawValue);
      case MaterialLineField.size:
        after = before.copyWith(size: rawValue);
      case MaterialLineField.modelSerial:
        after = before.copyWith(modelSerial: rawValue);
      case MaterialLineField.makeOrigin:
        after = before.copyWith(makeOrigin: rawValue);
      case MaterialLineField.quantity:
        after = before.copyWith(quantity: _parseOptionalNumber(rawValue));
      case MaterialLineField.unit:
        after = before.copyWith(unitSymbol: rawValue);
      case MaterialLineField.remarks:
        after = before.copyWith(remarks: rawValue);
      case MaterialLineField.unitCost:
        if (!commercialsEnabled) return;
        final value = _parseOptionalNumber(rawValue) ?? 0;
        if (!value.isFinite || value < 0) return;
        final existing = _commercials[lineId];
        if (existing?.unitCostAED == value) return;
        _checkpoint();
        _commercials = {
          ..._commercials,
          lineId: MaterialLineCommercial(lineId: lineId, unitCostAED: value),
        };
        _changed();
        return;
    }

    if (_sameLine(before, after)) return;
    _checkpoint();
    final next = [..._lines];
    next[index] = after;
    _lines = next;
    _changed();
  }

  void applySize(String lineId, String value) =>
      updateField(lineId, MaterialLineField.size, value.trim());

  Map<MaterialLineField, String> validateLine(MaterialLineDraft line) {
    final errors = <MaterialLineField, String>{};
    if (line.description.trim().isEmpty) {
      errors[MaterialLineField.description] = 'Item description is required';
    }
    final quantity = line.quantity;
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      errors[MaterialLineField.quantity] = 'Quantity must be greater than zero';
    }
    if (line.unitSymbol.trim().isEmpty) {
      errors[MaterialLineField.unit] = 'Unit is required';
    }
    final unitCost = commercialFor(line.id)?.unitCostAED;
    if (unitCost != null && (!unitCost.isFinite || unitCost < 0)) {
      errors[MaterialLineField.unitCost] = 'Unit cost must be zero or greater';
    }
    return errors;
  }

  Map<String, Map<MaterialLineField, String>> validateAll() => {
    for (final line in _lines)
      if (validateLine(line).isNotEmpty) line.id: validateLine(line),
  };

  void pasteTsv(String clipboard, {int startRow = 0, int startColumn = 0}) {
    final rows = clipboard
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((row) => row.isNotEmpty)
        .map((row) => row.split('\t'))
        .toList();
    if (rows.isEmpty) return;

    _checkpoint();
    final nextLines = [..._lines];
    final nextCommercials = {..._commercials};
    while (nextLines.length < startRow + rows.length) {
      nextLines.add(MaterialLineDraft(id: _idFactory()));
    }

    final fields = <MaterialLineField>[
      MaterialLineField.description,
      MaterialLineField.size,
      MaterialLineField.modelSerial,
      MaterialLineField.makeOrigin,
      MaterialLineField.quantity,
      MaterialLineField.unit,
      MaterialLineField.remarks,
      if (commercialsEnabled) MaterialLineField.unitCost,
    ];

    for (var rowOffset = 0; rowOffset < rows.length; rowOffset++) {
      var line = nextLines[startRow + rowOffset];
      final values = rows[rowOffset];
      for (var columnOffset = 0; columnOffset < values.length; columnOffset++) {
        final fieldIndex = startColumn + columnOffset;
        if (fieldIndex < 0 || fieldIndex >= fields.length) break;
        final value = values[columnOffset];
        switch (fields[fieldIndex]) {
          case MaterialLineField.description:
            line = line.copyWith(description: value);
          case MaterialLineField.size:
            line = line.copyWith(size: value);
          case MaterialLineField.modelSerial:
            line = line.copyWith(modelSerial: value);
          case MaterialLineField.makeOrigin:
            line = line.copyWith(makeOrigin: value);
          case MaterialLineField.quantity:
            line = line.copyWith(quantity: _parseOptionalNumber(value));
          case MaterialLineField.unit:
            line = line.copyWith(unitSymbol: value);
          case MaterialLineField.remarks:
            line = line.copyWith(remarks: value);
          case MaterialLineField.unitCost:
            if (commercialsEnabled) {
              final parsed = _parseOptionalNumber(value);
              if (parsed != null && parsed.isFinite && parsed >= 0) {
                nextCommercials[line.id] = MaterialLineCommercial(
                  lineId: line.id,
                  unitCostAED: parsed,
                );
              }
            }
        }
      }
      nextLines[startRow + rowOffset] = line;
    }
    _lines = nextLines;
    _commercials = commercialsEnabled ? nextCommercials : {};
    _changed();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  Future<void> flushAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    final callback = onAutosave;
    if (callback != null) {
      await callback(lines, commercials);
    }
  }

  void _checkpoint() {
    _undo.add(_snapshot());
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  _GridSnapshot _snapshot() =>
      _GridSnapshot(List.of(_lines), Map.of(_commercials));

  void _restore(_GridSnapshot snapshot) {
    _lines = List.of(snapshot.lines);
    _commercials = commercialsEnabled ? Map.of(snapshot.commercials) : {};
    _changed();
  }

  void _changed() {
    notifyListeners();
    _autosaveTimer?.cancel();
    if (onAutosave != null) {
      _autosaveTimer = Timer(autosaveDelay, flushAutosave);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  static double? _parseOptionalNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  static bool _sameLine(MaterialLineDraft a, MaterialLineDraft b) =>
      a.description == b.description &&
      a.size == b.size &&
      a.modelSerial == b.modelSerial &&
      a.makeOrigin == b.makeOrigin &&
      a.quantity == b.quantity &&
      a.unitSymbol == b.unitSymbol &&
      a.remarks == b.remarks;

  static int _generatedId = 0;
  static String _nextGeneratedId() =>
      'material-line-${DateTime.now().microsecondsSinceEpoch}-${_generatedId++}';
}

class _GridSnapshot {
  const _GridSnapshot(this.lines, this.commercials);

  final List<MaterialLineDraft> lines;
  final Map<String, MaterialLineCommercial> commercials;
}
