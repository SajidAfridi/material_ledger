import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';

class YorksV1RequestInformationButton extends StatelessWidget {
  const YorksV1RequestInformationButton({
    super.key,
    required this.request,
    required this.language,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSpacing.minTapTarget,
    child: OutlinedButton.icon(
      key: const ValueKey('material-request-information-action'),
      onPressed: () => showYorksV1RequestInformation(
        context,
        request: request,
        language: language,
      ),
      icon: const Icon(Icons.info_outline_rounded, size: 19),
      label: Text(
        YorksV1MaterialRequestStrings.requestInformation.active(language),
      ),
    ),
  );
}

class YorksV1RequestInformationToolbar extends StatelessWidget {
  const YorksV1RequestInformationToolbar({
    super.key,
    required this.request,
    required this.language,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    alignment: AlignmentDirectional.centerEnd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xs,
    ),
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: YorksV1RequestInformationButton(
      request: request,
      language: language,
    ),
  );
}

Future<void> showYorksV1RequestInformation(
  BuildContext context, {
  required YorksV1MaterialRequest request,
  required AppLanguage language,
}) {
  final content = _RequestInformationContent(
    request: request,
    language: language,
  );
  if (MediaQuery.sizeOf(context).width <= 720) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: .86, child: content),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: content,
      ),
    ),
  );
}

class _RequestInformationContent extends StatelessWidget {
  const _RequestInformationContent({
    required this.request,
    required this.language,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final requestTitle = request.title?.trim();
    final requestedBy = request.requesterDisplayName?.trim();
    final role = request.requesterExactRole ?? request.requesterProjectRole;
    final owner = request.currentActionOwnerRole?.trim();
    final scheduledDate = request.scheduledDate == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(request.scheduledDate!.toLocal());
    return Directionality(
      textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.blue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    YorksV1MaterialRequestStrings.requestInformation.active(
                      language,
                    ),
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.requestNumber.active(
                      language,
                    ),
                    value: request.requestNumber ?? '—',
                  ),
                  if (requestTitle != null && requestTitle.isNotEmpty)
                    _InformationFact(
                      label: YorksV1MaterialRequestStrings.requestTitle.active(
                        language,
                      ),
                      value: requestTitle,
                    ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.project.active(
                      language,
                    ),
                    value: request.projectName,
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.projectReference
                        .active(language),
                    value: request.projectReference,
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.scope.active(language),
                    value: request.scopeName,
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.requestedBy.active(
                      language,
                    ),
                    value: requestedBy == null || requestedBy.isEmpty
                        ? '—'
                        : requestedBy,
                    supporting: role == null || role.trim().isEmpty
                        ? null
                        : YorksV1ProjectStrings.roleLabel(
                            role,
                          ).active(language),
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.deliveryType.active(
                      language,
                    ),
                    value: yorksV1MaterialRequestTimingCopy(
                      request.timing,
                    ).active(language),
                    supporting: scheduledDate,
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.state.active(language),
                    value: yorksV1MaterialRequestStateCopy(
                      request.state,
                    ).active(language),
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.currentOwner.active(
                      language,
                    ),
                    value: owner == null || owner.isEmpty
                        ? '—'
                        : YorksV1ProjectStrings.roleLabel(
                            owner,
                          ).active(language),
                  ),
                  _InformationFact(
                    label: YorksV1MaterialRequestStrings.nextAction.active(
                      language,
                    ),
                    value: yorksV1MaterialRequestNextActionCopy(
                      request,
                    ).active(language),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationFact extends StatelessWidget {
  const _InformationFact({
    required this.label,
    required this.value,
    this.supporting,
    this.last = false,
  });

  final String label;
  final String value;
  final String? supporting;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value.trim().isEmpty ? '—' : value,
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        if (supporting?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            supporting!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}
