import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_engineering_tools.dart';
import 'package:material_ledger/shared/services/yorks_v1_engineering_calculator_service.dart';

void main() {
  test('R35 duct check matches the prototype 20°C air example', () {
    final result = YorksV1EngineeringCalculatorService.ductCalculation(
      const YorksV1DuctCalculationInput(
        flowLitresPerSecond: 2753,
        widthMillimetres: 900,
        heightMillimetres: 700,
        diameterMillimetres: 500,
        shape: YorksV1DuctShape.rectangular,
        solveMode: YorksV1DuctSolveMode.checkSize,
        targetVelocityMetresPerSecond: 2.5,
        targetFrictionPaPerMetre: .8,
        equivalentDiameterMillimetres: 500,
        aspectRatio: 1,
        roughnessMillimetres: .15,
        airDensityKgPerCubicMetre: 1.2014,
        airViscosityKgPerMetreHour: .0643,
      ),
    );

    expect(result.valid, isTrue);
    expect(result.widthMillimetres, 900);
    expect(result.heightMillimetres, 700);
    expect(result.equivalentDiameterMetres, closeTo(.866, .002));
    expect(result.velocityMetresPerSecond, closeTo(4.37, .01));
    expect(result.reynoldsNumber, closeTo(231470, 1500));
    expect(result.frictionFactor, closeTo(.0167, .001));
  });

  test('ESP rows enforce fitting rules and manual overrides', () {
    const straight = YorksV1EspRow(
      id: 'straight',
      fitting: 'Straight Duct',
      flowLitresPerSecond: '1000',
      widthMillimetres: '500',
      heightMillimetres: '300',
      lengthMetres: '20',
    );
    final calculated = YorksV1EngineeringCalculatorService.espRow(straight);
    expect(calculated.complete, isTrue);
    expect(calculated.lossPa, greaterThan(0));

    const manual = YorksV1EspRow(
      id: 'manual',
      fitting: 'Filter',
      manualEspPa: '33.1',
    );
    final overridden = YorksV1EngineeringCalculatorService.espRow(manual);
    expect(overridden.complete, isTrue);
    expect(overridden.lossPa, 33.1);

    final incomplete = straight.copyWith(lengthMetres: '');
    expect(
      YorksV1EngineeringCalculatorService.espRow(incomplete).complete,
      isFalse,
    );
  });
}
