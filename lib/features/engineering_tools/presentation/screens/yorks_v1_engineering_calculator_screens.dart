import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/yorks_v1_engineering_tools.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/services/yorks_v1_engineering_calculator_service.dart';

const _ductPrefsKey = 'yorks_r35_duct_calculation';
const _espPrefsKey = 'yorks_r35_esp_calculation';
const _jsonMime = 'application/json';

class YorksV1DuctSizerScreen extends ConsumerStatefulWidget {
  const YorksV1DuctSizerScreen({super.key});

  @override
  ConsumerState<YorksV1DuctSizerScreen> createState() =>
      _YorksV1DuctSizerScreenState();
}

class _YorksV1DuctSizerScreenState
    extends ConsumerState<YorksV1DuctSizerScreen> {
  final _flow = TextEditingController(text: '2753');
  final _width = TextEditingController(text: '900');
  final _height = TextEditingController(text: '700');
  final _diameter = TextEditingController(text: '500');
  final _targetVelocity = TextEditingController(text: '2.50');
  final _targetFriction = TextEditingController(text: '0.800');
  final _equivalentDiameter = TextEditingController(text: '500');
  final _aspectRatio = TextEditingController(text: '1.0');
  YorksV1DuctSolveMode _mode = YorksV1DuctSolveMode.checkSize;
  YorksV1DuctShape _shape = YorksV1DuctShape.rectangular;
  String _condition = '20°C Air STP';
  String _unitSystem = 'SI';
  String _material = 'Galvanized steel';
  YorksV1DuctCalculationResult? _result;
  bool _restoring = true;

  static const _air = <String, (double, double, double, double)>{
    'Air at 15°C': (1.2250, .0644, 1.006, 1.22),
    '20°C Air STP': (1.2014, .0643, 1.0048, 1.21),
    'Air at 25°C': (1.1840, .0662, 1.005, 1.20),
    'Air at 30°C': (1.1644, .0672, 1.005, 1.19),
  };
  static const _roughness = <String, double>{
    'Galvanized steel': .15,
    'Aluminium': .06,
    'Black steel': .045,
    'Flexible duct': 1.5,
    'Concrete': 3,
  };

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restore);
  }

  @override
  void dispose() {
    for (final controller in [
      _flow,
      _width,
      _height,
      _diameter,
      _targetVelocity,
      _targetFriction,
      _equivalentDiameter,
      _aspectRatio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final air = _air[_condition] ?? _air['20°C Air STP']!;
    final result = _result ?? _calculate(notify: false);
    return NexusPageShell(
      eyebrow: 'Engineering tools',
      title: 'Duct Sizer',
      description: 'A focused airflow, duct-size and pressure-loss workspace.',
      actions: [
        _ToolbarButton(label: 'Save', onPressed: _save),
        _ToolbarButton(label: 'Open', onPressed: _open),
        _ToolbarButton(label: 'Import', onPressed: _import),
        _ToolbarButton(label: 'Export', onPressed: _export),
        _ToolbarButton(label: 'Print', onPressed: _print, primary: true),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectBanner(onChanged: (_) {}, value: 'Independent calculation'),
          const SizedBox(height: AppSpacing.lg),
          _R35Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WorkspaceHeading(
                  kicker: 'Air distribution calculation',
                  title: 'Duct sizing workspace',
                  description:
                      'Darcy-Weisbach friction with ASHRAE rectangular equivalent diameter.',
                  trailing: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 460;
                      final firstWidth = stacked ? constraints.maxWidth : 190.0;
                      final secondWidth = stacked
                          ? constraints.maxWidth
                          : 260.0;
                      return Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          SizedBox(
                            width: firstWidth,
                            child: _SelectBox(
                              value: _unitSystem == 'SI'
                                  ? 'SI Units'
                                  : 'Imperial Units',
                              items: const ['SI Units', 'Imperial Units'],
                              onChanged: _switchUnitSystem,
                            ),
                          ),
                          SizedBox(
                            width: secondWidth,
                            child: _SelectBox(
                              value: _condition,
                              items: _air.keys.toList(),
                              onChanged: (value) => setState(() {
                                _condition = value;
                                _calculate();
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                _DuctBasisStrip(
                  condition: _condition,
                  density: air.$1,
                  viscosity: air.$2,
                  specificHeat: air.$3,
                  energyFactor: air.$4,
                ),
                const Divider(height: 1),
                _DuctModeStrip(
                  selected: _mode,
                  onChanged: (mode) => setState(() {
                    _mode = mode;
                    _calculate();
                  }),
                ),
                const Divider(height: 1),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 980;
                    final input = _ductInputs();
                    final output = _DuctResults(
                      result: result,
                      shape: _shape,
                      condition: _condition,
                      material: _material,
                      unitSystem: _unitSystem,
                      valid: result.valid,
                    );
                    return stacked
                        ? Column(children: [input, output])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: input),
                              const VerticalDivider(width: 1),
                              Expanded(child: output),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
          if (_restoring) const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _ductInputs() => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeading(
          kicker: 'Inputs',
          title: 'Design Parameters',
          trailing: _Badge(_modeLabel, AppColors.blueContainer),
        ),
        const SizedBox(height: AppSpacing.lg),
        _R35FormGrid(
          children: [
            _NumberField(
              label: 'Flow Rate',
              controller: _flow,
              suffix: _unitSystem == 'SI' ? 'L/s' : 'CFM',
              onChanged: (_) => _calculate(),
            ),
            _ToggleField(
              label: 'Duct Shape',
              selected: _shape == YorksV1DuctShape.rectangular
                  ? 'Rectangular'
                  : 'Circular',
              items: const ['Rectangular', 'Circular'],
              onChanged: (value) => setState(() {
                _shape = value == 'Rectangular'
                    ? YorksV1DuctShape.rectangular
                    : YorksV1DuctShape.circular;
                _calculate();
              }),
            ),
            _SelectField(
              label: 'Duct Material',
              value: _material,
              items: _roughness.keys.toList(),
              onChanged: (value) => setState(() {
                _material = value;
                _calculate();
              }),
            ),
            if (_mode == YorksV1DuctSolveMode.checkSize &&
                _shape == YorksV1DuctShape.rectangular)
              _NumberField(
                label: 'Duct Width',
                controller: _width,
                suffix: _lengthUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode == YorksV1DuctSolveMode.checkSize &&
                _shape == YorksV1DuctShape.rectangular)
              _NumberField(
                label: 'Duct Height',
                controller: _height,
                suffix: _lengthUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode == YorksV1DuctSolveMode.checkSize &&
                _shape == YorksV1DuctShape.circular)
              _NumberField(
                label: 'Duct Diameter',
                controller: _diameter,
                suffix: _lengthUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode == YorksV1DuctSolveMode.velocity)
              _NumberField(
                label: 'Target Velocity',
                controller: _targetVelocity,
                suffix: _velocityUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode == YorksV1DuctSolveMode.friction)
              _NumberField(
                label: 'Target Friction Rate',
                controller: _targetFriction,
                suffix: _frictionUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode == YorksV1DuctSolveMode.equivalentDiameter)
              _NumberField(
                label: 'Equivalent Diameter',
                controller: _equivalentDiameter,
                suffix: _lengthUnit,
                onChanged: (_) => _calculate(),
              ),
            if (_mode != YorksV1DuctSolveMode.checkSize &&
                _shape == YorksV1DuctShape.rectangular)
              _NumberField(
                label: 'Width : Height Ratio',
                controller: _aspectRatio,
                suffix: ': 1',
                onChanged: (_) => _calculate(),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _InfoNote(
          'Confirm final dimensions, allowable velocity, pressure drop, acoustic criteria and project specifications with the responsible HVAC Engineer.',
        ),
      ],
    ),
  );

  String get _modeLabel => switch (_mode) {
    YorksV1DuctSolveMode.checkSize => 'Check size',
    YorksV1DuctSolveMode.velocity => 'Size by velocity',
    YorksV1DuctSolveMode.friction => 'Size by friction',
    YorksV1DuctSolveMode.equivalentDiameter => 'Equivalent diameter',
  };

  String get _lengthUnit => _unitSystem == 'SI' ? 'mm' : 'in';
  String get _velocityUnit => _unitSystem == 'SI' ? 'm/s' : 'fpm';
  String get _frictionUnit => _unitSystem == 'SI' ? 'Pa/m' : 'in.wg/100 ft';

  YorksV1DuctCalculationResult _calculate({bool notify = true}) {
    _readDuctFields();
    final air = _air[_condition] ?? _air['20°C Air STP']!;
    final result = YorksV1EngineeringCalculatorService.ductCalculation(
      YorksV1DuctCalculationInput(
        flowLitresPerSecond: _unitSystem == 'SI'
            ? _number(_flow.text)
            : _number(_flow.text) / 2.118880003,
        widthMillimetres: _unitSystem == 'SI'
            ? _number(_width.text)
            : _number(_width.text) * 25.4,
        heightMillimetres: _unitSystem == 'SI'
            ? _number(_height.text)
            : _number(_height.text) * 25.4,
        diameterMillimetres: _unitSystem == 'SI'
            ? _number(_diameter.text)
            : _number(_diameter.text) * 25.4,
        shape: _shape,
        solveMode: _mode,
        targetVelocityMetresPerSecond: _unitSystem == 'SI'
            ? _number(_targetVelocity.text)
            : _number(_targetVelocity.text) / 196.850394,
        targetFrictionPaPerMetre: _unitSystem == 'SI'
            ? _number(_targetFriction.text)
            : _number(_targetFriction.text) * 8.172803,
        equivalentDiameterMillimetres: _unitSystem == 'SI'
            ? _number(_equivalentDiameter.text)
            : _number(_equivalentDiameter.text) * 25.4,
        aspectRatio: _number(_aspectRatio.text),
        roughnessMillimetres: _roughness[_material] ?? .15,
        airDensityKgPerCubicMetre: air.$1,
        airViscosityKgPerMetreHour: air.$2,
      ),
    );
    if (notify && mounted) setState(() => _result = result);
    return result;
  }

  void _readDuctFields() {
    // Values are already in the active display system. This hook intentionally
    // exists so switching systems can be extended without losing edit state.
  }

  void _switchUnitSystem(String value) {
    final next = value == 'SI Units' ? 'SI' : 'Imperial';
    if (next == _unitSystem) return;
    final toImperial = next == 'Imperial';
    _flow.text =
        (toImperial
                ? _number(_flow.text) * 2.118880003
                : _number(_flow.text) / 2.118880003)
            .toStringAsFixed(0);
    _width.text =
        (toImperial ? _number(_width.text) / 25.4 : _number(_width.text) * 25.4)
            .toStringAsFixed(toImperial ? 2 : 0);
    _height.text =
        (toImperial
                ? _number(_height.text) / 25.4
                : _number(_height.text) * 25.4)
            .toStringAsFixed(toImperial ? 2 : 0);
    _diameter.text =
        (toImperial
                ? _number(_diameter.text) / 25.4
                : _number(_diameter.text) * 25.4)
            .toStringAsFixed(toImperial ? 2 : 0);
    _targetVelocity.text =
        (toImperial
                ? _number(_targetVelocity.text) * 196.850394
                : _number(_targetVelocity.text) / 196.850394)
            .toStringAsFixed(toImperial ? 0 : 2);
    _targetFriction.text =
        (toImperial
                ? _number(_targetFriction.text) / 8.172803
                : _number(_targetFriction.text) * 8.172803)
            .toStringAsFixed(3);
    _equivalentDiameter.text =
        (toImperial
                ? _number(_equivalentDiameter.text) / 25.4
                : _number(_equivalentDiameter.text) * 25.4)
            .toStringAsFixed(toImperial ? 2 : 0);
    setState(() => _unitSystem = next);
    _calculate();
  }

  Future<void> _restore() async {
    final raw = ref.read(sharedPreferencesProvider).getString(_ductPrefsKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _condition = data['condition'] as String? ?? _condition;
        _unitSystem = data['unitSystem'] as String? ?? _unitSystem;
        _material = data['material'] as String? ?? _material;
        _shape = (data['shape'] as String?) == 'circular'
            ? YorksV1DuctShape.circular
            : YorksV1DuctShape.rectangular;
        _mode = YorksV1DuctSolveMode.values.firstWhere(
          (item) => item.name == data['mode'],
          orElse: () => YorksV1DuctSolveMode.checkSize,
        );
        for (final pair in <TextEditingController, String?>{
          _flow: data['flow'] as String?,
          _width: data['width'] as String?,
          _height: data['height'] as String?,
          _diameter: data['diameter'] as String?,
          _targetVelocity: data['targetVelocity'] as String?,
          _targetFriction: data['targetFriction'] as String?,
          _equivalentDiameter: data['equivalentDiameter'] as String?,
          _aspectRatio: data['aspectRatio'] as String?,
        }.entries) {
          if (pair.value != null) {
            pair.key.text = pair.value!;
          }
        }
      } catch (_) {
        // A corrupt local draft must never block the calculator.
      }
    }
    if (mounted) {
      setState(() {
        _restoring = false;
        _result = _calculate(notify: false);
      });
    }
  }

  Map<String, Object?> _json() => {
    'app': 'duct-calc',
    'version': 1,
    'savedAt': DateTime.now().toIso8601String(),
    'condition': _condition,
    'unitSystem': _unitSystem,
    'material': _material,
    'shape': _shape.name,
    'mode': _mode.name,
    'flow': _flow.text,
    'width': _width.text,
    'height': _height.text,
    'diameter': _diameter.text,
    'targetVelocity': _targetVelocity.text,
    'targetFriction': _targetFriction.text,
    'equivalentDiameter': _equivalentDiameter.text,
    'aspectRatio': _aspectRatio.text,
  };

  Future<void> _save() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_ductPrefsKey, jsonEncode(_json()));
    if (mounted) _snack('Calculation saved locally.');
  }

  Future<void> _open() async {
    await _restore();
    if (mounted) _snack('Saved calculation reopened.');
  }

  Future<void> _import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (file == null) return;
      final data =
          jsonDecode(utf8.decode(await file.readAsBytes()))
              as Map<String, dynamic>;
      await ref
          .read(sharedPreferencesProvider)
          .setString(_ductPrefsKey, jsonEncode(data));
      await _restore();
      if (mounted) _snack('Calculation imported.');
    } catch (_) {
      if (mounted) _snack('Could not import this JSON file.', error: true);
    }
  }

  Future<void> _export() => _saveFile(
    'Yorks-duct-calculation.json',
    utf8.encode(jsonEncode(_json())),
  );

  Future<void> _print() async {
    final result = _result ?? _calculate(notify: false);
    await Printing.layoutPdf(
      onLayout: (format) async => _buildDuctPdf(result, format),
    );
  }

  Future<void> _saveFile(String name, List<int> bytes) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(bytes),
      name: name,
      mimeType: _jsonMime,
    ).saveTo(location.path);
    if (mounted) _snack('File exported.');
  }

  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : AppColors.navy,
        ),
      );
}

