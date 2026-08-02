import 'dart:math' as math;

import '../models/yorks_v1_engineering_tools.dart';

/// Deterministic, local engineering aids matching the approved R35 prototype.
/// These values never write BOQ, approval, stock or commercial state.
abstract final class YorksV1EngineeringCalculatorService {
  static const air20Density = 1.2014;
  static const air20ViscosityKgPerMetreHour = .0643;
  static const air20SpecificHeat = 1.0048;
  static const air20EnergyFactor = 1.21;

  static const fittingCoefficients = <String, double>{
    'Straight Duct': 0,
    'MD': .25,
    'VCD': .35,
    'MFD': .4,
    'Elbow 90°, 0 Spl': .75,
    'Elbow 45°': .35,
    'Tee 45˚ Entry': .55,
    'Wye - Symmetrical': .3,
    'Reducer': .25,
    'Expansion': .3,
    'Plenum - Supply': .1,
    'S.A': .25,
    'Grille': .6,
    'Filter': 1.2,
    'Coil': 1.4,
    'Silencer': .8,
    'Other': 0,
  };

  static YorksV1DuctCalculationResult ductCalculation(
    YorksV1DuctCalculationInput input,
  ) {
    final flow = _finiteOrZero(input.flowLitresPerSecond) / 1000;
    final density = _finiteOrZero(input.airDensityKgPerCubicMetre);
    final viscosity = _finiteOrZero(input.airViscosityKgPerMetreHour) / 3600;
    final roughness = _finiteOrZero(input.roughnessMillimetres) / 1000;
    final ratio = math.max(1, _finiteOrZero(input.aspectRatio));
    var width =
        _finiteOrZero(
          input.shape == YorksV1DuctShape.circular
              ? input.diameterMillimetres
              : input.widthMillimetres,
        ) /
        1000;
    var height =
        _finiteOrZero(
          input.shape == YorksV1DuctShape.circular
              ? input.diameterMillimetres
              : input.heightMillimetres,
        ) /
        1000;

    if (input.solveMode == YorksV1DuctSolveMode.velocity && flow > 0) {
      final target = math.max(
        .1,
        _finiteOrZero(input.targetVelocityMetresPerSecond),
      );
      final area = flow / target;
      if (input.shape == YorksV1DuctShape.circular) {
        width = math.sqrt(4 * area / math.pi);
        height = width;
      } else {
        height = math.sqrt(area / ratio);
        width = ratio * height;
      }
      width = _roundDimension(width);
      height = input.shape == YorksV1DuctShape.circular
          ? width
          : _roundDimension(height);
    } else if (input.solveMode == YorksV1DuctSolveMode.equivalentDiameter) {
      final equivalent = math.max(
        .025,
        _finiteOrZero(input.equivalentDiameterMillimetres) / 1000,
      );
      if (input.shape == YorksV1DuctShape.circular) {
        width = equivalent;
        height = equivalent;
      } else {
        final factor = 1.3 * math.pow(ratio, .625) / math.pow(ratio + 1, .25);
        height = equivalent / factor;
        width = ratio * height;
      }
      width = _roundDimension(width);
      height = input.shape == YorksV1DuctShape.circular
          ? width
          : _roundDimension(height);
    } else if (input.solveMode == YorksV1DuctSolveMode.friction && flow > 0) {
      final target = math.max(
        .001,
        _finiteOrZero(input.targetFrictionPaPerMetre),
      );
      var low = .025;
      var high = 5.0;
      for (var index = 0; index < 80; index++) {
        final middle = (low + high) / 2;
        final testWidth = input.shape == YorksV1DuctShape.circular
            ? middle
            : ratio * middle;
        final test = hydraulics(
          flow: flow,
          width: testWidth,
          height: middle,
          shape: input.shape,
          roughness: roughness,
          density: density,
          viscosity: viscosity,
        );
        if (test.frictionRatePaPerMetre > target) {
          low = middle;
        } else {
          high = middle;
        }
      }
      height = (low + high) / 2;
      width = input.shape == YorksV1DuctShape.circular
          ? height
          : ratio * height;
      width = _roundDimension(width);
      height = input.shape == YorksV1DuctShape.circular
          ? width
          : _roundDimension(height);
    }

    final values = hydraulics(
      flow: flow,
      width: width,
      height: height,
      shape: input.shape,
      roughness: roughness,
      density: density,
      viscosity: viscosity,
    );
    final valid =
        flow > 0 && width > 0 && height > 0 && density > 0 && viscosity > 0;
    return YorksV1DuctCalculationResult(
      widthMillimetres: width * 1000,
      heightMillimetres: height * 1000,
      areaSquareMetres: values.area,
      hydraulicDiameterMetres: values.hydraulicDiameter,
      equivalentDiameterMetres: values.equivalentDiameter,
      velocityMetresPerSecond: values.velocity,
      reynoldsNumber: values.reynolds,
      frictionFactor: values.frictionFactor,
      frictionRatePaPerMetre: values.frictionRatePaPerMetre,
      velocityPressurePa: values.velocityPressure,
      valid: valid && values.area > 0,
    );
  }

