import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/constants.dart';
import '../controllers/material_line_grid_controller.dart';
import '../models/material_line_draft.dart';

class MaterialLineGrid extends StatefulWidget {
  const MaterialLineGrid({
    super.key,
    required this.controller,
    required this.units,
    this.editable = true,
    this.onExport,
    this.desktopHeight = 560,
  });

  final MaterialLineGridController controller;
  final List<String> units;
  final bool editable;
  final VoidCallback? onExport;
  final double desktopHeight;

  @override
  State<MaterialLineGrid> createState() => _MaterialLineGridState();
}

class _MaterialLineGridState extends State<MaterialLineGrid> {
  static const _rowHeight = 56.0;
  static const _serialWidth = 70.0;
  static const _operationalWidth = 1120.0;
  static const _commercialWidth = 240.0;

  final _serialScroll = ScrollController();
  final _bodyScroll = ScrollController();
  final _horizontalScroll = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};
  bool _syncingVertical = false;
  String? _selectedLineId;
  MaterialLineField _selectedField = MaterialLineField.description;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _serialScroll.addListener(() => _sync(_serialScroll, _bodyScroll));
    _bodyScroll.addListener(() => _sync(_bodyScroll, _serialScroll));
    _selectedLineId = widget.controller.lines.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant MaterialLineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      _selectedLineId = widget.controller.lines.firstOrNull?.id;
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    final lines = widget.controller.lines;
    if (_selectedLineId != null &&
        !lines.any((line) => line.id == _selectedLineId)) {
      _selectedLineId = lines.firstOrNull?.id;
    }
    setState(() {});
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncingVertical || !target.hasClients || !source.hasClients) return;
    _syncingVertical = true;
    final offset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    target.jumpTo(offset);
    _syncingVertical = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _serialScroll.dispose();
    _bodyScroll.dispose();
    _horizontalScroll.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            widget.controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            widget.controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): widget.controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            widget.controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteFromClipboard,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _pasteFromClipboard,
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= AppSpacing.compactBreakpoint) {
              return _buildMobile(context, constraints.maxHeight);
            }
            return _buildDesktop(context);
          },
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final count = widget.controller.lines.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _CountChip(count: count),
          if (widget.editable) ...[
            OutlinedButton.icon(
              key: const ValueKey('grid-add-blank'),
              onPressed: () {
                final line = widget.controller.addBlankRow();
                setState(() => _selectedLineId = line.id);
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Blank row'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('grid-add-similar'),
              onPressed: count == 0
                  ? null
                  : () {
                      final line = widget.controller.addSimilarRow(
                        sourceLineId: _selectedLineId,
                      );
                      setState(() => _selectedLineId = line.id);
                    },
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Similar row'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('grid-paste'),
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_outlined, size: 16),
              label: const Text('Paste'),
            ),
            IconButton(
              key: const ValueKey('grid-undo'),
              tooltip: 'Undo',
              onPressed: widget.controller.canUndo
                  ? widget.controller.undo
                  : null,
              icon: const Icon(Icons.undo_rounded, size: 19),
            ),
            IconButton(
              key: const ValueKey('grid-redo'),
              tooltip: 'Redo',
              onPressed: widget.controller.canRedo
                  ? widget.controller.redo
                  : null,
              icon: const Icon(Icons.redo_rounded, size: 19),
            ),
          ],
          OutlinedButton.icon(
            key: const ValueKey('grid-export'),
            onPressed: widget.onExport,
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final lines = widget.controller.lines;
    final width =
        _operationalWidth +
        (widget.controller.commercialsEnabled ? _commercialWidth : 0);
    return Container(
      key: const ValueKey('material-line-grid-desktop'),
      height: widget.desktopHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildToolbar(context),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: _serialWidth,
                  child: Column(
                    children: [
                      const _GridHeaderCell(label: 'S:No', width: _serialWidth),
                      Expanded(
                        child: ListView.builder(
                          key: const ValueKey('grid-serial-list'),
                          controller: _serialScroll,
                          itemExtent: _rowHeight,
                          itemCount: lines.length,
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            return _SerialCell(
                              key: ValueKey('serial-${line.id}'),
                              number: index + 1,
                              selected: line.id == _selectedLineId,
                              errorCount: widget.controller
                                  .validateLine(line)
                                  .length,
                              onTap: () =>
                                  setState(() => _selectedLineId = line.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.line),
                Expanded(
                  child: Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(4),
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            _buildHeader(),
                            Expanded(
                              child: ListView.builder(
                                key: const ValueKey('grid-body-list'),
                                controller: _bodyScroll,
                                itemExtent: _rowHeight,
                                itemCount: lines.length,
                                itemBuilder: (context, index) =>
                                    _buildDesktopRow(lines[index], index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFooter(showColumnHint: true),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const _GridHeaderCell(label: 'Item Description', width: 220),
        const _GridHeaderCell(label: 'Size (If any)', width: 150),
        const _GridHeaderCell(label: 'Model/Serial No.', width: 160),
        const _GridHeaderCell(label: 'Make/Origin', width: 180),
        const _GridHeaderCell(label: 'QTY', width: 90),
        const _GridHeaderCell(label: 'Unit', width: 100),
        const _GridHeaderCell(label: 'Remarks', width: 220),
        if (widget.controller.commercialsEnabled) ...[
          const _GridHeaderCell(label: 'Unit Cost', width: 120),
          const _GridHeaderCell(label: 'Total Cost', width: 120),
        ],
      ],
    );
  }

  Widget _buildDesktopRow(MaterialLineDraft line, int rowIndex) {
    final selected = line.id == _selectedLineId;
    final errors = widget.controller.validateLine(line);
    final commercial = widget.controller.commercialFor(line.id);
    final background = selected
        ? AppColors.blueContainer.withValues(alpha: 0.55)
        : rowIndex.isEven
        ? AppColors.surfaceContainerLowest
        : AppColors.surfaceContainerLow;
    return ColoredBox(
      key: ValueKey('grid-row-${line.id}'),
      color: background,
      child: Row(
        children: [
          _textCell(
            line,
            rowIndex,
            MaterialLineField.description,
            line.description,
            220,
            error: errors[MaterialLineField.description],
          ),
          _sizeCell(line, 150),
          _textCell(
            line,
            rowIndex,
            MaterialLineField.modelSerial,
            line.modelSerial,
            160,
          ),
          _textCell(
            line,
            rowIndex,
            MaterialLineField.makeOrigin,
            line.makeOrigin,
            180,
          ),
          _textCell(
            line,
            rowIndex,
            MaterialLineField.quantity,
            _number(line.quantity),
            90,
            numeric: true,
            error: errors[MaterialLineField.quantity],
          ),
          _unitCell(line, rowIndex, errors[MaterialLineField.unit]),
          _textCell(
            line,
            rowIndex,
            MaterialLineField.remarks,
            line.remarks,
            220,
          ),
          if (widget.controller.commercialsEnabled) ...[
            _textCell(
              line,
              rowIndex,
              MaterialLineField.unitCost,
              commercial?.unitCostAED.toStringAsFixed(2) ?? '',
              120,
              numeric: true,
              error: errors[MaterialLineField.unitCost],
            ),
            _ReadOnlyCell(
              width: 120,
              value: commercial == null
                  ? '—'
                  : 'AED ${commercial.totalCostAED(line.quantity).toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _textCell(
    MaterialLineDraft line,
    int rowIndex,
    MaterialLineField field,
    String value,
    double width, {
    bool numeric = false,
    String? error,
  }) {
    final focusNode = _focusNode(line.id, field);
    return SizedBox(
      width: width,
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: TextFormField(
          key: ValueKey('cell-${line.id}-${field.name}'),
          initialValue: value,
          focusNode: focusNode,
          enabled: widget.editable,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink,
            height: 1.1,
          ),
          decoration: _cellDecoration(error),
          onChanged: (next) =>
              widget.controller.updateField(line.id, field, next),
          onTap: () => _select(line.id, field),
        ),
      ),
    );
  }

  Widget _sizeCell(MaterialLineDraft line, double width) {
    return SizedBox(
      width: width,
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: OutlinedButton(
          key: ValueKey('cell-${line.id}-size'),
          onPressed: widget.editable
              ? () async {
                  _select(line.id, MaterialLineField.size);
                  final result = await showMaterialSizeBuilder(
                    context,
                    initialValue: line.size,
                  );
                  if (result != null) {
                    widget.controller.applySize(line.id, result);
                  }
                }
              : null,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size(width, 44),
          ),
          child: Text(
            line.size.isEmpty ? 'Add size…' : line.size,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.ink),
          ),
        ),
      ),
    );
  }

  Widget _unitCell(MaterialLineDraft line, int rowIndex, String? error) {
    final options = {
      if (line.unitSymbol.isNotEmpty) line.unitSymbol,
      ...widget.units,
    }.toList();
    return SizedBox(
      width: 100,
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: DropdownButtonFormField<String>(
          key: ValueKey('cell-${line.id}-unit'),
          initialValue: line.unitSymbol,
          focusNode: _focusNode(line.id, MaterialLineField.unit),
          isExpanded: true,
          style: AppTypography.bodySmall.copyWith(color: AppColors.ink),
          decoration: _cellDecoration(error),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: widget.editable
              ? (value) {
                  if (value == null) return;
                  _select(line.id, MaterialLineField.unit);
                  widget.controller.updateField(
                    line.id,
                    MaterialLineField.unit,
                    value,
                  );
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context, double availableHeight) {
    final lines = widget.controller.lines;
    final listHeight = availableHeight.isFinite
        ? (availableHeight - 300).clamp(220.0, widget.desktopHeight)
        : widget.desktopHeight;
    return Container(
      key: const ValueKey('material-line-grid-mobile'),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          if (lines.isEmpty)
            const _EmptyGrid()
          else
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                key: const ValueKey('grid-mobile-list'),
                itemCount: lines.length,
                itemBuilder: (context, index) => _MobileLineCard(
                  key: ValueKey('mobile-line-${lines[index].id}'),
                  line: lines[index],
                  lineNumber: index + 1,
                  commercial: widget.controller.commercialFor(lines[index].id),
                  errorCount: widget.controller
                      .validateLine(lines[index])
                      .length,
                  onTap: () => _openMobileEditor(lines[index]),
                ),
              ),
            ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter({bool showColumnHint = false}) {
    final invalid = widget.controller.validateAll().length;
    final lines = widget.controller.lines;
    final total = widget.controller.commercialsEnabled
        ? lines.fold<double>(
            0,
            (sum, line) =>
                sum +
                (widget.controller
                        .commercialFor(line.id)
                        ?.totalCostAED(line.quantity) ??
                    0),
          )
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 4,
        spacing: AppSpacing.lg,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              Text(
                invalid == 0
                    ? 'Draft valid · Autosave ready'
                    : '$invalid row${invalid == 1 ? '' : 's'} need attention',
                style: AppTypography.bodySmall.copyWith(
                  color: invalid == 0 ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showColumnHint)
                Text(
                  'Scroll horizontally for all columns',
                  style: AppTypography.bodySmall,
                ),
            ],
          ),
          Text(
            total == null
                ? 'Lines ${lines.length}'
                : 'Lines ${lines.length} · AED ${total.toStringAsFixed(2)}',
            style: AppTypography.labelLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _openMobileEditor(MaterialLineDraft line) async {
    _selectedLineId = line.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => MaterialLineFocusedEditor(
        controller: widget.controller,
        lineId: line.id,
        units: widget.units,
        editable: widget.editable,
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    if (!widget.editable) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) return;
    final startRow = widget.controller.lines.indexWhere(
      (line) => line.id == _selectedLineId,
    );
    widget.controller.pasteTsv(
      text,
      startRow: startRow < 0 ? 0 : startRow,
      startColumn: _pasteColumn(_selectedField),
    );
  }

  int _pasteColumn(MaterialLineField field) => switch (field) {
    MaterialLineField.description => 0,
    MaterialLineField.size => 1,
    MaterialLineField.modelSerial => 2,
    MaterialLineField.makeOrigin => 3,
    MaterialLineField.quantity => 4,
    MaterialLineField.unit => 5,
    MaterialLineField.remarks => 6,
    MaterialLineField.unitCost => 7,
  };

  FocusNode _focusNode(String lineId, MaterialLineField field) {
    final key = '$lineId:${field.name}';
    return _focusNodes.putIfAbsent(key, () {
      final node = FocusNode(
        debugLabel: key,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent ||
              event.logicalKey != LogicalKeyboardKey.enter) {
            return KeyEventResult.ignored;
          }
          _moveVertically(
            lineId,
            field,
            backwards: HardwareKeyboard.instance.isShiftPressed,
          );
          return KeyEventResult.handled;
        },
      );
      node.addListener(() {
        if (node.hasFocus && mounted) _select(lineId, field);
      });
      return node;
    });
  }

  void _moveVertically(
    String lineId,
    MaterialLineField field, {
    required bool backwards,
  }) {
    final lines = widget.controller.lines;
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;
    final next = (index + (backwards ? -1 : 1)).clamp(0, lines.length - 1);
    if (next == index) return;
    _bodyScroll.jumpTo(
      (next * _rowHeight).clamp(
        _bodyScroll.position.minScrollExtent,
        _bodyScroll.position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode(lines[next].id, field).requestFocus();
      _select(lines[next].id, field);
    });
  }

  void _select(String lineId, MaterialLineField field) {
    setState(() {
      _selectedLineId = lineId;
      _selectedField = field;
    });
  }

  InputDecoration _cellDecoration(String? error) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    filled: true,
    fillColor: AppColors.surfaceContainerLowest,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: error == null ? AppColors.line : AppColors.error,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
    ),
    errorText: null,
  );

  static String _number(double? value) {
    if (value == null) return '';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : '$value';
  }
}

class MaterialLineFocusedEditor extends StatefulWidget {
  const MaterialLineFocusedEditor({
    super.key,
    required this.controller,
    required this.lineId,
    required this.units,
    required this.editable,
  });

  final MaterialLineGridController controller;
  final String lineId;
  final List<String> units;
  final bool editable;

  @override
  State<MaterialLineFocusedEditor> createState() =>
      _MaterialLineFocusedEditorState();
}

class _MaterialLineFocusedEditorState extends State<MaterialLineFocusedEditor> {
  late final Map<MaterialLineField, TextEditingController> _fields;
  late String _unit;

  MaterialLineDraft get _line =>
      widget.controller.lines.firstWhere((line) => line.id == widget.lineId);

  @override
  void initState() {
    super.initState();
    final line = _line;
    final commercial = widget.controller.commercialFor(line.id);
    _unit = line.unitSymbol;
    _fields = {
      MaterialLineField.description: TextEditingController(
        text: line.description,
      ),
      MaterialLineField.size: TextEditingController(text: line.size),
      MaterialLineField.modelSerial: TextEditingController(
        text: line.modelSerial,
      ),
      MaterialLineField.makeOrigin: TextEditingController(
        text: line.makeOrigin,
      ),
      MaterialLineField.quantity: TextEditingController(
        text: MaterialLineGridStateNumber.number(line.quantity),
      ),
      MaterialLineField.remarks: TextEditingController(text: line.remarks),
      if (widget.controller.commercialsEnabled)
        MaterialLineField.unitCost: TextEditingController(
          text: commercial?.unitCostAED.toStringAsFixed(2) ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit material line')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + 110,
        ),
        children: [
          _field(MaterialLineField.description, 'Item Description'),
          const SizedBox(height: AppSpacing.md),
          Text('Size (If any)', style: AppTypography.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fields[MaterialLineField.size],
                  enabled: widget.editable,
                  decoration: const InputDecoration(hintText: '500 x 500 mm'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'Build size',
                onPressed: widget.editable
                    ? () async {
                        final value = await showMaterialSizeBuilder(
                          context,
                          initialValue:
                              _fields[MaterialLineField.size]?.text ?? '',
                        );
                        if (value != null) {
                          _fields[MaterialLineField.size]?.text = value;
                        }
                      }
                    : null,
                icon: const Icon(Icons.straighten_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _field(MaterialLineField.modelSerial, 'Model/Serial No.'),
          const SizedBox(height: AppSpacing.md),
          _field(MaterialLineField.makeOrigin, 'Make/Origin'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(MaterialLineField.quantity, 'QTY', numeric: true),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: {_unit, ...widget.units}.map((unit) {
                    return DropdownMenuItem(value: unit, child: Text(unit));
                  }).toList(),
                  onChanged: widget.editable
                      ? (value) => setState(() => _unit = value ?? _unit)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _field(MaterialLineField.remarks, 'Remarks', maxLines: 3),
          if (widget.controller.commercialsEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            _field(MaterialLineField.unitCost, 'Unit Cost', numeric: true),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('focused-editor-save'),
                  onPressed: widget.editable ? _save : null,
                  child: const Text('Save row'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    MaterialLineField field,
    String label, {
    bool numeric = false,
    int maxLines = 1,
  }) {
    return TextField(
      key: ValueKey('focused-${field.name}'),
      controller: _fields[field],
      enabled: widget.editable,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  void _save() {
    for (final entry in _fields.entries) {
      widget.controller.updateField(widget.lineId, entry.key, entry.value.text);
    }
    widget.controller.updateField(widget.lineId, MaterialLineField.unit, _unit);
    Navigator.of(context).pop();
  }
}

Future<String?> showMaterialSizeBuilder(
  BuildContext context, {
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _MaterialSizeBuilderDialog(initialValue: initialValue),
  );
}

class _MaterialSizeBuilderDialog extends StatefulWidget {
  const _MaterialSizeBuilderDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_MaterialSizeBuilderDialog> createState() =>
      _MaterialSizeBuilderDialogState();
}

class _MaterialSizeBuilderDialogState
    extends State<_MaterialSizeBuilderDialog> {
  MaterialSizeMode mode = MaterialSizeMode.rectangular;
  final first = TextEditingController(text: '500');
  final second = TextEditingController(text: '500');
  late final custom = TextEditingController(text: widget.initialValue);
  String unit = 'mm';

  @override
  void initState() {
    super.initState();
    first.addListener(_refresh);
    second.addListener(_refresh);
    custom.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    custom.dispose();
    super.dispose();
  }

  String get value {
    final a = double.tryParse(first.text) ?? 0;
    final b = double.tryParse(second.text) ?? 0;
    return switch (mode) {
      MaterialSizeMode.rectangular => MaterialSizeFormatter.rectangular(
        width: a,
        height: b,
        unit: unit,
      ),
      MaterialSizeMode.circular => MaterialSizeFormatter.circular(
        diameter: a,
        unit: unit,
      ),
      MaterialSizeMode.linear => MaterialSizeFormatter.linear(
        length: a,
        unit: unit,
      ),
      MaterialSizeMode.nominalPipe => MaterialSizeFormatter.nominalPipe(
        custom.text.isEmpty ? 'DN50' : custom.text,
      ),
      MaterialSizeMode.custom => MaterialSizeFormatter.custom(custom.text),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Build material size'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<MaterialSizeMode>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Size type'),
                items: const [
                  DropdownMenuItem(
                    value: MaterialSizeMode.rectangular,
                    child: Text('Rectangular'),
                  ),
                  DropdownMenuItem(
                    value: MaterialSizeMode.circular,
                    child: Text('Circular'),
                  ),
                  DropdownMenuItem(
                    value: MaterialSizeMode.linear,
                    child: Text('Linear'),
                  ),
                  DropdownMenuItem(
                    value: MaterialSizeMode.nominalPipe,
                    child: Text('Pipe / Nominal'),
                  ),
                  DropdownMenuItem(
                    value: MaterialSizeMode.custom,
                    child: Text('Custom'),
                  ),
                ],
                onChanged: (next) => setState(() => mode = next ?? mode),
              ),
              const SizedBox(height: AppSpacing.md),
              if (mode == MaterialSizeMode.custom ||
                  mode == MaterialSizeMode.nominalPipe)
                TextField(
                  key: const ValueKey('size-custom'),
                  controller: custom,
                  decoration: InputDecoration(
                    labelText: mode == MaterialSizeMode.nominalPipe
                        ? 'Nominal size'
                        : 'Custom size / specification',
                    hintText: mode == MaterialSizeMode.nominalPipe
                        ? 'DN50'
                        : '0.8 mm x 1.22 m x 2.44 m',
                  ),
                )
              else ...[
                TextField(
                  key: const ValueKey('size-first'),
                  controller: first,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: switch (mode) {
                      MaterialSizeMode.rectangular => 'Width',
                      MaterialSizeMode.circular => 'Diameter',
                      MaterialSizeMode.linear => 'Length',
                      _ => '',
                    },
                  ),
                ),
                if (mode == MaterialSizeMode.rectangular) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('size-second'),
                    controller: second,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Height'),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: 'mm', child: Text('mm')),
                    DropdownMenuItem(value: 'cm', child: Text('cm')),
                    DropdownMenuItem(value: 'm', child: Text('m')),
                  ],
                  onChanged: (next) => setState(() => unit = next ?? unit),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Formatted value', style: AppTypography.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      value.isEmpty ? 'Enter a size' : value,
                      key: const ValueKey('size-preview'),
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('size-apply'),
          onPressed: value.isEmpty
              ? null
              : () => Navigator.of(context).pop(value),
          child: const Text('Apply size'),
        ),
      ],
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.lineStrong),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelMedium.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _SerialCell extends StatelessWidget {
  const _SerialCell({
    super.key,
    required this.number,
    required this.selected,
    required this.errorCount,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final int errorCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blueContainer
              : AppColors.surfaceContainerLowest,
          border: const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: errorCount == 0 ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('$number', style: AppTypography.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyCell extends StatelessWidget {
  const _ReadOnlyCell({required this.width, required this.value});

  final double width;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge,
      ),
    );
  }
}

class _MobileLineCard extends StatelessWidget {
  const _MobileLineCard({
    super.key,
    required this.line,
    required this.lineNumber,
    required this.commercial,
    required this.errorCount,
    required this.onTap,
  });

  final MaterialLineDraft line;
  final int lineNumber;
  final MaterialLineCommercial? commercial;
  final int errorCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: errorCount == 0
                    ? AppColors.successContainer
                    : AppColors.warningContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$lineNumber', style: AppTypography.labelLarge),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.description.isEmpty
                        ? 'Untitled material'
                        : line.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (line.size.isNotEmpty) line.size,
                      if (line.quantity != null)
                        '${MaterialLineGridStateNumber.number(line.quantity)} ${line.unitSymbol}',
                      if (line.makeOrigin.isNotEmpty) line.makeOrigin,
                    ].join(' · '),
                    style: AppTypography.bodySmall,
                  ),
                  if (commercial != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'AED ${commercial!.totalCostAED(line.quantity).toStringAsFixed(2)}',
                      style: AppTypography.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.neutralContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '$count row${count == 1 ? '' : 's'}',
          style: AppTypography.labelLarge,
        ),
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.playlist_add_rounded, color: AppColors.muted),
          const SizedBox(height: AppSpacing.sm),
          Text('No material lines yet', style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add a blank row or paste rows copied from Excel.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

abstract final class MaterialLineGridStateNumber {
  static String number(double? value) {
    if (value == null) return '';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : '$value';
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