class YorksV1EspCalculatorScreen extends ConsumerStatefulWidget {
  const YorksV1EspCalculatorScreen({super.key});

  @override
  ConsumerState<YorksV1EspCalculatorScreen> createState() =>
      _YorksV1EspCalculatorScreenState();
}

class _YorksV1EspCalculatorScreenState
    extends ConsumerState<YorksV1EspCalculatorScreen> {
  final _projectName = TextEditingController();
  final _projectNo = TextEditingController();
  final _systemNo = TextEditingController();
  final _revision = TextEditingController(text: 'A');
  final _date = TextEditingController(text: _dateText());
  final _equipment = TextEditingController();
  final _safety = TextEditingController(text: '10');
  final _rows = <YorksV1EspRow>[
    const YorksV1EspRow(id: 'esp-row-1', fitting: 'Straight Duct'),
  ];
  bool _restoring = true;

  static String _dateText() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restore);
  }

  @override
  void dispose() {
    for (final controller in [
      _projectName,
      _projectNo,
      _systemNo,
      _revision,
      _date,
      _equipment,
      _safety,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totals = YorksV1EngineeringCalculatorService.espTotals(
      _rows,
      _number(_safety.text),
    );
    return NexusPageShell(
      eyebrow: 'Engineering tools',
      title: 'ESP Calculator',
      description:
          'Create, save, reopen and print controlled external static pressure calculations.',
      actions: [
        _ToolbarButton(label: 'Save', onPressed: _save),
        _ToolbarButton(label: 'Open', onPressed: _open),
        _ToolbarButton(label: 'Import JSON', onPressed: _import),
        _ToolbarButton(label: 'Export JSON', onPressed: _export),
        _ToolbarButton(label: 'Fittings', onPressed: _showFittings),
        _ToolbarButton(label: 'Print', onPressed: _print, primary: true),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectBanner(onChanged: (_) {}, value: 'Independent calculation'),
          const SizedBox(height: AppSpacing.lg),
          _R35Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WorkspaceHeading(
                  kicker: 'External static pressure',
                  title: 'System calculation workspace',
                  description:
                      'Straight-duct losses use Darcy-Weisbach. Fittings use configurable K factors unless a manufacturer/manual ESP is entered.',
                  trailing: _Badge(
                    '${_rows.length} rows',
                    AppColors.blueContainer,
                  ),
                ),
                const Divider(height: 1),
                _EspHeader(
                  controllers: [
                    _projectName,
                    _projectNo,
                    _systemNo,
                    _revision,
                    _date,
                    _equipment,
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controls = Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _ToolbarButton(
                            label: 'Add Row',
                            icon: Icons.add,
                            onPressed: _addRow,
                          ),
                          _ToolbarButton(
                            label: 'Duplicate Last',
                            onPressed: _duplicateLast,
                          ),
                          _ToolbarButton(label: 'Clear', onPressed: _clear),
                        ],
                      );
                      final note = Text(
                        'Width/Height and Diameter are mutually exclusive. Manual ESP overrides the calculated value.',
                        style: AppTypography.bodySmall,
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            controls,
                            const SizedBox(height: AppSpacing.sm),
                            note,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: controls),
                          const SizedBox(width: AppSpacing.lg),
                          Flexible(child: note),
                        ],
                      );
                    },
                  ),
                ),
                if (totals.incompleteRows > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: _Warning(
                      '${totals.incompleteRows} incomplete row${totals.incompleteRows == 1 ? '' : 's'}. Enter the required duct data or a manufacturer/manual ESP value before issuing the final calculation.',
                    ),
                  ),
                _EspRows(
                  rows: _rows,
                  onChanged: _updateRow,
                  onDelete: _deleteRow,
                ),
                _EspSummary(
                  safety: _safety,
                  totals: totals,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (_restoring) const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  void _updateRow(YorksV1EspRow row) => setState(() {
    final index = _rows.indexWhere((item) => item.id == row.id);
    if (index >= 0) _rows[index] = row;
  });

  void _addRow() => setState(
    () => _rows.add(
      YorksV1EspRow(
        id: 'esp-row-${DateTime.now().microsecondsSinceEpoch}',
        fitting: 'Straight Duct',
      ),
    ),
  );
  void _duplicateLast() => setState(() {
    final last = _rows.last;
    _rows.add(
      last.copyWith(id: 'esp-row-${DateTime.now().microsecondsSinceEpoch}'),
    );
  });
  void _deleteRow(String id) => setState(() {
    if (_rows.length > 1) _rows.removeWhere((row) => row.id == id);
  });
  void _clear() => setState(() {
    _rows
      ..clear()
      ..add(const YorksV1EspRow(id: 'esp-row-1', fitting: 'Straight Duct'));
  });

  Map<String, Object?> _json() => {
    'app': 'esp-calc',
    'version': 1,
    'savedAt': DateTime.now().toIso8601String(),
    'header': {
      'projectName': _projectName.text,
      'projectNo': _projectNo.text,
      'systemNo': _systemNo.text,
      'revision': _revision.text,
      'date': _date.text,
      'equipment': _equipment.text,
    },
    'safetyFactor': _safety.text,
    'rows': _rows.map((row) => row.toJson()).toList(),
  };

  Future<void> _restore() async {
    final raw = ref.read(sharedPreferencesProvider).getString(_espPrefsKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final header = (data['header'] as Map?)?.cast<String, dynamic>() ?? {};
        _projectName.text = '${header['projectName'] ?? ''}';
        _projectNo.text = '${header['projectNo'] ?? ''}';
        _systemNo.text = '${header['systemNo'] ?? ''}';
        _revision.text = '${header['revision'] ?? 'A'}';
        _date.text = '${header['date'] ?? _dateText()}';
        _equipment.text = '${header['equipment'] ?? ''}';
        _safety.text = '${data['safetyFactor'] ?? '10'}';
        final rows = data['rows'];
        if (rows is List && rows.isNotEmpty) {
          _rows
            ..clear()
            ..addAll(
              rows.whereType<Map>().map(
                (item) => YorksV1EspRow.fromJson(
                  item.cast<String, Object?>(),
                  _rows.length,
                ),
              ),
            );
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _save() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_espPrefsKey, jsonEncode(_json()));
    if (mounted) _snack('Calculation saved locally.');
  }

  Future<void> _open() async {
    await _restore();
    if (mounted) _snack('Saved calculation reopened.');
  }

  Future<void> _import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'ESP JSON', extensions: ['json', 'espcalc.json']),
        ],
      );
      if (file == null) return;
      final data =
          jsonDecode(utf8.decode(await file.readAsBytes()))
              as Map<String, dynamic>;
      await ref
          .read(sharedPreferencesProvider)
          .setString(_espPrefsKey, jsonEncode(data));
      await _restore();
      if (mounted) _snack('Calculation imported.');
    } catch (_) {
      if (mounted) _snack('Could not import this JSON file.', error: true);
    }
  }

  Future<void> _export() => _saveFile(
    'Yorks-esp-calculation.espcalc.json',
    utf8.encode(jsonEncode(_json())),
  );
  Future<void> _saveFile(String name, List<int> bytes) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(bytes),
      name: name,
      mimeType: _jsonMime,
    ).saveTo(location.path);
    if (mounted) _snack('File exported.');
  }

  Future<void> _print() => Printing.layoutPdf(
    onLayout: (format) => _buildEspPdf(_rows, _number(_safety.text), format),
  );

  Future<void> _showFittings() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ESP Fitting Library'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: YorksV1EngineeringCalculatorService
              .fittingCoefficients
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text('K ${entry.value.toStringAsFixed(2)}'),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : AppColors.navy,
        ),
      );
}

