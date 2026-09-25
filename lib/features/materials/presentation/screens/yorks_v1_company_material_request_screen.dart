import '../../../../shared/controllers/yorks_v1_material_line_editor.dart';
import 'yorks_v1_material_request_screens.dart'
    show YorksV1MaterialItemsEditor, YorksV1MaterialDescriptionField;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/yorks_mobile_ui.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';

export 'yorks_v1_company_material_request_approval_screens.dart';

enum _CompanyRequestStep { details, items, review }

enum _CompanyRequestExitChoice { save, discard }

bool _lineHasMaterial(YorksV1CompanyMaterialRequestLine line) =>
    line.description.trim().isNotEmpty ||
    line.quantity.trim().isNotEmpty ||
    line.unit.trim().isNotEmpty ||
    line.brandOrigin?.trim().isNotEmpty == true;

int _materialCount(List<YorksV1CompanyMaterialRequestLine> lines) =>
    lines.where(_lineHasMaterial).length;

bool _requestDetailsReady(YorksV1CompanyMaterialRequestDraft draft) =>
    draft.categoryId != null &&
    draft.responsibleUnitId != null &&
    draft.beneficiaryAuthUserId != null &&
    draft.authorizedReceiverAuthUserId != null &&
    draft.purpose?.trim().isNotEmpty == true &&
    draft.deliveryCollectionPoint?.trim().isNotEmpty == true &&
    (draft.timing != YorksV1MaterialRequestTiming.scheduled ||
        draft.scheduledDate != null);

/// Focused first-step composer for a non-project company need.
///
/// The presentation follows the established Material Request language without
/// introducing project, BOQ or inventory authority to this separate lane.
class YorksV1CompanyMaterialRequestScreen extends ConsumerStatefulWidget {
  const YorksV1CompanyMaterialRequestScreen({super.key, this.draftId});

  final String? draftId;

  @override
  ConsumerState<YorksV1CompanyMaterialRequestScreen> createState() =>
      _YorksV1CompanyMaterialRequestScreenState();
}

