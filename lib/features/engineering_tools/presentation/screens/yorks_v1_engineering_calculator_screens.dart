import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_engineering_tools.dart';
import '../../../../shared/models/yorks_v1_engineering_tools_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/services/yorks_v1_engineering_calculator_service.dart';

class YorksV1DuctSizerScreen extends ConsumerStatefulWidget {
  const YorksV1DuctSizerScreen({super.key});

  @override
  ConsumerState<YorksV1DuctSizerScreen> createState() =>
      _YorksV1DuctSizerScreenState();
}

class _YorksV1DuctSizerScreenState
    extends ConsumerState<YorksV1DuctSizerScreen> {
  final _airflow = TextEditingController(text: '1000');
  final _width = TextEditingController(text: '500');
  final _height = TextEditingController(text: '300');
  YorksV1DuctSizerResult? _result;
  bool _invalid = false;

  @override
  void dispose() {
    _airflow.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    return _CalculatorScaffold(
      title: YorksV1EngineeringToolsStrings.ductSizer,
      language: language,
      input: _CalculatorInputCard(
        fields: [
          _CalculatorField(
            controller: _airflow,
            label: YorksV1EngineeringToolsStrings.airflow,
          ),
          _CalculatorField(
            controller: _width,
            label: YorksV1EngineeringToolsStrings.width,
          ),
          _CalculatorField(
            controller: _height,
            label: YorksV1EngineeringToolsStrings.height,
          ),
        ],
        invalid: _invalid,
        onCalculate: _calculate,
      ),
      result: _result == null
          ? null
          : _DuctResultCard(result: _result!, language: language),
    );
  }

  void _calculate() {
    try {
      final result = YorksV1EngineeringCalculatorService.ductSizer(
        YorksV1DuctSizerInput(
          airflowLitresPerSecond: _number(_airflow.text),
          widthMillimetres: _number(_width.text),
          heightMillimetres: _number(_height.text),
        ),
      );
      setState(() {
        _result = result;
        _invalid = false;
      });
    } on ArgumentError {
      setState(() => _invalid = true);
    }
  }
}

class YorksV1EspCalculatorScreen extends ConsumerStatefulWidget {
  const YorksV1EspCalculatorScreen({super.key});

  @override
  ConsumerState<YorksV1EspCalculatorScreen> createState() =>
      _YorksV1EspCalculatorScreenState();
}

class _YorksV1EspCalculatorScreenState
    extends ConsumerState<YorksV1EspCalculatorScreen> {
  final _airflow = TextEditingController(text: '1000');
  final _width = TextEditingController(text: '500');
  final _height = TextEditingController(text: '300');
  final _length = TextEditingController(text: '20');
  final _friction = TextEditingController(text: '1');
  final _fittingCoefficient = TextEditingController(text: '1.5');
  final _margin = TextEditingController(text: '10');
  YorksV1EspCalculatorResult? _result;
  bool _invalid = false;

  @override
  void dispose() {
    _airflow.dispose();
    _width.dispose();
    _height.dispose();
    _length.dispose();
    _friction.dispose();
    _fittingCoefficient.dispose();
    _margin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    return _CalculatorScaffold(
      title: YorksV1EngineeringToolsStrings.espCalculator,
      language: language,
      input: _CalculatorInputCard(
        fields: [
          _CalculatorField(
            controller: _airflow,
            label: YorksV1EngineeringToolsStrings.airflow,
          ),
          _CalculatorField(
            controller: _width,
            label: YorksV1EngineeringToolsStrings.width,
          ),
          _CalculatorField(
            controller: _height,
            label: YorksV1EngineeringToolsStrings.height,
          ),
          _CalculatorField(
            controller: _length,
            label: YorksV1EngineeringToolsStrings.ductLength,
          ),
          _CalculatorField(
            controller: _friction,
            label: YorksV1EngineeringToolsStrings.frictionLoss,
          ),
          _CalculatorField(
            controller: _fittingCoefficient,
            label: YorksV1EngineeringToolsStrings.fittingCoefficient,
          ),
          _CalculatorField(
            controller: _margin,
            label: YorksV1EngineeringToolsStrings.safetyMargin,
          ),
        ],
        invalid: _invalid,
        onCalculate: _calculate,
      ),
      result: _result == null
          ? null
          : _EspResultCard(result: _result!, language: language),
    );
  }

  void _calculate() {
    try {
      final result = YorksV1EngineeringCalculatorService.esp(
        YorksV1EspCalculatorInput(
          airflowLitresPerSecond: _number(_airflow.text),
          widthMillimetres: _number(_width.text),
          heightMillimetres: _number(_height.text),
          ductLengthMetres: _number(_length.text),
          frictionLossPaPerMetre: _number(_friction.text),
          fittingLossCoefficient: _number(_fittingCoefficient.text),
          safetyMarginPercent: _number(_margin.text),
        ),
      );
      setState(() {
        _result = result;
        _invalid = false;
      });
    } on ArgumentError {
      setState(() => _invalid = true);
    }
  }
}