class _EspRows extends StatelessWidget {
  const _EspRows({
    required this.rows,
    required this.onChanged,
    required this.onDelete,
  });
  final List<YorksV1EspRow> rows;
  final ValueChanged<YorksV1EspRow> onChanged;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 820
        ? Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _EspMobileRow(
                  index: i,
                  row: rows[i],
                  onChanged: onChanged,
                  onDelete: onDelete,
                ),
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  AppColors.surfaceContainerHigh,
                ),
                columnSpacing: 14,
                columns: const [
                  DataColumn(label: Text('No.')),
                  DataColumn(label: Text('Fitting Type')),
                  DataColumn(label: Text('Flow L/s')),
                  DataColumn(label: Text('Width mm')),
                  DataColumn(label: Text('Height mm')),
                  DataColumn(label: Text('Length m')),
                  DataColumn(label: Text('Diameter mm')),
                  DataColumn(label: Text('Manual ESP Pa')),
                  DataColumn(label: Text('ESP')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++) _desktopRow(i, rows[i]),
                ],
              ),
            ),
          ),
  );

  DataRow _desktopRow(int index, YorksV1EspRow row) {
    final result = YorksV1EngineeringCalculatorService.espRow(row);
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          _rowSelect(row, (value) => onChanged(row.copyWith(fitting: value))),
        ),
        DataCell(
          _cell(
            row,
            'flow',
            row.flowLitresPerSecond,
            (value) => onChanged(row.copyWith(flowLitresPerSecond: value)),
          ),
        ),
        DataCell(
          _cell(
            row,
            'width',
            row.widthMillimetres,
            (value) => onChanged(row.copyWith(widthMillimetres: value)),
          ),
        ),
        DataCell(
          _cell(
            row,
            'height',
            row.heightMillimetres,
            (value) => onChanged(row.copyWith(heightMillimetres: value)),
          ),
        ),
        DataCell(
          _cell(
            row,
            'length',
            row.lengthMetres,
            (value) => onChanged(row.copyWith(lengthMetres: value)),
            enabled: _lengthEnabled(row),
          ),
        ),
        DataCell(
          _cell(
            row,
            'diameter',
            row.diameterMillimetres,
            (value) => onChanged(row.copyWith(diameterMillimetres: value)),
            enabled:
                row.widthMillimetres.isEmpty && row.heightMillimetres.isEmpty,
          ),
        ),
        DataCell(
          _cell(
            row,
            'manual',
            row.manualEspPa,
            (value) => onChanged(row.copyWith(manualEspPa: value)),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result.complete
                    ? '${result.lossPa.toStringAsFixed(2)} Pa'
                    : '—',
              ),
              Text(result.source, style: AppTypography.labelSmall),
            ],
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () => onDelete(row.id),
            icon: const Icon(Icons.close),
            tooltip: 'Delete row',
          ),
        ),
      ],
    );
  }

  Widget _rowSelect(YorksV1EspRow row, ValueChanged<String> changed) =>
      DropdownButton<String>(
        value:
            YorksV1EngineeringCalculatorService.fittingCoefficients.containsKey(
              row.fitting,
            )
            ? row.fitting
            : 'Other',
        items: YorksV1EngineeringCalculatorService.fittingCoefficients.keys
            .map((key) => DropdownMenuItem(value: key, child: Text(key)))
            .toList(),
        onChanged: (value) {
          if (value != null) changed(value);
        },
      );

  Widget _cell(
    YorksV1EspRow row,
    String key,
    String initial,
    ValueChanged<String> changed, {
    bool enabled = true,
  }) => SizedBox(
    width: 100,
    child: _EspEditableField(
      key: ValueKey('${row.id}-$key'),
      value: initial,
      enabled: enabled,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: changed,
    ),
  );
  bool _lengthEnabled(YorksV1EspRow row) =>
      const {'Straight Duct', 'Reducer', 'Expansion'}.contains(row.fitting);
}