class _YorksV1CompanyMaterialRequestScreenState
    extends ConsumerState<YorksV1CompanyMaterialRequestScreen> {
  final _purpose = TextEditingController();
  final _point = TextEditingController();
  late YorksV1CompanyMaterialRequestDraft _draft;
  YorksV1CompanyMaterialRequestApprovalPreflight? _preflight;
  _CompanyRequestStep _step = _CompanyRequestStep.details;
  bool _routeChecking = false;
  bool _routeUnavailable = false;
  bool _reviewConfirmed = false;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  bool _allowPop = false;
  bool _exitDecisionOpen = false;
  bool _inspectorExpanded = false;
  bool _restoring = false;
  bool _restoreFailed = false;
  int _routeGeneration = 0;

  @override
  void initState() {
    super.initState();
    const uuid = Uuid();
    _draft = YorksV1CompanyMaterialRequestDraft(
      id: uuid.v4(),
      recordVersion: 0,
      submissionIdempotencyKey: uuid.v4(),
      timing: YorksV1MaterialRequestTiming.normal,
      lines: [
        YorksV1CompanyMaterialRequestLine(
          id: uuid.v4(),
          displayOrder: 1,
          description: '',
          quantity: '',
          unit: '',
        ),
      ],
    );
    _purpose.addListener(_onTextChanged);
    _point.addListener(_onTextChanged);
    if (widget.draftId != null) unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    setState(() {
      _restoring = true;
      _restoreFailed = false;
    });
    try {
      final request = await ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .getRequest(widget.draftId!);
      if (!mounted) return;
      if (request.state != 'draft' ||
          request.categoryId == null ||
          request.responsibleUnitId == null) {
        context.go('/yorks/material-requests/company/${request.id}');
        return;
      }
      _purpose.text = request.purpose;
      _point.text = request.deliveryCollectionPoint;
      setState(() {
        _draft = YorksV1CompanyMaterialRequestDraft(
          id: request.id,
          recordVersion: request.recordVersion,
          submissionIdempotencyKey: const Uuid().v4(),
          categoryId: request.categoryId,
          responsibleUnitId: request.responsibleUnitId,
          purpose: request.purpose,
          deliveryCollectionPoint: request.deliveryCollectionPoint,
          beneficiaryAuthUserId: request.beneficiary.authUserId,
          authorizedReceiverAuthUserId: request.authorizedReceiver.authUserId,
          selectedApproverAuthUserId: request.selectedApproverAuthUserId,
          timing: request.timing,
          scheduledDate: request.scheduledDate,
          lines: request.lines,
        );
        _hasUnsavedChanges = false;
        _restoring = false;
      });
      await _checkRoute();
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _purpose
      ..removeListener(_onTextChanged)
      ..dispose();
    _point
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _reviewConfirmed = false;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _update(YorksV1CompanyMaterialRequestDraft next) {
    final participantsChanged =
        _draft.categoryId != next.categoryId ||
        _draft.responsibleUnitId != next.responsibleUnitId ||
        _draft.beneficiaryAuthUserId != next.beneficiaryAuthUserId ||
        _draft.authorizedReceiverAuthUserId !=
            next.authorizedReceiverAuthUserId;
    if (participantsChanged) next = next.copyWith(clearApprover: true);
    final authorizationChanged =
        participantsChanged ||
        _draft.selectedApproverAuthUserId != next.selectedApproverAuthUserId;
    setState(() {
      _draft = next;
      _reviewConfirmed = false;
      _hasUnsavedChanges = true;
      if (authorizationChanged) {
        _routeGeneration++;
        _preflight = null;
        _routeUnavailable = false;
        _routeChecking = false;
      }
    });
    if (authorizationChanged) _checkRoute();
  }

  Future<void> _checkRoute() async {
    final generation = ++_routeGeneration;
    final category = _draft.categoryId;
    final unit = _draft.responsibleUnitId;
    final beneficiary = _draft.beneficiaryAuthUserId;
    final receiver = _draft.authorizedReceiverAuthUserId;
    if (category == null ||
        unit == null ||
        beneficiary == null ||
        receiver == null) {
      return;
    }
    setState(() => _routeChecking = true);
    try {
      final result = await ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .preflightApproval(
            categoryId: category,
            responsibleUnitId: unit,
            beneficiaryAuthUserId: beneficiary,
            authorizedReceiverAuthUserId: receiver,
            selectedApproverAuthUserId: _draft.selectedApproverAuthUserId,
          );
      if (!mounted ||
          generation != _routeGeneration ||
          category != _draft.categoryId ||
          unit != _draft.responsibleUnitId ||
          beneficiary != _draft.beneficiaryAuthUserId ||
          receiver != _draft.authorizedReceiverAuthUserId) {
        return;
      }
      setState(() {
        if (_draft.selectedApproverAuthUserId == null) {
          _draft = _draft.copyWith(
            selectedApproverAuthUserId: result.approver.authUserId,
          );
        }
        _preflight = result;
        _routeUnavailable = false;
        _routeChecking = false;
      });
    } catch (_) {
      if (!mounted || generation != _routeGeneration) return;
      setState(() {
        _preflight = null;
        _routeUnavailable = true;
        _routeChecking = false;
      });
    }
  }

  YorksV1CompanyMaterialRequestDraft get _current => _draft.copyWith(
    purpose: _purpose.text,
    deliveryCollectionPoint: _point.text,
  );

  bool get _detailsReady {
    return _requestDetailsReady(_current);
  }

  bool get _itemsReady =>
      _draft.lines.isNotEmpty && _draft.lines.every((line) => line.isValid);

  bool get _canSubmitAndApprove {
    final actor = ref.read(yorksV1AuthUserIdProvider);
    return actor != null &&
        _preflight?.approver.authUserId == actor &&
        _current.selectedApproverAuthUserId == actor;
  }

  void _goTo(_CompanyRequestStep step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _leave() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.maybeOf(context)?.go('/yorks/material-requests/company');
      }
    });
  }

  Future<void> _requestClose(AppLanguage language) async {
    if (_saving || _exitDecisionOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (!_hasUnsavedChanges) {
      _leave();
      return;
    }
    _exitDecisionOpen = true;
    final canSave = _current.canSave;
    final choice = await showDialog<_CompanyRequestExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.leaveDraftTitle.active(language),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1CompanyMaterialRequestStrings.leaveDraftBody.active(
                language,
              ),
            ),
            if (!canSave) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                YorksV1CompanyMaterialRequestStrings.incompleteLeaveDraftBody
                    .active(language),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('company-material-request-keep-editing'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.keepEditing.active(language),
            ),
          ),
          TextButton(
            key: const ValueKey('company-material-request-discard-and-leave'),
            onPressed: () =>
                Navigator.pop(dialogContext, _CompanyRequestExitChoice.discard),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.discardAndLeave.active(
                language,
              ),
            ),
          ),
          FilledButton(
            key: const ValueKey('company-material-request-save-and-leave'),
            onPressed: canSave
                ? () => Navigator.pop(
                    dialogContext,
                    _CompanyRequestExitChoice.save,
                  )
                : null,
            child: Text(
              YorksV1CompanyMaterialRequestStrings.saveAndLeave.active(
                language,
              ),
            ),
          ),
        ],
      ),
    );
    _exitDecisionOpen = false;
    if (!mounted || choice == null) return;
    if (choice == _CompanyRequestExitChoice.save) {
      final saved = await _save(submit: false, language: language);
      if (!saved || !mounted) return;
    }
    _leave();
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _save({
    required bool submit,
    bool approveImmediately = false,
    required AppLanguage language,
  }) async {
    final draft = _current;
    if (!draft.canSave) {
      _show(YorksV1CompanyMaterialRequestStrings.validation.active(language));
      return false;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        yorksV1CompanyMaterialRequestRepositoryProvider,
      );
      final result = approveImmediately
          ? await repository.saveSubmitAndApprove(draft)
          : submit
          ? await repository.saveAndSubmit(draft)
          : await repository.saveDraft(draft);
      if (!mounted) return false;
      setState(() {
        _draft = _draft.copyWith(recordVersion: result.recordVersion);
        _hasUnsavedChanges = false;
      });
      if (submit) {
        setState(() => _saving = false);
        await _showSubmitted(result, language, approveImmediately);
        if (mounted) {
          ref.invalidate(yorksV1CompanyMaterialRequestApprovalInboxProvider);
          ref.invalidate(yorksV1CompanyMaterialRequestProvider(result.id));
          setState(() => _allowPop = true);
          context.go('/yorks/material-requests/company/${result.id}');
        }
      } else {
        _show(YorksV1CompanyMaterialRequestStrings.draftSaved.active(language));
      }
      return true;
    } on YorksV1DomainException {
      if (mounted) {
        _show(YorksV1CompanyMaterialRequestStrings.failed.active(language));
      }
      return false;
    } catch (_) {
      if (mounted) {
        _show(YorksV1CompanyMaterialRequestStrings.failed.active(language));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSubmit(
    AppLanguage language, {
    bool approveImmediately = false,
  }) async {
    final approver = _preflight?.approver;
    if (approver == null ||
        !_current.canSave ||
        (approveImmediately && !_canSubmitAndApprove)) {
      _show(YorksV1CompanyMaterialRequestStrings.validation.active(language));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          (approveImmediately
                  ? YorksV1MaterialRequestStrings.submitAndApprove
                  : YorksV1CompanyMaterialRequestStrings.submitConfirmTitle)
              .active(language),
        ),
        content: Text(
          (approveImmediately
                  ? YorksV1CompanyMaterialRequestStrings
                        .submitAndApproveConfirmMessage
                  : YorksV1CompanyMaterialRequestStrings.submitConfirmMessage(
                      approver.displayName,
                    ))
              .active(language),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(YorksV1MaterialRequestStrings.cancel.active(language)),
          ),
          FilledButton(
            key: const ValueKey('company-material-request-confirm-submit'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              (approveImmediately
                      ? YorksV1MaterialRequestStrings.submitAndApprove
                      : YorksV1CompanyMaterialRequestStrings.submit)
                  .active(language),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _save(
        submit: true,
        approveImmediately: approveImmediately,
        language: language,
      );
    }
  }

  Future<void> _showSubmitted(
    YorksV1CompanyMaterialRequest result,
    AppLanguage language,
    bool approveImmediately,
  ) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
        size: 42,
      ),
      title: Text(
        (approveImmediately
                ? YorksV1CompanyMaterialRequestStrings.submitAndApprovedTitle
                : YorksV1CompanyMaterialRequestStrings.submitConfirmedTitle)
            .active(language),
      ),
      content: Text(
        (approveImmediately
                ? YorksV1CompanyMaterialRequestStrings.submitAndApprovedMessage(
                    result.requestNumber ?? result.id,
                  )
                : YorksV1CompanyMaterialRequestStrings.submitConfirmedMessage(
                    result.requestNumber ?? result.id,
                    result.approver?.displayName ??
                        _preflight?.approver.displayName ??
                        YorksV1CompanyMaterialRequestStrings.approver.active(
                          language,
                        ),
                  ))
            .active(language),
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            YorksV1CompanyMaterialRequestStrings.viewRequest.active(language),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoreFailed) {
      return _CompanyRequestPolicyState(
        language: language,
        onRetry: _restoreDraft,
      );
    }
    final options = ref.watch(
      yorksV1CompanyMaterialRequestDraftOptionsProvider,
    );
    final body = options.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _CompanyRequestPolicyState(
        language: language,
        onRetry: () =>
            ref.invalidate(yorksV1CompanyMaterialRequestDraftOptionsProvider),
      ),
      data: (items) => items.isEmpty
          ? _CompanyRequestPolicyState(
              language: language,
              onRetry: () => ref.invalidate(
                yorksV1CompanyMaterialRequestDraftOptionsProvider,
              ),
            )
          : MediaQuery.sizeOf(context).width < AppSpacing.stackedBreakpoint
          ? _buildMobile(items, language)
          : _buildDesktop(items, language),
    );
    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !_allowPop) await _requestClose(language);
      },
      child: body,
    );
  }

  Widget _approverChoice(AppLanguage language) {
    final choices =
        _preflight?.eligibleApprovers ??
        const <YorksV1CompanyMaterialRequestPerson>[];
    if (choices.isEmpty) return const SizedBox.shrink();
    final selected =
        _draft.selectedApproverAuthUserId ?? _preflight?.approver.authUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: DropdownButtonFormField<String>(
        key: ValueKey('company-approver-$selected'),
        initialValue: choices.any((p) => p.authUserId == selected)
            ? selected
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: YorksV1CompanyMaterialRequestStrings.approver.active(
            language,
          ),
        ),
        items: [
          for (final person in choices)
            DropdownMenuItem(
              value: person.authUserId,
              child: Text(person.displayName),
            ),
        ],
        onChanged: _saving || _routeChecking
            ? null
            : (value) =>
                  _update(_draft.copyWith(selectedApproverAuthUserId: value)),
      ),
    );
  }

  Widget _buildMobile(
    List<YorksV1CompanyMaterialRequestDraftOption> options,
    AppLanguage language,
  ) {
    final title = switch (_step) {
      _CompanyRequestStep.details =>
        YorksV1MaterialRequestStrings.detailsStep.active(language),
      _CompanyRequestStep.items => YorksV1MaterialRequestStrings.items.active(
        language,
      ),
      _CompanyRequestStep.review => YorksV1MaterialRequestStrings.review.active(
        language,
      ),
    };
    return Scaffold(
      backgroundColor: AppColors.mobileSurface,
      body: Column(
        children: [
          YorksMobileAppBar(
            title: title,
            leading: YorksMobileIconButton(
              key: const ValueKey('company-material-request-back'),
              icon: Icons.arrow_back_rounded,
              tooltip: YorksV1MaterialRequestStrings.back.active(language),
              onPressed: _step == _CompanyRequestStep.details
                  ? () => _requestClose(language)
                  : () => _goTo(
                      _step == _CompanyRequestStep.review
                          ? _CompanyRequestStep.items
                          : _CompanyRequestStep.details,
                    ),
            ),
          ),
          Expanded(
            child: switch (_step) {
              _CompanyRequestStep.details => _mobileDetails(options, language),
              _CompanyRequestStep.items => _mobileItems(language),
              _CompanyRequestStep.review => _mobileReview(options, language),
            },
          ),
          _mobileActions(language),
        ],
      ),
    );
  }

  Widget _mobileDetails(
    List<YorksV1CompanyMaterialRequestDraftOption> options,
    AppLanguage language,
  ) => ListView(
    key: const ValueKey('company-material-request-mobile-details'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    children: [
      _CompanyProgress(step: _step, language: language),
      const SizedBox(height: AppSpacing.xl),
      YorksMobilePageTitle(
        eyebrow: YorksV1CompanyMaterialRequestStrings.companyUse.active(
          language,
        ),
        title: YorksV1CompanyMaterialRequestStrings.detailsPrompt.active(
          language,
        ),
        description: YorksV1CompanyMaterialRequestStrings.detailsDescription
            .active(language),
      ),
      const SizedBox(height: AppSpacing.lg),
      YorksMobileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContextFields(
              language: language,
              options: options,
              draft: _draft,
              onChanged: _update,
            ),
            const SizedBox(height: AppSpacing.lg),
            _approverChoice(language),
            _RequestDetailFields(
              language: language,
              purpose: _purpose,
              collectionPoint: _point,
              draft: _draft,
              onChanged: _update,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _ApprovalStatus(
        language: language,
        checking: _routeChecking,
        routeUnavailable: _routeUnavailable,
        preflight: _preflight,
      ),
    ],
  );

  Widget _mobileItems(AppLanguage language) => ListView(
    key: const ValueKey('company-material-request-mobile-items'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    children: [
      _CompanyProgress(step: _step, language: language),
      const SizedBox(height: AppSpacing.xl),
      YorksMobilePageTitle(
        eyebrow: YorksV1CompanyMaterialRequestStrings.companyUse.active(
          language,
        ),
        title: YorksV1MaterialRequestStrings.materialBasket.active(language),
        description: YorksV1CompanyMaterialRequestStrings.itemsDescription
            .active(language),
      ),
      const SizedBox(height: AppSpacing.lg),
      _CompanyLineEditor(
        language: language,
        lines: _draft.lines,
        readLines: () => _draft.lines,
        categoryId: _draft.categoryId,
        responsibleUnitId: _draft.responsibleUnitId,
        compact: true,
        onChanged: (lines) => _update(_draft.copyWith(lines: lines)),
      ),
    ],
  );

  Widget _mobileReview(
    List<YorksV1CompanyMaterialRequestDraftOption> options,
    AppLanguage language,
  ) => ListView(
    key: const ValueKey('company-material-request-mobile-review'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    children: [
      _CompanyProgress(step: _step, language: language),
      const SizedBox(height: AppSpacing.xl),
      YorksMobilePageTitle(
        eyebrow: YorksV1CompanyMaterialRequestStrings.companyUse.active(
          language,
        ),
        title: YorksV1CompanyMaterialRequestStrings.reviewTitle.active(
          language,
        ),
        description: YorksV1CompanyMaterialRequestStrings.reviewDescription
            .active(language),
      ),
      const SizedBox(height: AppSpacing.lg),
      _CompanyRequestSummary(
        language: language,
        options: options,
        draft: _current,
        preflight: _preflight,
        routeChecking: _routeChecking,
        routeUnavailable: _routeUnavailable,
      ),
      const SizedBox(height: AppSpacing.md),
      _ReviewLines(language: language, lines: _draft.lines),
      const SizedBox(height: AppSpacing.md),
      if (_preflight != null)
        YorksMobileCallout(
          icon: Icons.verified_user_outlined,
          title: YorksV1CompanyMaterialRequestStrings.approvalHandoffTitle
              .active(language),
          message: YorksV1CompanyMaterialRequestStrings.approvalHandoff(
            _preflight!.approver.displayName,
          ).active(language),
        )
      else
        _ApprovalStatus(
          language: language,
          checking: _routeChecking,
          routeUnavailable: _routeUnavailable,
          preflight: _preflight,
        ),
      const SizedBox(height: AppSpacing.md),
      YorksMobileCard(
        child: CheckboxListTile(
          key: const ValueKey('company-material-request-review-confirmation'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _reviewConfirmed,
          onChanged: (value) =>
              setState(() => _reviewConfirmed = value == true),
          title: Text(
            YorksV1CompanyMaterialRequestStrings.reviewConfirmation.active(
              language,
            ),
            style: AppTypography.bodyMedium,
          ),
        ),
      ),
    ],
  );

  Widget _mobileActions(AppLanguage language) {
    if (_step == _CompanyRequestStep.details) {
      return YorksMobileStickyActions(
        children: [
          FilledButton(
            key: const ValueKey('company-material-request-continue'),
            onPressed: _detailsReady
                ? () => _goTo(_CompanyRequestStep.items)
                : null,
            child: Text(
              YorksV1MaterialRequestStrings.continueAction.active(language),
            ),
          ),
        ],
      );
    }
    if (_step == _CompanyRequestStep.items) {
      return YorksMobileStickyActions(
        summary: YorksV1CompanyMaterialRequestStrings.itemCount(
          _materialCount(_draft.lines),
        ).active(language),
        children: [
          OutlinedButton(
            onPressed: () => _goTo(_CompanyRequestStep.details),
            child: Text(YorksV1MaterialRequestStrings.back.active(language)),
          ),
          FilledButton(
            key: const ValueKey('company-material-request-review'),
            onPressed: _detailsReady && _itemsReady
                ? () => _goTo(_CompanyRequestStep.review)
                : null,
            child: Text(YorksV1MaterialRequestStrings.review.active(language)),
          ),
        ],
      );
    }
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _preflight == null
                    ? YorksV1CompanyMaterialRequestStrings.routeChecking.active(
                        language,
                      )
                    : YorksV1CompanyMaterialRequestStrings.approvalHandoff(
                        _preflight!.approver.displayName,
                      ).active(language),
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('company-material-request-save-draft'),
                  onPressed: _saving || !_current.canSave || !_hasUnsavedChanges
                      ? null
                      : () => _save(submit: false, language: language),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    YorksV1CompanyMaterialRequestStrings.saveDraft.active(
                      language,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: _CompanySubmitActions(
                  language: language,
                  expand: true,
                  enabled: !_saving && _reviewConfirmed && _preflight != null,
                  saving: _saving,
                  canApprove: _canSubmitAndApprove,
                  onPrimary: () => _confirmSubmit(
                    language,
                    approveImmediately: _canSubmitAndApprove,
                  ),
                  onSubmitOnly: () => _confirmSubmit(language),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(
    List<YorksV1CompanyMaterialRequestDraftOption> options,
    AppLanguage language,
  ) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.pageMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopHero(
                        language: language,
                        inspectorExpanded: _inspectorExpanded,
                        onToggleInspector: () => setState(
                          () => _inspectorExpanded = !_inspectorExpanded,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _DesktopSection(
                                  number: '1',
                                  title: YorksV1MaterialRequestStrings
                                      .requestInformation
                                      .active(language),
                                  description:
                                      YorksV1CompanyMaterialRequestStrings
                                          .detailsDescription
                                          .active(language),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _ContextFields(
                                          language: language,
                                          options: options,
                                          draft: _draft,
                                          onChanged: _update,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.lg),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _approverChoice(language),
                                            _RequestDetailFields(
                                              language: language,
                                              purpose: _purpose,
                                              collectionPoint: _point,
                                              draft: _draft,
                                              onChanged: _update,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _DesktopSection(
                                  number: '2',
                                  title: YorksV1CompanyMaterialRequestStrings
                                      .materialItems
                                      .active(language),
                                  description:
                                      YorksV1CompanyMaterialRequestStrings
                                          .itemsDescription
                                          .active(language),
                                  child: _CompanyLineEditor(
                                    language: language,
                                    lines: _draft.lines,
                                    readLines: () => _draft.lines,
                                    categoryId: _draft.categoryId,
                                    responsibleUnitId: _draft.responsibleUnitId,
                                    compact: false,
                                    onChanged: (lines) =>
                                        _update(_draft.copyWith(lines: lines)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_inspectorExpanded) ...[
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              width: 340,
                              child: Column(
                                children: [
                                  _CompanyRequestSummary(
                                    language: language,
                                    options: options,
                                    draft: _current,
                                    preflight: _preflight,
                                    routeChecking: _routeChecking,
                                    routeUnavailable: _routeUnavailable,
                                    onClose: () => setState(
                                      () => _inspectorExpanded = false,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _ApprovalStatus(
                                    language: language,
                                    checking: _routeChecking,
                                    routeUnavailable: _routeUnavailable,
                                    preflight: _preflight,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _DesktopActionBar(
            language: language,
            saving: _saving,
            canSave: _current.canSave,
            canSubmit: _current.canSave && _preflight != null,
            canSubmitAndApprove: _canSubmitAndApprove,
            hasUnsavedChanges: _hasUnsavedChanges,
            onCancel: () => _requestClose(language),
            onSave: () => _save(submit: false, language: language),
            onSubmit: () => _confirmSubmit(
              language,
              approveImmediately: _canSubmitAndApprove,
            ),
            onSubmitOnly: () => _confirmSubmit(language),
          ),
        ],
      ),
    ),
  );
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero({
    required this.language,
    required this.inspectorExpanded,
    required this.onToggleInspector,
  });
  final AppLanguage language;
  final bool inspectorExpanded;
  final VoidCallback onToggleInspector;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.business_center_outlined, color: AppColors.blue),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1CompanyMaterialRequestStrings.newRequest.active(language),
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              YorksV1CompanyMaterialRequestStrings.privateDraft.active(
                language,
              ),
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      OutlinedButton.icon(
        key: const ValueKey('company-request-information-toggle'),
        onPressed: onToggleInspector,
        icon: Icon(
          inspectorExpanded ? Icons.close_rounded : Icons.info_outline_rounded,
        ),
        label: Text(
          YorksV1CompanyMaterialRequestStrings.showRequestInformation.active(
            language,
          ),
        ),
      ),
    ],
  );
}

class _DesktopActionBar extends StatelessWidget {
  const _DesktopActionBar({
    required this.language,
    required this.saving,
    required this.canSave,
    required this.canSubmit,
    required this.canSubmitAndApprove,
    required this.hasUnsavedChanges,
    required this.onCancel,
    required this.onSave,
    required this.onSubmit,
    required this.onSubmitOnly,
  });
  final AppLanguage language;
  final bool saving;
  final bool canSave;
  final bool canSubmit;
  final bool canSubmitAndApprove;
  final bool hasUnsavedChanges;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onSubmit;
  final VoidCallback onSubmitOnly;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
        child: Row(
          children: [
            Icon(
              canSave
                  ? hasUnsavedChanges
                        ? Icons.check_circle_outline
                        : Icons.cloud_done_outlined
                  : Icons.info_outline,
              color: canSave ? AppColors.success : AppColors.muted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                (canSave
                        ? hasUnsavedChanges
                              ? YorksV1CompanyMaterialRequestStrings.draftReady
                              : YorksV1CompanyMaterialRequestStrings
                                    .allChangesSaved
                        : YorksV1CompanyMaterialRequestStrings
                              .completeBeforeSaving)
                    .active(language),
                style: AppTypography.bodySmall.copyWith(
                  color: canSave ? AppColors.success : AppColors.muted,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('company-material-request-cancel'),
              onPressed: saving ? null : onCancel,
              child: Text(
                YorksV1MaterialRequestStrings.cancel.active(language),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('company-material-request-save-draft'),
              onPressed: saving || !canSave || !hasUnsavedChanges
                  ? null
                  : onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                YorksV1CompanyMaterialRequestStrings.saveDraft.active(language),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CompanySubmitActions(
              language: language,
              enabled: !saving && canSubmit,
              saving: saving,
              canApprove: canSubmitAndApprove,
              onPrimary: onSubmit,
              onSubmitOnly: onSubmitOnly,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompanySubmitActions extends StatelessWidget {
  const _CompanySubmitActions({
    required this.language,
    this.expand = false,
    required this.enabled,
    required this.saving,
    required this.canApprove,
    required this.onPrimary,
    required this.onSubmitOnly,
  });

  final AppLanguage language;
  final bool expand;
  final bool enabled;
  final bool saving;
  final bool canApprove;
  final VoidCallback onPrimary;
  final VoidCallback onSubmitOnly;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      key: const ValueKey('company-material-request-submit'),
      onPressed: enabled ? onPrimary : null,
      icon: Icon(canApprove ? Icons.verified_outlined : Icons.send_rounded),
      label: _SavingLabel(
        saving: saving,
        label:
            (canApprove
                    ? YorksV1MaterialRequestStrings.submitAndApprove
                    : YorksV1CompanyMaterialRequestStrings.submit)
                .active(language),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (expand) Expanded(child: primary) else primary,
        if (canApprove) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            key: const ValueKey('company-material-request-submit-options'),
            tooltip: YorksV1CompanyMaterialRequestStrings.submit.active(
              language,
            ),
            enabled: enabled,
            icon: const Icon(Icons.arrow_drop_down_rounded),
            onSelected: (_) => onSubmitOnly(),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const ValueKey('company-material-request-submit-only'),
                value: 'submit_only',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.submit.active(language),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DesktopSection extends StatelessWidget {
  const _DesktopSection({
    required this.number,
    required this.title,
    required this.description,
    required this.child,
  });
  final String number;
  final String title;
  final String description;
  final Widget child;
  @override
  Widget build(BuildContext context) => _CompanyCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.blueContainer,
                child: Text(
                  number,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
      ],
    ),
  );
}

class _ContextFields extends StatelessWidget {
  const _ContextFields({
    required this.language,
    required this.options,
    required this.draft,
    required this.onChanged,
  });
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestDraftOption> options;
  final YorksV1CompanyMaterialRequestDraft draft;
  final ValueChanged<YorksV1CompanyMaterialRequestDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption(options, draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<YorksV1CompanyMaterialRequestDraftOption>(
          key: const ValueKey('company-material-request-context'),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.categoryAndUnit
                .active(language),
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(
                  '${option.categoryName} · ${option.responsibleUnitName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (option) {
            if (option == null) return;
            onChanged(
              draft.copyWith(
                categoryId: option.categoryId,
                responsibleUnitId: option.responsibleUnitId,
                clearBeneficiary: true,
                clearAuthorizedReceiver: true,
              ),
            );
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            YorksV1CompanyMaterialRequestStrings.chooseContextFirst.active(
              language,
            ),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _PersonPicker(
          fieldKey: const ValueKey('company-material-request-beneficiary'),
          label: YorksV1CompanyMaterialRequestStrings.beneficiary.active(
            language,
          ),
          value: draft.beneficiaryAuthUserId,
          options: selected?.beneficiaries ?? const [],
          onChanged: (value) =>
              onChanged(draft.copyWith(beneficiaryAuthUserId: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        _PersonPicker(
          fieldKey: const ValueKey('company-material-request-receiver'),
          label: YorksV1CompanyMaterialRequestStrings.authorizedReceiver.active(
            language,
          ),
          value: draft.authorizedReceiverAuthUserId,
          options: selected?.receivers ?? const [],
          onChanged: (value) =>
              onChanged(draft.copyWith(authorizedReceiverAuthUserId: value)),
        ),
      ],
    );
  }
}

class _PersonPicker extends StatelessWidget {
  const _PersonPicker({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final Key fieldKey;
  final String label;
  final String? value;
  final List<YorksV1CompanyMaterialRequestPerson> options;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: fieldKey,
    initialValue: options.any((person) => person.authUserId == value)
        ? value
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final person in options)
        DropdownMenuItem(
          value: person.authUserId,
          child: Text(person.displayName, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: options.isEmpty ? null : onChanged,
  );
}

class _RequestDetailFields extends StatelessWidget {
  const _RequestDetailFields({
    required this.language,
    required this.purpose,
    required this.collectionPoint,
    required this.draft,
    required this.onChanged,
  });
  final AppLanguage language;
  final TextEditingController purpose;
  final TextEditingController collectionPoint;
  final YorksV1CompanyMaterialRequestDraft draft;
  final ValueChanged<YorksV1CompanyMaterialRequestDraft> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('company-material-request-purpose'),
        controller: purpose,
        maxLength: 1000,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          counterText: '',
          labelText: YorksV1CompanyMaterialRequestStrings.purpose.active(
            language,
          ),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        key: const ValueKey('company-material-request-collection-point'),
        controller: collectionPoint,
        maxLength: 500,
        decoration: InputDecoration(
          counterText: '',
          labelText: YorksV1CompanyMaterialRequestStrings
              .deliveryCollectionPoint
              .active(language),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<YorksV1MaterialRequestTiming>(
        initialValue: draft.timing,
        decoration: InputDecoration(
          labelText: YorksV1CompanyMaterialRequestStrings.timing.active(
            language,
          ),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(
            value: YorksV1MaterialRequestTiming.normal,
            child: Text(
              YorksV1CompanyMaterialRequestStrings.normal.active(language),
            ),
          ),
          DropdownMenuItem(
            value: YorksV1MaterialRequestTiming.urgent,
            child: Text(
              YorksV1CompanyMaterialRequestStrings.urgent.active(language),
            ),
          ),
          DropdownMenuItem(
            value: YorksV1MaterialRequestTiming.scheduled,
            child: Text(
              YorksV1CompanyMaterialRequestStrings.scheduled.active(language),
            ),
          ),
        ],
        onChanged: (timing) => onChanged(
          draft.copyWith(
            timing: timing,
            clearScheduledDate:
                timing != YorksV1MaterialRequestTiming.scheduled,
          ),
        ),
      ),
      if (draft.timing == YorksV1MaterialRequestTiming.scheduled) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final selected = await showDatePicker(
              context: context,
              firstDate: now,
              lastDate: now.add(const Duration(days: 730)),
              initialDate: draft.scheduledDate ?? now,
            );
            if (selected != null) {
              onChanged(draft.copyWith(scheduledDate: selected));
            }
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(
            draft.scheduledDate == null
                ? YorksV1CompanyMaterialRequestStrings.requiredDate.active(
                    language,
                  )
                : '${draft.scheduledDate!.day}/${draft.scheduledDate!.month}/${draft.scheduledDate!.year}',
          ),
        ),
      ],
    ],
  );
}

class _CompanyLineEditor extends ConsumerWidget {
  const _CompanyLineEditor({
    required this.language,
    required this.lines,
    required this.readLines,
    required this.categoryId,
    required this.responsibleUnitId,
    required this.compact,
    required this.onChanged,
  });
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestLine> lines;
  final List<YorksV1CompanyMaterialRequestLine> Function() readLines;
  final String? categoryId;
  final String? responsibleUnitId;
  final bool compact;
  final ValueChanged<List<YorksV1CompanyMaterialRequestLine>> onChanged;

  void _addLine() {
    final lines = readLines();
    const uuid = Uuid();
    onChanged([
      ...lines,
      YorksV1CompanyMaterialRequestLine(
        id: uuid.v4(),
        displayOrder: lines.length + 1,
        description: '',
        quantity: '',
        unit: '',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _CompanyLineActions(readLines, onChanged, _insertAfter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('company-material-request-add-item'),
              onPressed: _addLine,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                YorksV1MaterialRequestStrings.addCustomItem.active(language),
              ),
            ),
            Text(
              YorksV1CompanyMaterialRequestStrings.itemCount(
                _materialCount(lines),
              ).active(language),
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        YorksV1MaterialItemsEditor(
          lines: lines.map(_companyPresentationLine).toList(growable: false),
          controller: actions,
          descriptionBuilder: (line, compact) =>
              YorksV1MaterialDescriptionField(
                key: ValueKey('company-line-description-${line.id}'),
                line: line,
                controller: actions,
                enabled: true,
                compact: compact,
                searchContext: (categoryId, responsibleUnitId),
                projectId: null,
                scopeId: null,
                search: (query) async {
                  if (categoryId == null || responsibleUnitId == null) {
                    return const [];
                  }
                  return ref.read(
                    yorksV1CompanyMaterialSearchProvider(
                      YorksV1CompanyMaterialSearchKey(
                        categoryId: categoryId!,
                        responsibleUnitId: responsibleUnitId!,
                        query: query,
                      ),
                    ).future,
                  );
                },
              ),
        ),
      ],
    );
  }

  void _insertAfter(int index, YorksV1CompanyMaterialRequestLine? source) {
    final lines = readLines();
    const uuid = Uuid();
    final inserted = YorksV1CompanyMaterialRequestLine(
      id: uuid.v4(),
      displayOrder: index + 2,
      description: source?.description ?? '',
      brandOrigin: source?.brandOrigin,
      size: source?.size,
      model: source?.model,
      equipmentTag: source?.equipmentTag,
      quantity: '',
      unit: source?.unit ?? '',
    );
    final next = [...lines]..insert(index + 1, inserted);
    onChanged([
      for (var i = 0; i < next.length; i++)
        next[i].copyWith(displayOrder: i + 1),
    ]);
  }
}

YorksV1MaterialRequestLine _companyPresentationLine(
  YorksV1CompanyMaterialRequestLine line,
) => YorksV1MaterialRequestLine(
  id: line.id,
  displayOrder: line.displayOrder,
  source: YorksV1MaterialRequestLineSource.custom,
  description: line.description,
  quantity: line.quantity,
  unit: line.unit,
  size: line.size,
  model: line.model,
  brandOrigin: line.brandOrigin,
  equipmentTag: line.equipmentTag,
);

class _CompanyLineActions implements YorksV1MaterialLineEditor {
  _CompanyLineActions(this.readLines, this.onChanged, this.insert);
  final List<YorksV1CompanyMaterialRequestLine> Function() readLines;
  List<YorksV1CompanyMaterialRequestLine> get lines => readLines();
  final ValueChanged<List<YorksV1CompanyMaterialRequestLine>> onChanged;
  final void Function(int, YorksV1CompanyMaterialRequestLine?) insert;
  @override
  Future<void> updateLine(
    String id,
    YorksV1MaterialRequestLine Function(YorksV1MaterialRequestLine) transform,
  ) async {
    onChanged([
      for (final line in lines)
        if (line.id != id)
          line
        else
          _updated(line, transform(_companyPresentationLine(line))),
    ]);
  }

  YorksV1CompanyMaterialRequestLine _updated(
    YorksV1CompanyMaterialRequestLine original,
    YorksV1MaterialRequestLine line,
  ) => original.copyWith(
    description: line.description,
    quantity: line.quantity,
    unit: line.unit,
    equipmentTag: line.equipmentTag,
    clearEquipmentTag: line.equipmentTag == null,
    size: line.size,
    clearSize: line.size == null,
    model: line.model,
    clearModel: line.model == null,
    brandOrigin: line.brandOrigin,
    clearBrandOrigin: line.brandOrigin == null,
  );
  @override
  Future<void> addCustomLine({String? afterLineId}) async => insert(
    afterLineId == null
        ? lines.length - 1
        : lines.indexWhere((line) => line.id == afterLineId),
    null,
  );
  @override
  Future<void> addSimilarLine({String? afterLineId}) async {
    final index = lines.indexWhere((line) => line.id == afterLineId);
    if (index >= 0) insert(index, lines[index]);
  }

  @override
  Future<void> removeLine(String id) async {
    final remaining = lines.where((line) => line.id != id).toList();
    onChanged([
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(displayOrder: i + 1),
    ]);
  }
}

class _CompanyRequestSummary extends StatelessWidget {
  const _CompanyRequestSummary({
    required this.language,
    required this.options,
    required this.draft,
    required this.preflight,
    required this.routeChecking,
    required this.routeUnavailable,
    this.onClose,
  });
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestDraftOption> options;
  final YorksV1CompanyMaterialRequestDraft draft;
  final YorksV1CompanyMaterialRequestApprovalPreflight? preflight;
  final bool routeChecking;
  final bool routeUnavailable;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption(options, draft);
    final beneficiary = _selectedPerson(
      selected?.beneficiaries,
      draft.beneficiaryAuthUserId,
    );
    final receiver = _selectedPerson(
      selected?.receivers,
      draft.authorizedReceiverAuthUserId,
    );
    final detailsReady = _requestDetailsReady(draft);
    final materialsReady =
        draft.lines.isNotEmpty && draft.lines.every((line) => line.isValid);
    final materialCount = _materialCount(draft.lines);
    return _CompanyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.blue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.requestSummary.active(
                    language,
                  ),
                  style: AppTypography.titleMedium,
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusChip(
            icon: Icons.apartment_rounded,
            label: YorksV1CompanyMaterialRequestStrings.companyUse.active(
              language,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            YorksV1CompanyMaterialRequestStrings.completeRequest.active(
              language,
            ),
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            YorksV1CompanyMaterialRequestStrings.completeRequestMessage.active(
              language,
            ),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReadinessRow(
            label: YorksV1CompanyMaterialRequestStrings.recipientAndHandover
                .active(language),
            ready: detailsReady,
            language: language,
          ),
          _ReadinessRow(
            label: YorksV1CompanyMaterialRequestStrings.materialItems.active(
              language,
            ),
            ready: materialsReady,
            language: language,
          ),
          _ReadinessRow(
            label: YorksV1CompanyMaterialRequestStrings.approvalRoute.active(
              language,
            ),
            ready: preflight != null,
            checking: routeChecking,
            language: language,
          ),
          if (selected != null || materialCount > 0 || preflight != null) ...[
            const Divider(height: AppSpacing.xl),
            if (selected != null)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.categoryAndUnit
                    .active(language),
                value:
                    '${selected.categoryName} · ${selected.responsibleUnitName}',
              ),
            if (beneficiary != null)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.beneficiary.active(
                  language,
                ),
                value: beneficiary.displayName,
              ),
            if (receiver != null)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.authorizedReceiver
                    .active(language),
                value: receiver.displayName,
              ),
            if (draft.purpose?.trim().isNotEmpty == true)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.purpose.active(
                  language,
                ),
                value: draft.purpose!.trim(),
              ),
            if (draft.deliveryCollectionPoint?.trim().isNotEmpty == true)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings
                    .deliveryCollectionPoint
                    .active(language),
                value: draft.deliveryCollectionPoint!.trim(),
              ),
            if (materialCount > 0)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.materialItems
                    .active(language),
                value: YorksV1CompanyMaterialRequestStrings.itemCount(
                  materialCount,
                ).active(language),
              ),
            if (preflight != null)
              _SummaryFact(
                label: YorksV1CompanyMaterialRequestStrings.approver.active(
                  language,
                ),
                value: preflight!.approver.displayName,
                last: true,
              ),
          ],
          if (routeUnavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              YorksV1CompanyMaterialRequestStrings.routeUnavailable.active(
                language,
              ),
              style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.ready,
    required this.language,
    this.checking = false,
  });
  final String label;
  final bool ready;
  final bool checking;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        if (checking)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 19,
            color: ready ? AppColors.success : AppColors.muted,
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTypography.bodySmall)),
        Text(
          (ready
                  ? YorksV1CompanyMaterialRequestStrings.ready
                  : YorksV1CompanyMaterialRequestStrings.required)
              .active(language),
          style: AppTypography.labelSmall.copyWith(
            color: ready ? AppColors.success : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ReviewLines extends StatelessWidget {
  const _ReviewLines({required this.language, required this.lines});
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestLine> lines;
  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YorksMobileSectionHeader(
          title: YorksV1CompanyMaterialRequestStrings.materialItems.active(
            language,
          ),
          subtitle: YorksV1CompanyMaterialRequestStrings.itemCount(
            _materialCount(lines),
          ).active(language),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const Divider(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.blueContainer,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines[index].description,
                      style: AppTypography.titleSmall,
                    ),
                    if (lines[index].brandOrigin?.trim().isNotEmpty == true)
                      Text(
                        lines[index].brandOrigin!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${lines[index].quantity} ${lines[index].unit}',
                style: AppTypography.labelLarge,
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ApprovalStatus extends StatelessWidget {
  const _ApprovalStatus({
    required this.language,
    required this.checking,
    required this.routeUnavailable,
    required this.preflight,
  });
  final AppLanguage language;
  final bool checking;
  final bool routeUnavailable;
  final YorksV1CompanyMaterialRequestApprovalPreflight? preflight;
  @override
  Widget build(BuildContext context) {
    if (checking) {
      return _CompanyCard(
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                YorksV1CompanyMaterialRequestStrings.routeChecking.active(
                  language,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (preflight != null) {
      return YorksMobileCallout(
        icon: Icons.verified_user_outlined,
        title: YorksV1CompanyMaterialRequestStrings.approvalHandoffTitle.active(
          language,
        ),
        message: YorksV1CompanyMaterialRequestStrings.approvalHandoff(
          preflight!.approver.displayName,
        ).active(language),
      );
    }
    if (routeUnavailable) {
      return YorksMobileCallout(
        icon: Icons.warning_amber_rounded,
        title: YorksV1CompanyMaterialRequestStrings.unavailableTitle.active(
          language,
        ),
        message: YorksV1CompanyMaterialRequestStrings.routeUnavailable.active(
          language,
        ),
        warning: true,
      );
    }
    return _CompanyCard(
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              YorksV1CompanyMaterialRequestStrings.approvalGuidance.active(
                language,
              ),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyProgress extends StatelessWidget {
  const _CompanyProgress({required this.step, required this.language});
  final _CompanyRequestStep step;
  final AppLanguage language;
  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        _CompanyRequestStep.details,
        YorksV1MaterialRequestStrings.detailsStep.active(language),
      ),
      (
        _CompanyRequestStep.items,
        YorksV1MaterialRequestStrings.items.active(language),
      ),
      (
        _CompanyRequestStep.review,
        YorksV1MaterialRequestStrings.review.active(language),
      ),
    ];
    final active = step.index;
    return Semantics(
      label: '${active + 1} / ${entries.length}',
      child: Row(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index <= active
                                ? AppColors.blue
                                : AppColors.lineStrong,
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= active
                              ? AppColors.blue
                              : AppColors.surfaceContainerLowest,
                          border: Border.all(
                            color: index <= active
                                ? AppColors.blue
                                : AppColors.lineStrong,
                          ),
                        ),
                        child: index < active
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: AppTypography.labelMedium.copyWith(
                                  color: index == active
                                      ? Colors.white
                                      : AppColors.muted,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                      if (index < entries.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < active
                                ? AppColors.blue
                                : AppColors.lineStrong,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entries[index].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: index == active ? AppColors.blue : AppColors.muted,
                      fontWeight: index == active
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanyRequestPolicyState extends StatelessWidget {
  const _CompanyRequestPolicyState({
    required this.language,
    required this.onRetry,
  });
  final AppLanguage language;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      title: Text(YorksV1CompanyMaterialRequestStrings.title.active(language)),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _CompanyCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.policy_outlined,
                  color: AppColors.warning,
                  size: 42,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  YorksV1CompanyMaterialRequestStrings.unavailableTitle.active(
                    language,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  YorksV1CompanyMaterialRequestStrings.noEligibleOptions.active(
                    language,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    YorksV1CompanyMaterialRequestStrings.retry.active(language),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.blue),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.blue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _SummaryFact extends StatelessWidget {
  const _SummaryFact({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodyMedium),
      ],
    ),
  );
}

class _SavingLabel extends StatelessWidget {
  const _SavingLabel({required this.saving, required this.label});
  final bool saving;
  final String label;
  @override
  Widget build(BuildContext context) => saving
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(label);
}

YorksV1CompanyMaterialRequestDraftOption? _selectedOption(
  List<YorksV1CompanyMaterialRequestDraftOption> options,
  YorksV1CompanyMaterialRequestDraft draft,
) {
  for (final option in options) {
    if (option.categoryId == draft.categoryId &&
        option.responsibleUnitId == draft.responsibleUnitId) {
      return option;
    }
  }
  return null;
}

YorksV1CompanyMaterialRequestPerson? _selectedPerson(
  List<YorksV1CompanyMaterialRequestPerson>? people,
  String? id,
) {
  if (people == null || id == null) return null;
  for (final person in people) {
    if (person.authUserId == id) return person;
  }
  return null;
}