class _CalculatorScaffold extends StatelessWidget {
  const _CalculatorScaffold({
    required this.title,
    required this.language,
    required this.input,
    required this.result,
  });

  final TranslatableString title;
  final AppLanguage language;
  final Widget input;
  final Widget? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: BilingualText(
        english: title.primary,
        secondary: title.secondary(language),
        englishStyle: AppTypography.titleLarge.copyWith(
          fontWeight: FontWeight.w800,
        ),
        secondaryStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.muted,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NexusSectionCard(
                  child: BilingualText(
                    english:
                        YorksV1EngineeringToolsStrings.referenceOnly.primary,
                    secondary: YorksV1EngineeringToolsStrings.referenceOnly
                        .secondary(language),
                    englishStyle: AppTypography.bodyMedium,
                    secondaryStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                NexusSectionCard(child: input),
                if (result != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1EngineeringToolsStrings.results.primary,
                    child: result!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CalculatorInputCard extends StatelessWidget {
  const _CalculatorInputCard({
    required this.fields,
    required this.invalid,
    required this.onCalculate,
  });

  final List<Widget> fields;
  final bool invalid;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final field in fields)
              SizedBox(
                width: constraints.maxWidth >= 640
                    ? (constraints.maxWidth - AppSpacing.md) / 2
                    : constraints.maxWidth,
                child: field,
              ),
          ],
        ),
      ),
      if (invalid) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          YorksV1EngineeringToolsStrings.invalidInput.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: PrimaryButton(
          label: YorksV1EngineeringToolsStrings.calculate.primary,
          icon: Icons.calculate_outlined,
          isExpanded: false,
          onPressed: onCalculate,
        ),
      ),
    ],
  );
}

class _CalculatorField extends StatelessWidget {
  const _CalculatorField({required this.controller, required this.label});
  final TextEditingController controller;
  final TranslatableString label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label.primary,
      border: const OutlineInputBorder(),
    ),
  );
}

class _DuctResultCard extends StatelessWidget {
  const _DuctResultCard({required this.result, required this.language});
  final YorksV1DuctSizerResult result;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _ResultGrid(
    entries: [
      _ResultEntry(
        YorksV1EngineeringToolsStrings.area,
        _fixed(result.areaSquareMetres, 'm²'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.velocity,
        _fixed(result.velocityMetresPerSecond, 'm/s'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.hydraulicDiameter,
        _fixed(result.hydraulicDiameterMetres, 'm'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.equivalentDiameter,
        _fixed(result.equivalentDiameterMetres, 'm'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.reynolds,
        result.reynoldsNumber.toStringAsFixed(0),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.frictionFactor,
        result.frictionFactor.toStringAsFixed(4),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.frictionLoss,
        _fixed(result.frictionLossPaPerMetre, 'Pa/m'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.velocityPressure,
        _fixed(result.velocityPressurePa, 'Pa'),
      ),
    ],
  );
}

class _EspResultCard extends StatelessWidget {
  const _EspResultCard({required this.result, required this.language});
  final YorksV1EspCalculatorResult result;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _ResultGrid(
    entries: [
      _ResultEntry(
        YorksV1EngineeringToolsStrings.area,
        _fixed(result.areaSquareMetres, 'm²'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.velocity,
        _fixed(result.velocityMetresPerSecond, 'm/s'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.velocityPressure,
        _fixed(result.velocityPressurePa, 'Pa'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.ductFriction,
        _fixed(result.ductFrictionLossPa, 'Pa'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.fittingLoss,
        _fixed(result.fittingLossPa, 'Pa'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.systemLoss,
        _fixed(result.systemLossPa, 'Pa'),
      ),
      _ResultEntry(
        YorksV1EngineeringToolsStrings.designEsp,
        _fixed(result.designEspPa, 'Pa'),
      ),
    ],
  );
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.entries});
  final List<_ResultEntry> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final entry in entries)
          SizedBox(
            width: constraints.maxWidth >= 640
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label.primary,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.value,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ResultEntry {
  const _ResultEntry(this.label, this.value);
  final TranslatableString label;
  final String value;
}

double _number(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? double.nan;

String _fixed(double value, String unit) => '${value.toStringAsFixed(2)} $unit';