class _EspMobileRow extends StatelessWidget {
  const _EspMobileRow({
    required this.index,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final YorksV1EspRow row;
  final ValueChanged<YorksV1EspRow> onChanged;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final result = YorksV1EngineeringCalculatorService.espRow(row);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: _R35Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Line ${index + 1}', style: AppTypography.labelMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => onDelete(row.id),
                  icon: const Icon(Icons.close),
                  tooltip: 'Delete row',
                ),
              ],
            ),
            _rowSelect(context),
            const SizedBox(height: AppSpacing.sm),
            _R35FormGrid(
              children: [
                _mini(
                  'Flow L/s',
                  row.flowLitresPerSecond,
                  (value) =>
                      onChanged(row.copyWith(flowLitresPerSecond: value)),
                ),
                _mini(
                  'Width mm',
                  row.widthMillimetres,
                  (value) => onChanged(row.copyWith(widthMillimetres: value)),
                  enabled: row.diameterMillimetres.isEmpty,
                ),
                _mini(
                  'Height mm',
                  row.heightMillimetres,
                  (value) => onChanged(row.copyWith(heightMillimetres: value)),
                  enabled: row.diameterMillimetres.isEmpty,
                ),
                _mini(
                  'Length m',
                  row.lengthMetres,
                  (value) => onChanged(row.copyWith(lengthMetres: value)),
                  enabled: const {
                    'Straight Duct',
                    'Reducer',
                    'Expansion',
                  }.contains(row.fitting),
                ),
                _mini(
                  'Diameter mm',
                  row.diameterMillimetres,
                  (value) =>
                      onChanged(row.copyWith(diameterMillimetres: value)),
                  enabled:
                      row.widthMillimetres.isEmpty &&
                      row.heightMillimetres.isEmpty,
                ),
                _mini(
                  'Manual ESP Pa',
                  row.manualEspPa,
                  (value) => onChanged(row.copyWith(manualEspPa: value)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.complete ? '${result.lossPa.toStringAsFixed(2)} Pa' : '—',
              style: AppTypography.titleMedium,
            ),
            Text(result.source, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _rowSelect(BuildContext context) => DropdownButtonFormField<String>(
    initialValue:
        YorksV1EngineeringCalculatorService.fittingCoefficients.containsKey(
          row.fitting,
        )
        ? row.fitting
        : 'Other',
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Fitting Type',
      border: OutlineInputBorder(),
    ),
    items: YorksV1EngineeringCalculatorService.fittingCoefficients.keys
        .map((key) => DropdownMenuItem(value: key, child: Text(key)))
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(row.copyWith(fitting: value));
    },
  );
  Widget _mini(
    String label,
    String value,
    ValueChanged<String> changed, {
    bool enabled = true,
  }) => _EspEditableField(
    key: ValueKey('${row.id}-$label'),
    value: value,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onChanged: changed,
  );
}

/// A row editor must keep its identity while the parent recalculates totals.
/// Re-keying a TextFormField with its current value recreates its editable
/// state on every keystroke, which drops focus and makes typing appear to jump
/// between fields. This small stateful wrapper keeps the controller stable and
/// still accepts external values when a saved/imported row is reopened.
class _EspEditableField extends StatefulWidget {
  const _EspEditableField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool enabled;

  @override
  State<_EspEditableField> createState() => _EspEditableFieldState();
}

class _EspEditableFieldState extends State<_EspEditableField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EspEditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    enabled: widget.enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: widget.decoration,
    onChanged: widget.onChanged,
  );
}

