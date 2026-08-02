import 'dart:math' as math;

import '../models/yorks_v1_engineering_tools.dart';

/// Reference HVAC calculations retained from the approved R35 prototype.
/// They are deliberately local, unpersisted and never an authority for BOQ,
/// material, approval, pricing or design decisions.
abstract final class YorksV1EngineeringCalculatorService {
  static const _airDensityKgPerCubicMetre = 1.2;
  static const _airDynamicViscosity = 1.81e-5;
  static const _ductRoughnessMetres = 0.00015;

  static YorksV1DuctSizerResult ductSizer(YorksV1DuctSizerInput input) {
    _requirePositive(input.airflowLitresPerSecond);
    _requirePositive(input.widthMillimetres);
    _requirePositive(input.heightMillimetres);

    final flow = input.airflowLitresPerSecond / 1000;
    final width = input.widthMillimetres / 1000;
    final height = input.heightMillimetres / 1000;
    final area = width * height;
    final velocity = flow / area;
    final hydraulicDiameter = 2 * width * height / (width + height);
    final equivalentDiameter =
        1.3 * math.pow(width * height, .625) / math.pow(width + height, .25);
    final reynolds =
        _airDensityKgPerCubicMetre *
        velocity *
        hydraulicDiameter /
        _airDynamicViscosity;
    final frictionFactor =
        .25 /
        math.pow(
          math.log(
                _ductRoughnessMetres / (3.7 * hydraulicDiameter) +
                    5.74 / math.pow(reynolds, .9),
              ) /
              math.ln10,
          2,
        );
    final velocityPressure =
        .5 * _airDensityKgPerCubicMetre * velocity * velocity;
    final frictionLoss = frictionFactor * velocityPressure / hydraulicDiameter;
    return YorksV1DuctSizerResult(
      areaSquareMetres: area,
      velocityMetresPerSecond: velocity,
      hydraulicDiameterMetres: hydraulicDiameter,
      equivalentDiameterMetres: equivalentDiameter.toDouble(),
      reynoldsNumber: reynolds,
      frictionFactor: frictionFactor,
      frictionLossPaPerMetre: frictionLoss,
      velocityPressurePa: velocityPressure,
    );
  }

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
        (input.widthMillimetres / 1000) * (input.heightMillimetres / 1000);
    final velocity = flow / area;
    final velocityPressure =
        .5 * _airDensityKgPerCubicMetre * velocity * velocity;
    final ductFriction = input.ductLengthMetres * input.frictionLossPaPerMetre;
    final fittingLoss = input.fittingLossCoefficient * velocityPressure;
    final systemLoss = ductFriction + fittingLoss;
    return YorksV1EspCalculatorResult(
      areaSquareMetres: area,
      velocityMetresPerSecond: velocity,
      velocityPressurePa: velocityPressure,
      ductFrictionLossPa: ductFriction,
      fittingLossPa: fittingLoss,
      systemLossPa: systemLoss,
      designEspPa: systemLoss * (1 + input.safetyMarginPercent / 100),
    );
  }

  static void _requirePositive(double value) {
    if (!value.isFinite || value <= 0) throw ArgumentError.value(value);
  }

  static void _requireNonNegative(double value) {
    if (!value.isFinite || value < 0) throw ArgumentError.value(value);
  }
}
