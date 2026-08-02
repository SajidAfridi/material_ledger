class YorksV1DuctSizerInput {
  const YorksV1DuctSizerInput({
    required this.airflowLitresPerSecond,
    required this.widthMillimetres,
    required this.heightMillimetres,
  });

  final double airflowLitresPerSecond;
  final double widthMillimetres;
  final double heightMillimetres;
}

class YorksV1DuctSizerResult {
  const YorksV1DuctSizerResult({
    required this.areaSquareMetres,
    required this.velocityMetresPerSecond,
    required this.hydraulicDiameterMetres,
    required this.equivalentDiameterMetres,
    required this.reynoldsNumber,
    required this.frictionFactor,
    required this.frictionLossPaPerMetre,
    required this.velocityPressurePa,
  });

  final double areaSquareMetres;
  final double velocityMetresPerSecond;
  final double hydraulicDiameterMetres;
  final double equivalentDiameterMetres;
  final double reynoldsNumber;
  final double frictionFactor;
  final double frictionLossPaPerMetre;
  final double velocityPressurePa;
}

class YorksV1EspCalculatorInput {
  const YorksV1EspCalculatorInput({
    required this.airflowLitresPerSecond,
    required this.widthMillimetres,
    required this.heightMillimetres,
    required this.ductLengthMetres,
    required this.frictionLossPaPerMetre,
    required this.fittingLossCoefficient,
    required this.safetyMarginPercent,
  });

  final double airflowLitresPerSecond;
  final double widthMillimetres;
  final double heightMillimetres;
  final double ductLengthMetres;
  final double frictionLossPaPerMetre;
  final double fittingLossCoefficient;
  final double safetyMarginPercent;
}

class YorksV1EspCalculatorResult {
  const YorksV1EspCalculatorResult({
    required this.areaSquareMetres,
    required this.velocityMetresPerSecond,
    required this.velocityPressurePa,
    required this.ductFrictionLossPa,
    required this.fittingLossPa,
    required this.systemLossPa,
    required this.designEspPa,
  });

  final double areaSquareMetres;
  final double velocityMetresPerSecond;
  final double velocityPressurePa;
  final double ductFrictionLossPa;
  final double fittingLossPa;
  final double systemLossPa;
  final double designEspPa;
}