class _DuctResults extends StatelessWidget {
  const _DuctResults({
    required this.result,
    required this.shape,
    required this.condition,
    required this.material,
    required this.unitSystem,
    required this.valid,
  });
  final YorksV1DuctCalculationResult result;
  final YorksV1DuctShape shape;
  final String condition;
  final String material;
  final String unitSystem;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final width = unitSystem == 'SI'
        ? result.widthMillimetres
        : result.widthMillimetres / 25.4;
    final height = unitSystem == 'SI'
        ? result.heightMillimetres
        : result.heightMillimetres / 25.4;
    final velocity = unitSystem == 'SI'
        ? result.velocityMetresPerSecond
        : result.velocityMetresPerSecond * 196.850394;
    final area = unitSystem == 'SI'
        ? result.areaSquareMetres
        : result.areaSquareMetres * 10.7639104;
    final pressure = unitSystem == 'SI'
        ? result.velocityPressurePa
        : result.velocityPressurePa / 249.08891;
    final friction = unitSystem == 'SI'
        ? result.frictionRatePaPerMetre
        : result.frictionRatePaPerMetre / 8.172803;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroResult(
            title: valid
                ? (shape == YorksV1DuctShape.circular
                      ? 'Checked duct size'
                      : 'Checked duct size')
                : 'Enter design parameters',
            value: valid
                ? (shape == YorksV1DuctShape.circular
                      ? '${width.toStringAsFixed(unitSystem == 'SI' ? 0 : 2)} ${unitSystem == 'SI' ? 'mm' : 'in'} diameter'
                      : '${width.toStringAsFixed(unitSystem == 'SI' ? 0 : 2)} × ${height.toStringAsFixed(unitSystem == 'SI' ? 0 : 2)} ${unitSystem == 'SI' ? 'mm' : 'in'}')
                : '—',
            note: '$condition · $material · Darcy-Weisbach',
          ),
          const SizedBox(height: AppSpacing.xl),
          _PanelHeading(
            kicker: 'Calculated results',
            title: 'Hydraulic Performance',
            trailing: _Badge(condition, AppColors.surfaceContainerHigh),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetricGrid(
            entries: [
              (
                'Equivalent diameter',
                '${_length(result.equivalentDiameterMetres * 1000)} ${unitSystem == 'SI' ? 'mm' : 'in'}',
                false,
              ),
              (
                'Hydraulic diameter',
                '${_length(result.hydraulicDiameterMetres * 1000)} ${unitSystem == 'SI' ? 'mm' : 'in'}',
                false,
              ),
              (
                'Flow area',
                '${area.toStringAsFixed(4)} ${unitSystem == 'SI' ? 'm²' : 'ft²'}',
                false,
              ),
              (
                'Fluid velocity',
                '${velocity.toStringAsFixed(3)} ${unitSystem == 'SI' ? 'm/s' : 'fpm'}',
                true,
              ),
              (
                'Reynolds number',
                result.reynoldsNumber.toStringAsFixed(0),
                false,
              ),
              (
                'Friction factor',
                result.frictionFactor.toStringAsFixed(4),
                false,
              ),
              (
                'Friction rate',
                '${friction.toStringAsFixed(3)} ${unitSystem == 'SI' ? 'Pa/m' : 'in.wg/100 ft'}',
                false,
              ),
              (
                'Velocity pressure',
                '${pressure.toStringAsFixed(3)} ${unitSystem == 'SI' ? 'Pa' : 'in.wg'}',
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _length(double mm) => unitSystem == 'SI'
      ? mm.toStringAsFixed(1)
      : (mm / 25.4).toStringAsFixed(2);
}

class _DuctBasisStrip extends StatelessWidget {
  const _DuctBasisStrip({
    required this.condition,
    required this.density,
    required this.viscosity,
    required this.specificHeat,
    required this.energyFactor,
  });
  final String condition;
  final double density;
  final double viscosity;
  final double specificHeat;
  final double energyFactor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final entries = [
        ('Design basis', condition, ''),
        ('Density', density.toStringAsFixed(4), 'kg/m³'),
        ('Viscosity', viscosity.toStringAsFixed(4), 'kg/m·h'),
        ('Specific heat', specificHeat.toStringAsFixed(4), 'kJ/kg·°C'),
        ('Energy factor', energyFactor.toStringAsFixed(2), 'W/°C·L/s'),
      ];
      return Wrap(
        children: [
          for (final entry in entries)
            SizedBox(
              width: constraints.maxWidth < 680
                  ? constraints.maxWidth / 2
                  : constraints.maxWidth / 5,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.$1.toUpperCase(),
                      style: AppTypography.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(entry.$2, style: AppTypography.titleMedium),
                    if (entry.$3.isNotEmpty)
                      Text(entry.$3, style: AppTypography.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _DuctModeStrip extends StatelessWidget {
  const _DuctModeStrip({required this.selected, required this.onChanged});
  final YorksV1DuctSolveMode selected;
  final ValueChanged<YorksV1DuctSolveMode> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children:
            [
                  _mode(
                    YorksV1DuctSolveMode.checkSize,
                    'Check Size',
                    'Known duct dimensions',
                    '01',
                  ),
                  _mode(
                    YorksV1DuctSolveMode.velocity,
                    'Size by Velocity',
                    'Target design velocity',
                    '02',
                  ),
                  _mode(
                    YorksV1DuctSolveMode.friction,
                    'Size by Friction',
                    'Target pressure loss',
                    '03',
                  ),
                  _mode(
                    YorksV1DuctSolveMode.equivalentDiameter,
                    'Equivalent Diameter',
                    'Known equivalent diameter',
                    '04',
                  ),
                ]
                .map(
                  (child) => SizedBox(
                    width: constraints.maxWidth < 740
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 4,
                    child: child,
                  ),
                )
                .toList(),
      ),
    ),
  );
  Widget _mode(
    YorksV1DuctSolveMode mode,
    String title,
    String caption,
    String number,
  ) => InkWell(
    onTap: () => onChanged(mode),
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    child: Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: selected == mode
            ? AppColors.blueContainer
            : AppColors.surfaceContainerLowest,
        border: Border.all(
          color: selected == mode ? AppColors.blue : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected == mode
                  ? AppColors.blue
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              number,
              style: AppTypography.labelSmall.copyWith(
                color: selected == mode ? Colors.white : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppTypography.labelLarge),
                Text(caption, style: AppTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EspHeader extends StatelessWidget {
  const _EspHeader({required this.controllers, required this.onChanged});
  final List<TextEditingController> controllers;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: _R35FormGrid(
      children: [
        for (var i = 0; i < controllers.length; i++)
          _NumberField(
            label: [
              'Project Name',
              'Project No.',
              'System No.',
              'Revision',
              'Date',
              'Equipment',
            ][i],
            controller: controllers[i],
            onChanged: onChanged,
            keyboard: i == 0 || i == 5
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
          ),
      ],
    ),
  );
}

class _EspSummary extends StatelessWidget {
  const _EspSummary({
    required this.safety,
    required this.totals,
    required this.onChanged,
  });
  final TextEditingController safety;
  final ({double subtotalPa, double finalPa, int incompleteRows}) totals;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.lg,
        children: [
          SizedBox(
            width: constraints.maxWidth < 620 ? constraints.maxWidth : 300,
            child: _NumberField(
              label: 'Safety Factor (%)',
              controller: safety,
              onChanged: onChanged,
            ),
          ),
          _TotalCard(
            label: 'Total external static pressure',
            pa: totals.subtotalPa,
          ),
          _TotalCard(
            label: 'Final ESP with safety factor',
            pa: totals.finalPa,
            dark: true,
          ),
        ],
      ),
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.pa, this.dark = false});
  final String label;
  final double pa;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: dark ? AppColors.navy : AppColors.surfaceContainerLowest,
      border: Border.all(color: dark ? AppColors.navy : AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: dark ? Colors.white70 : AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${pa.toStringAsFixed(2)} Pa',
          style: AppTypography.headlineSmall.copyWith(
            color: dark ? Colors.white : AppColors.ink,
          ),
        ),
        Text(
          '${(pa / 249.08891).toStringAsFixed(3)} in. wg',
          style: AppTypography.bodySmall.copyWith(
            color: dark ? Colors.white70 : AppColors.muted,
          ),
        ),
      ],
    ),
  );
}

class _ProjectBanner extends StatelessWidget {
  const _ProjectBanner({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => _R35Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = _SelectBox(
            value: value,
            items: const ['Independent calculation'],
            onChanged: onChanged,
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calculation Project', style: AppTypography.titleSmall),
              Text(
                'Keep saved calculations grouped by project and prefill the project header where available.',
                style: AppTypography.bodySmall,
              ),
            ],
          );
          return constraints.maxWidth < 680
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: AppSpacing.md),
                    selector,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(width: 380, child: selector),
                  ],
                );
        },
      ),
    ),
  );
}

