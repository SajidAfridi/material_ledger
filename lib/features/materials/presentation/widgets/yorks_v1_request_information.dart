import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/widgets/yorks_panel_toggle_icon.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import 'yorks_v1_material_request_history.dart';

class YorksV1RequestInformationButton extends StatefulWidget {
  const YorksV1RequestInformationButton({
    super.key,
    required this.request,
    required this.language,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  State<YorksV1RequestInformationButton> createState() =>
      _RequestInformationButtonState();
}

class _RequestInformationButtonState
    extends State<YorksV1RequestInformationButton> {
  bool _open = false;

  Future<void> _show() async {
    if (_open) return;
    setState(() => _open = true);
    try {
      await showYorksV1RequestInformation(
        context,
        request: widget.request,
        language: widget.language,
      );
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: _open,
    child: SizedBox(
      height: AppSpacing.minTapTarget,
      child: OutlinedButton.icon(
        key: const ValueKey('material-request-information-action'),
        onPressed: _show,
        style: _open
            ? OutlinedButton.styleFrom(backgroundColor: AppColors.blueContainer)
            : null,
        icon: YorksPanelToggleIcon(expanded: _open, atEnd: true),
        label: Text(
          YorksV1MaterialRequestStrings.requestInformation.active(
            widget.language,
          ),
        ),
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

/// One responsive, full-height overlay for the saved MR workflow. Resizing
/// recomputes panel bounds without replacing route content or working editors.
Future<void> showYorksV1RequestInformationPanel(
  BuildContext context, {
  required AppLanguage language,
  required WidgetBuilder builder,
}) => showGeneralDialog<void>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: AppColors.scrim.withValues(alpha: .18),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180),
  pageBuilder: (dialogContext, _, _) => Directionality(
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
    child: SafeArea(
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          key: const ValueKey('material-request-information-panel'),
          color: Colors.transparent,
          child: SizedBox(
            width: math.min(MediaQuery.sizeOf(dialogContext).width * .92, 430),
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const PageStorageKey(
                  'material-request-information-scroll',
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      constraints.maxHeight - AppSpacing.sm * 2,
                    ),
                  ),
                  child: builder(dialogContext),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, _, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(language.isRtl ? -.08 : .08, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  },
);

class YorksV1RequestInformationSurface extends StatelessWidget {
  const YorksV1RequestInformationSurface({
    super.key,
    required this.language,
    required this.onClose,
    required this.children,
  });
  final AppLanguage language;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.view_sidebar_outlined, color: AppColors.blue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                YorksV1MaterialRequestStrings.requestInformation.active(
                  language,
                ),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('material-request-inspector-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    ),
  );
}

Future<void> showYorksV1RequestInformation(
  BuildContext context, {
  required YorksV1MaterialRequest request,
  required AppLanguage language,
}) => showYorksV1RequestInformationPanel(
  context,
  language: language,
  builder: (context) =>
      _RequestInformationContent(request: request, language: language),
);

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
    return YorksV1RequestInformationSurface(
      language: language,
      onClose: () => Navigator.of(context).pop(),
      children: [
        Text(
          YorksV1MaterialRequestStrings.requestDetails.active(language),
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.requestNumber.active(language),
          value: request.requestNumber ?? '—',
        ),
        if (requestTitle != null && requestTitle.isNotEmpty)
          _InformationFact(
            label: YorksV1MaterialRequestStrings.requestTitle.active(language),
            value: requestTitle,
          ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.project.active(language),
          value: request.projectName,
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.projectReference.active(
            language,
          ),
          value: request.projectReference,
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.scope.active(language),
          value: request.scopeName,
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.requestedBy.active(language),
          value: requestedBy == null || requestedBy.isEmpty ? '—' : requestedBy,
          supporting: role == null || role.trim().isEmpty
              ? null
              : YorksV1ProjectStrings.roleLabel(role).active(language),
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.deliveryType.active(language),
          value: yorksV1MaterialRequestTimingCopy(
            request.timing,
          ).active(language),
          supporting: scheduledDate,
        ),
        const SizedBox(height: AppSpacing.lg),
        YorksV1MaterialRequestHistorySection(
          requestId: request.id,
          language: language,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          YorksV1MaterialRequestStrings.requestStatus.active(language),
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.state.active(language),
          value: yorksV1MaterialRequestStateCopy(
            request.state,
          ).active(language),
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.currentOwner.active(language),
          value: owner == null || owner.isEmpty
              ? '—'
              : YorksV1ProjectStrings.roleLabel(owner).active(language),
        ),
        _InformationFact(
          label: YorksV1MaterialRequestStrings.nextAction.active(language),
          value: yorksV1MaterialRequestNextActionCopy(request).active(language),
          last: true,
        ),
      ],
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
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        );
        final valueWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.trim().isEmpty ? '—' : value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (supporting?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                supporting!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        );
        if (constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            250) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xxs),
              valueWidget,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: labelWidget),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}
