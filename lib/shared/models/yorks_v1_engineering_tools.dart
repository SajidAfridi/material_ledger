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

/// The controlled R35 duct workspace input.  Values are kept in SI units so
/// the same calculation is deterministic on desktop, web and Android; the UI
/// converts the displayed values when Imperial units are selected.
class YorksV1DuctCalculationInput {
  const YorksV1DuctCalculationInput({
    required this.flowLitresPerSecond,
    required this.widthMillimetres,
    required this.heightMillimetres,
    required this.diameterMillimetres,
    required this.shape,
    required this.solveMode,
    required this.targetVelocityMetresPerSecond,
    required this.targetFrictionPaPerMetre,
    required this.equivalentDiameterMillimetres,
    required this.aspectRatio,
    required this.roughnessMillimetres,
    required this.airDensityKgPerCubicMetre,
    required this.airViscosityKgPerMetreHour,
  });

  final double flowLitresPerSecond;
  final double widthMillimetres;
  final double heightMillimetres;
  final double diameterMillimetres;
  final YorksV1DuctShape shape;
  final YorksV1DuctSolveMode solveMode;
  final double targetVelocityMetresPerSecond;
  final double targetFrictionPaPerMetre;
  final double equivalentDiameterMillimetres;
  final double aspectRatio;
  final double roughnessMillimetres;
  final double airDensityKgPerCubicMetre;
  final double airViscosityKgPerMetreHour;
}

enum YorksV1DuctShape { rectangular, circular }

enum YorksV1DuctSolveMode { checkSize, velocity, friction, equivalentDiameter }

class YorksV1DuctCalculationResult {
  const YorksV1DuctCalculationResult({
    required this.widthMillimetres,
    required this.heightMillimetres,
    required this.areaSquareMetres,
    required this.hydraulicDiameterMetres,
    required this.equivalentDiameterMetres,
    required this.velocityMetresPerSecond,
    required this.reynoldsNumber,
    required this.frictionFactor,
    required this.frictionRatePaPerMetre,
    required this.velocityPressurePa,
    required this.valid,
  });

  final double widthMillimetres;
  final double heightMillimetres;
  final double areaSquareMetres;
  final double hydraulicDiameterMetres;
  final double equivalentDiameterMetres;
  final double velocityMetresPerSecond;
  final double reynoldsNumber;
  final double frictionFactor;
  final double frictionRatePaPerMetre;
  final double velocityPressurePa;
  final bool valid;
}

class YorksV1EspRow {
  const YorksV1EspRow({
    required this.id,
    required this.fitting,
    this.flowLitresPerSecond = '',
    this.widthMillimetres = '',
    this.heightMillimetres = '',
    this.lengthMetres = '',
    this.diameterMillimetres = '',
    this.manualEspPa = '',
  });

  final String id;
  final String fitting;
  final String flowLitresPerSecond;
  final String widthMillimetres;
  final String heightMillimetres;
  final String lengthMetres;
  final String diameterMillimetres;
  final String manualEspPa;

  YorksV1EspRow copyWith({
    String? id,
    String? fitting,
    String? flowLitresPerSecond,
    String? widthMillimetres,
    String? heightMillimetres,
    String? lengthMetres,
    String? diameterMillimetres,
    String? manualEspPa,
  }) => YorksV1EspRow(
    id: id ?? this.id,
    fitting: fitting ?? this.fitting,
    flowLitresPerSecond: flowLitresPerSecond ?? this.flowLitresPerSecond,
    widthMillimetres: widthMillimetres ?? this.widthMillimetres,
    heightMillimetres: heightMillimetres ?? this.heightMillimetres,
    lengthMetres: lengthMetres ?? this.lengthMetres,
    diameterMillimetres: diameterMillimetres ?? this.diameterMillimetres,
    manualEspPa: manualEspPa ?? this.manualEspPa,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'fitting': fitting,
    'flow': flowLitresPerSecond,
    'width': widthMillimetres,
    'height': heightMillimetres,
    'length': lengthMetres,
    'diameter': diameterMillimetres,
    'manualEsp': manualEspPa,
  };

  factory YorksV1EspRow.fromJson(Map<String, Object?> json, int index) =>
      YorksV1EspRow(
        id:
            (json['id'] as String?) ??
            'esp-row-${DateTime.now().microsecondsSinceEpoch}-$index',
        fitting: (json['fitting'] as String?) ?? 'Straight Duct',
        flowLitresPerSecond: '${json['flow'] ?? ''}',
        widthMillimetres: '${json['width'] ?? ''}',
        heightMillimetres: '${json['height'] ?? ''}',
        lengthMetres: '${json['length'] ?? ''}',
        diameterMillimetres: '${json['diameter'] ?? ''}',
        manualEspPa: '${json['manualEsp'] ?? ''}',
      );
}

class YorksV1EspRowResult {
  const YorksV1EspRowResult({
    required this.lossPa,
    required this.complete,
    required this.source,
  });

  final double lossPa;
  final bool complete;
  final String source;
}