class _WorkspaceHeading extends StatelessWidget {
  const _WorkspaceHeading({
    required this.kicker,
    required this.title,
    required this.description,
    required this.trailing,
  });
  final String kicker;
  final String title;
  final String description;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker.toUpperCase(), style: AppTypography.eyebrow),
            const SizedBox(height: 6),
            Text(title, style: AppTypography.headlineSmall),
            const SizedBox(height: 6),
            Text(description, style: AppTypography.bodyMedium),
          ],
        );
        return constraints.maxWidth < 680
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: AppSpacing.md),
                  trailing,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: trailing,
                    ),
                  ),
                ],
              );
      },
    ),
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.kicker,
    required this.title,
    required this.trailing,
  });
  final String kicker;
  final String title;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker.toUpperCase(), style: AppTypography.labelSmall),
            Text(title, style: AppTypography.titleLarge),
          ],
        ),
      ),
      trailing,
    ],
  );
}

class _R35FormGrid extends StatelessWidget {
  const _R35FormGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final child in children)
          SizedBox(
            width: constraints.maxWidth >= 560
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth,
            child: child,
          ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
    this.keyboard,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? suffix;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType:
        keyboard ?? const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      border: const OutlineInputBorder(),
    ),
  );
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: items
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class _ToggleField extends StatelessWidget {
  const _ToggleField({
    required this.label,
    required this.selected,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String selected;
  final List<String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    child: Row(
      children: [
        for (final item in items)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(item),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item == selected ? AppColors.blueContainer : null,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  item,
                  style: AppTypography.labelLarge.copyWith(
                    color: item == selected ? AppColors.blue : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    items: items
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => primary
      ? PrimaryButton(
          label: label,
          icon: icon,
          isExpanded: false,
          onPressed: onPressed,
        )
      : SecondaryButton(
          label: label,
          icon: icon,
          isExpanded: false,
          onPressed: onPressed,
        );
}

class _R35Card extends StatelessWidget {
  const _R35Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      label,
      style: AppTypography.labelLarge.copyWith(color: AppColors.blue),
    ),
  );
}

class _HeroResult extends StatelessWidget {
  const _HeroResult({
    required this.title,
    required this.value,
    required this.note,
  });
  final String title;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: AppTypography.displaySmall.copyWith(color: AppColors.navy),
        ),
        Text(note, style: AppTypography.bodySmall),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.entries});
  final List<(String, String, bool)> entries;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in entries)
          SizedBox(
            width: constraints.maxWidth >= 620
                ? (constraints.maxWidth - AppSpacing.sm) / 2
                : constraints.maxWidth,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: entry.$3
                    ? AppColors.blueContainer
                    : AppColors.surfaceContainerLowest,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.$1.toUpperCase(), style: AppTypography.labelSmall),
                  const SizedBox(height: 5),
                  Text(entry.$2, style: AppTypography.titleMedium),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Text(text, style: AppTypography.bodySmall),
  );
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningContainer,
      border: Border.all(color: const Color(0xFFE8C77D)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.onWarningContainer,
      ),
    ),
  );
}