  /// The legacy one-shot API is retained for existing callers and tests.
  static YorksV1DuctSizerResult ductSizer(YorksV1DuctSizerInput input) {
    _requirePositive(input.airflowLitresPerSecond);
    _requirePositive(input.widthMillimetres);
    _requirePositive(input.heightMillimetres);
    final result = ductCalculation(
      YorksV1DuctCalculationInput(
        flowLitresPerSecond: input.airflowLitresPerSecond,
        widthMillimetres: input.widthMillimetres,
        heightMillimetres: input.heightMillimetres,
        diameterMillimetres: 0,
        shape: YorksV1DuctShape.rectangular,
        solveMode: YorksV1DuctSolveMode.checkSize,
        targetVelocityMetresPerSecond: 2.5,
        targetFrictionPaPerMetre: .8,
        equivalentDiameterMillimetres: 500,
        aspectRatio: 1,
        roughnessMillimetres: .15,
        // Keep the pre-R35 public wrapper numerically compatible with the
        // legacy service contract. The R35 worksheet uses the explicit air
        // preset above instead.
        airDensityKgPerCubicMetre: 1.2,
        airViscosityKgPerMetreHour: 1.81e-5 * 3600,
      ),
    );
    return YorksV1DuctSizerResult(
      areaSquareMetres: result.areaSquareMetres,
      velocityMetresPerSecond: result.velocityMetresPerSecond,
      hydraulicDiameterMetres: result.hydraulicDiameterMetres,
      equivalentDiameterMetres: result.equivalentDiameterMetres,
      reynoldsNumber: result.reynoldsNumber,
      frictionFactor: result.frictionFactor,
      frictionLossPaPerMetre: result.frictionRatePaPerMetre,
      velocityPressurePa: result.velocityPressurePa,
    );
  }

  static YorksV1EspRowResult espRow(YorksV1EspRow row, {double? coefficient}) {
    final manual = double.tryParse(row.manualEspPa.trim().replaceAll(',', '.'));
    if (manual != null && manual.isFinite && manual >= 0) {
      return YorksV1EspRowResult(
        lossPa: manual,
        complete: true,
        source: 'Manual pressure loss',
      );
    }
    final fitting = row.fitting;
    final ruleIsManual = {
      'Plenum - Supply',
      'S.A',
      'Filter',
      'Coil',
      'Silencer',
      'Other',
    }.contains(fitting);
    if (ruleIsManual) {
      return const YorksV1EspRowResult(
        lossPa: 0,
        complete: false,
        source: 'Manual ESP required',
      );
    }
    final flow = _number(row.flowLitresPerSecond) / 1000;
    final width = _number(row.widthMillimetres);
    final height = _number(row.heightMillimetres);
    final diameter = _number(row.diameterMillimetres);
    final circular = diameter > 0 && width <= 0 && height <= 0;
    final rectangular = !circular && width > 0 && height > 0;
    if (flow <= 0 || (!circular && !rectangular)) {
      return const YorksV1EspRowResult(
        lossPa: 0,
        complete: false,
        source: 'Flow and duct dimensions required',
      );
    }
    final result = hydraulics(
      flow: flow,
      width: (circular ? diameter : width) / 1000,
      height: (circular ? diameter : height) / 1000,
      shape: circular
          ? YorksV1DuctShape.circular
          : YorksV1DuctShape.rectangular,
      roughness: .00015,
      density: air20Density,
      viscosity: air20ViscosityKgPerMetreHour / 3600,
    );
    if (fitting == 'Straight Duct') {
      final length = _number(row.lengthMetres);
      if (length <= 0) {
        return const YorksV1EspRowResult(
          lossPa: 0,
          complete: false,
          source: 'Duct length required',
        );
      }
      return YorksV1EspRowResult(
        lossPa: result.frictionRatePaPerMetre * length,
        complete: true,
        source: 'Darcy-Weisbach duct friction',
      );
    }
    final k = coefficient ?? fittingCoefficients[fitting] ?? 0;
    return YorksV1EspRowResult(
      lossPa: k * result.velocityPressure,
      complete: true,
      source: 'K ${k.toStringAsFixed(2)} × velocity pressure',
    );
  }

