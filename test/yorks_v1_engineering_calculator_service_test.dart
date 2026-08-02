import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_engineering_tools.dart';
import 'package:material_ledger/shared/services/yorks_v1_engineering_calculator_service.dart';

void main() {
  test('duct sizer follows the approved reference formula', () {
    final result = YorksV1EngineeringCalculatorService.ductSizer(
      const YorksV1DuctSizerInput(
        airflowLitresPerSecond: 1000,
        widthMillimetres: 500,
        heightMillimetres: 300,
      ),
    );

    expect(result.areaSquareMetres, closeTo(.15, .0001));
    expect(result.velocityMetresPerSecond, closeTo(6.6667, .0001));
    expect(result.hydraulicDiameterMetres, closeTo(.375, .0001));
    expect(result.frictionLossPaPerMetre, greaterThan(0));
    expect(result.velocityPressurePa, closeTo(26.6667, .0001));
  });

  test('ESP applies duct, fitting and safety-margin losses', () {
    final result = YorksV1EngineeringCalculatorService.esp(
      const YorksV1EspCalculatorInput(
        airflowLitresPerSecond: 1000,
        widthMillimetres: 500,
        heightMillimetres: 300,
        ductLengthMetres: 20,
        frictionLossPaPerMetre: 1,
        fittingLossCoefficient: 1.5,
        safetyMarginPercent: 10,
      ),
    );

    expect(result.ductFrictionLossPa, 20);
    expect(result.fittingLossPa, closeTo(40, .0001));
    expect(result.systemLossPa, closeTo(60, .0001));
    expect(result.designEspPa, closeTo(66, .0001));
  });

  test('calculators reject invalid physical inputs', () {
    expect(
      () => YorksV1EngineeringCalculatorService.ductSizer(
        const YorksV1DuctSizerInput(
          airflowLitresPerSecond: 0,
          widthMillimetres: 500,
          heightMillimetres: 300,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => YorksV1EngineeringCalculatorService.esp(
        const YorksV1EspCalculatorInput(
          airflowLitresPerSecond: 1000,
          widthMillimetres: 500,
          heightMillimetres: 300,
          ductLengthMetres: -1,
          frictionLossPaPerMetre: 1,
          fittingLossCoefficient: 1,
          safetyMarginPercent: 10,
        ),
      ),
      throwsArgumentError,
    );
  });
}