double _number(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

Future<Uint8List> _buildDuctPdf(
  YorksV1DuctCalculationResult result,
  PdfPageFormat format,
) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: format,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'YORKS AC. & REF. · DUCT SIZER',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Checked duct size: ${result.widthMillimetres.toStringAsFixed(0)} × ${result.heightMillimetres.toStringAsFixed(0)} mm',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            data: [
              ['Metric', 'Value'],
              ['Flow area', '${result.areaSquareMetres.toStringAsFixed(4)} m²'],
              [
                'Velocity',
                '${result.velocityMetresPerSecond.toStringAsFixed(3)} m/s',
              ],
              [
                'Equivalent diameter',
                '${(result.equivalentDiameterMetres * 1000).toStringAsFixed(1)} mm',
              ],
              [
                'Friction rate',
                '${result.frictionRatePaPerMetre.toStringAsFixed(3)} Pa/m',
              ],
              [
                'Velocity pressure',
                '${result.velocityPressurePa.toStringAsFixed(3)} Pa',
              ],
            ],
          ),
          pw.Spacer(),
          pw.Text(
            'Engineering calculation aid. Final selections remain subject to responsible HVAC Engineer review.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );
  return document.save();
}

Future<Uint8List> _buildEspPdf(
  List<YorksV1EspRow> rows,
  double safety,
  PdfPageFormat format,
) async {
  final totals = YorksV1EngineeringCalculatorService.espTotals(rows, safety);
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (_) => [
        pw.Text(
          'YORKS AC. & REF. · EXTERNAL STATIC PRESSURE',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          data: [
            [
              'No.',
              'Fitting',
              'Flow L/s',
              'Width mm',
              'Height mm',
              'Length m',
              'Manual ESP',
              'Loss Pa',
            ],
            for (var i = 0; i < rows.length; i++)
              [
                '${i + 1}',
                rows[i].fitting,
                rows[i].flowLitresPerSecond,
                rows[i].widthMillimetres,
                rows[i].heightMillimetres,
                rows[i].lengthMetres,
                rows[i].manualEspPa,
                YorksV1EngineeringCalculatorService.espRow(
                  rows[i],
                ).lossPa.toStringAsFixed(2),
              ],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Total external static pressure: ${totals.subtotalPa.toStringAsFixed(2)} Pa',
        ),
        pw.Text('Safety factor: ${safety.toStringAsFixed(1)}%'),
        pw.Text('Final ESP: ${totals.finalPa.toStringAsFixed(2)} Pa'),
      ],
    ),
  );
  return document.save();
}