  static ({double subtotalPa, double finalPa, int incompleteRows}) espTotals(
    Iterable<YorksV1EspRow> rows,
    double safetyFactorPercent,
  ) {
    final results = rows.map(espRow).toList(growable: false);
    final subtotal = results.fold<double>(0, (sum, row) => sum + row.lossPa);
    final factor = math.max(0, _finiteOrZero(safetyFactorPercent));
    return (
      subtotalPa: subtotal,
      finalPa: subtotal * (1 + factor / 100),
      incompleteRows: results.where((row) => !row.complete).length,
    );
  }

  /// Legacy ESP API for callers outside the R35 worksheet.
  static YorksV1EspCalculatorResult esp(YorksV1EspCalculatorInput input) {
    _requirePositive(input.airflowLitresPerSecond);
    _requirePositive(input.widthMillimetres);
    _requirePositive(input.heightMillimetres);
    _requireNonNegative(input.ductLengthMetres);
    _requireNonNegative(input.frictionLossPaPerMetre);
    _requireNonNegative(input.fittingLossCoefficient);
    _requireNonNegative(input.safetyMarginPercent);
    final flow = input.airflowLitresPerSecond / 1000;
    final area =
        input.widthMillimetres / 1000 * (input.heightMillimetres / 1000);
    final velocity = flow / area;
    final pressure = .5 * 1.2 * velocity * velocity;
    final duct = input.ductLengthMetres * input.frictionLossPaPerMetre;
    final fitting = input.fittingLossCoefficient * pressure;
    final system = duct + fitting;
    return YorksV1EspCalculatorResult(
      areaSquareMetres: area,
      velocityMetresPerSecond: velocity,
      velocityPressurePa: pressure,
      ductFrictionLossPa: duct,
      fittingLossPa: fitting,
      systemLossPa: system,
      designEspPa: system * (1 + input.safetyMarginPercent / 100),
    );
  }

  static ({
    double area,
    double hydraulicDiameter,
    double equivalentDiameter,
    double velocity,
    double reynolds,
    double frictionFactor,
    double velocityPressure,
    double frictionRatePaPerMetre,
  })
  hydraulics({
    required double flow,
    required double width,
    required double height,
    required YorksV1DuctShape shape,
    required double roughness,
    required double density,
    required double viscosity,
  }) {
    final area = shape == YorksV1DuctShape.circular
        ? math.pi * width * width / 4
        : width * height;
    final hydraulic = shape == YorksV1DuctShape.circular
        ? width
        : (width + height) > 0
        ? 2 * width * height / (width + height)
        : 0;
    final equivalent = shape == YorksV1DuctShape.circular
        ? width
        : (width > 0 && height > 0)
        ? 1.3 * math.pow(width * height, .625) / math.pow(width + height, .25)
        : 0;
    final velocity = area > 0 ? flow / area : 0;
    final reynolds = viscosity > 0 && hydraulic > 0
        ? density * velocity * hydraulic / viscosity
        : 0;
    final frictionFactor = reynolds > 0
        ? reynolds < 2300
              ? 64 / reynolds
              : .25 /
                    math.pow(
                      math.log(
                            roughness / (3.7 * hydraulic) +
                                5.74 / math.pow(reynolds, .9),
                          ) /
                          math.ln10,
                      2,
                    )
        : 0;
    final velocityPressure = .5 * density * velocity * velocity;
    final frictionRate = hydraulic > 0
        ? frictionFactor * velocityPressure / hydraulic
        : 0;
    return (
      area: area,
      hydraulicDiameter: hydraulic.toDouble(),
      equivalentDiameter: equivalent.toDouble(),
      velocity: velocity.toDouble(),
      reynolds: reynolds.toDouble(),
      frictionFactor: frictionFactor.toDouble(),
      velocityPressure: velocityPressure.toDouble(),
      frictionRatePaPerMetre: frictionRate.toDouble(),
    );
  }

  static double _roundDimension(double metres) =>
      math.max(.025, (metres * 1000 / 25).ceil() * 25 / 1000);

  static double _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  static double _finiteOrZero(double value) => value.isFinite ? value : 0;

  static void _requirePositive(double value) {
    if (!value.isFinite || value <= 0) throw ArgumentError.value(value);
  }

  static void _requireNonNegative(double value) {
    if (!value.isFinite || value < 0) throw ArgumentError.value(value);
  }
}
