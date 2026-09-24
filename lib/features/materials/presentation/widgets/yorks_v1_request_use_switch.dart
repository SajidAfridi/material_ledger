import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';

/// One Material Requests workspace, with explicit operational contexts.
/// This is navigation only; each destination retains its protected projection.
class YorksV1RequestUseSwitch extends StatelessWidget {
  const YorksV1RequestUseSwitch({
    required this.company,
    required this.language,
    super.key,
  });

  final bool company;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: SegmentedButton<bool>(
        key: const ValueKey('material-request-use-switch'),
        direction:
            MediaQuery.sizeOf(context).width < 600 &&
                MediaQuery.textScalerOf(context).scale(14) > 20
            ? Axis.vertical
            : Axis.horizontal,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          visualDensity: VisualDensity.standard,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.blueContainer
                : AppColors.surfaceContainerLowest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.ink,
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.labelLarge),
        ),
        showSelectedIcon: true,
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.domain_outlined),
            label: Text(
              YorksV1CompanyMaterialRequestStrings.projectUse.active(language),
            ),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.business_center_outlined),
            label: Text(
              YorksV1CompanyMaterialRequestStrings.companyUse.active(language),
            ),
          ),
        ],
        selected: {company},
        onSelectionChanged: (value) => context.go(
          value.single
              ? '/yorks/material-requests/company'
              : '/yorks/material-requests',
        ),
      ),
    ),
  );
}
