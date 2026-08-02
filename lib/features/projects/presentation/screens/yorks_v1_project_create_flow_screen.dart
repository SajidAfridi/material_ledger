import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/yorks_v1_project_controller.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_boq_strings.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_project.dart';
import '../../../../shared/models/yorks_v1_project_creation_draft.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_project_team_directory_member.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_project_controller_provider.dart';
import '../../../../shared/providers/yorks_v1_project_creation_draft_provider.dart';
import '../../../../shared/providers/yorks_v1_project_team_directory_provider.dart';

/// The normalized Yorks V1 R35 project creation experience.
///
/// This screen intentionally owns only recoverable local draft input and
/// delegates the committed create command to [YorksV1ProjectCommandController].
/// It never writes projects, scopes, memberships or BOQ groups locally.
class YorksV1ProjectCreateFlowScreen extends ConsumerStatefulWidget {
  const YorksV1ProjectCreateFlowScreen({super.key, this.onProjectCreated});

  /// Lets route composition move to the authoritative project workspace after
  /// the server has committed the project. It is deliberately called only
  /// after the local creation draft was discarded.
  final ValueChanged<YorksV1Project>? onProjectCreated;

  @override
  ConsumerState<YorksV1ProjectCreateFlowScreen> createState() =>
      _YorksV1ProjectCreateFlowScreenState();
}

class _YorksV1ProjectCreateFlowScreenState
    extends ConsumerState<YorksV1ProjectCreateFlowScreen> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _referenceController = TextEditingController();
  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _jobOrContractController = TextEditingController();
  final _siteController = TextEditingController();
  final _notesController = TextEditingController();
  final _consultantController = TextEditingController();
  final _mainContractorController = TextEditingController();
  final _subcontractorController = TextEditingController();
  final _otherContractorController = TextEditingController();
  final _buildingCodeController = TextEditingController();
  final _buildingNameController = TextEditingController();
  final _buildingFloorsController = TextEditingController();
  final _buildingDeliveryAddressController = TextEditingController();
  final _attachmentNameController = TextEditingController();
  final _attachmentMimeTypeController = TextEditingController();
  final _attachmentSizeBytesController = TextEditingController();

  Timer? _draftSaveTimer;
  YorksV1ProjectCreationDraft? _pendingDraft;
  String? _activeAuthUserId;
  Set<YorksV1ProjectValidationCode> _validationErrors = const {};
  YorksV1Project? _createdProject;
  bool _hasFrpRoom = false;
  bool _isCreating = false;

  List<TextEditingController> get _controllers => [
    _referenceController,
    _nameController,
    _clientController,
    _jobOrContractController,
    _siteController,
    _notesController,
    _consultantController,
    _mainContractorController,
    _subcontractorController,
    _otherContractorController,
    _buildingCodeController,
    _buildingNameController,
    _buildingFloorsController,
    _buildingDeliveryAddressController,
    _attachmentNameController,
    _attachmentMimeTypeController,
    _attachmentSizeBytesController,
  ];

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _scrollController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final authUserId = ref.watch(yorksV1AuthUserIdProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);

    if (authUserId == null || authUserId.trim().isEmpty) {
      return _AccessState(
        title: YorksV1ProjectStrings.signInRequired,
        description: YorksV1ProjectStrings.signInRequired,
        language: language,
      );
    }
    if (role == null || !role.canCreateProject) {
      return _AccessState(
        title: YorksV1ProjectStrings.noPermission,
        description: YorksV1ProjectStrings.noPermissionDescription,
        language: language,
      );
    }

    if (_activeAuthUserId != authUserId) {
      _draftSaveTimer?.cancel();
      _pendingDraft = null;
      _activeAuthUserId = authUserId;
      _createdProject = null;
      _validationErrors = const {};
    }

    final draft = ref.watch(yorksV1ProjectCreationDraftProvider(authUserId));
    _synchronizeControllers(_pendingDraft ?? draft);
    final commandState = ref.watch(yorksV1ProjectCommandControllerProvider);

    final createdProject = _createdProject;
    if (createdProject != null) {
      return _CreatedProjectState(project: createdProject, language: language);
    }

    // The directory is needed only on the access and review stages. Keeping
    // the request out of the remaining creation flow both minimises the
    // exposure window for this safe projection and avoids needless RPC calls.
    final teamDirectory =
        draft.currentStage == YorksV1ProjectCreationStage.partiesAndAccess ||
            draft.currentStage == YorksV1ProjectCreationStage.reviewAndCreate
        ? ref.watch(yorksV1ActiveProjectTeamDirectoryProvider)
        : null;

    final saving =
        _isCreating ||
        (commandState.operation ==
                YorksV1ProjectCommandOperation.createProject &&
            commandState.status == YorksV1ProjectCommandStatus.saving);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop =
                constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
            final content = _buildStageContent(
              draft: draft,
              language: language,
              saving: saving,
              creatorRole: role,
              creatorAuthUserId: authUserId,
              teamDirectory: teamDirectory,
            );
            final navigation = _StageNavigation(
              currentStage: draft.currentStage,
              language: language,
              vertical: desktop,
              onSelect: _selectStage,
            );
            final horizontal = desktop
                ? AppSpacing.xxxl + AppSpacing.xs
                : AppSpacing.lg;
            return SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.xxxl,
                horizontal,
                72,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.pageMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    YorksR35PageHeader(
                      eyebrow:
                          YorksV1ProjectStrings.projectCreationEyebrow.primary,
                      title: YorksV1ProjectStrings.createProject.primary,
                      description: YorksV1ProjectStrings
                          .createProjectDescription
                          .primary,
                      actions: [
                        SizedBox(
                          height: AppSpacing.minTapTarget,
                          child: OutlinedButton(
                            onPressed: saving ? null : () => _saveDraft(draft),
                            child: Text(
                              YorksV1ProjectStrings.saveDraft.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (desktop)
                      _R35ProjectCreationFrame(
                        navigation: navigation,
                        currentStage: draft.currentStage,
                        content: content,
                      )
                    else ...[
                      navigation,
                      const SizedBox(height: AppSpacing.lg),
                      _R35ProjectCreationFrame(
                        currentStage: draft.currentStage,
                        content: content,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageContent({
    required YorksV1ProjectCreationDraft draft,
    required AppLanguage language,
    required bool saving,
    required YorksV1Role creatorRole,
    required String creatorAuthUserId,
    required AsyncValue<List<YorksV1ProjectTeamDirectoryMember>>? teamDirectory,
  }) {
    final stage = draft.currentStage;
    final stageBody = switch (stage) {
      YorksV1ProjectCreationStage.projectDetails => _DetailsStage(
        formKey: _detailsFormKey,
        language: language,
        referenceController: _referenceController,
        nameController: _nameController,
        clientController: _clientController,
        jobOrContractController: _jobOrContractController,
        siteController: _siteController,
        notesController: _notesController,
        startDate: draft.startDate,
        endDate: draft.endDate,
        validationErrors: _validationErrors,
        onReferenceChanged: (value) =>
            _queueDraft((current) => current.copyWith(reference: value)),
        onNameChanged: (value) =>
            _queueDraft((current) => current.copyWith(name: value)),
        onClientChanged: (value) =>
            _queueDraft((current) => current.copyWith(clientName: value)),
        onJobOrContractChanged: (value) => _queueDraft(
          (current) => current.copyWith(jobOrContractReference: value),
        ),
        onSiteChanged: (value) =>
            _queueDraft((current) => current.copyWith(siteLocation: value)),
        onNotesChanged: (value) =>
            _queueDraft((current) => current.copyWith(notes: value)),
        onSelectStartDate: () => _selectDate(isStartDate: true),
        onSelectEndDate: () => _selectDate(isStartDate: false),
      ),
      YorksV1ProjectCreationStage.partiesAndAccess => _PartiesAndAccessStage(
        draft: draft,
        language: language,
        consultantController: _consultantController,
        mainContractorController: _mainContractorController,
        subcontractorController: _subcontractorController,
        otherContractorController: _otherContractorController,
        validationErrors: _validationErrors,
        creatorRole: creatorRole,
        creatorAuthUserId: creatorAuthUserId,
        teamDirectory: teamDirectory!,
        onConsultantChanged: (value) =>
            _setSingleParty(YorksV1ProjectPartyKind.consultant, value),
        onMainContractorChanged: (value) =>
            _setSingleParty(YorksV1ProjectPartyKind.mainContractor, value),
        onAddSubcontractor: () => _addNamedParty(
          YorksV1ProjectPartyKind.subcontractor,
          _subcontractorController,
        ),
        onAddOtherContractor: () => _addNamedParty(
          YorksV1ProjectPartyKind.otherContractor,
          _otherContractorController,
        ),
        onRemoveParty: _removePartyAt,
        onAddInitialMember: _addInitialMember,
        onRemoveInitialMember: _removeInitialMemberAt,
      ),
      YorksV1ProjectCreationStage.buildings => _BuildingsStage(
        draft: draft,
        language: language,
        codeController: _buildingCodeController,
        nameController: _buildingNameController,
        floorsController: _buildingFloorsController,
        deliveryAddressController: _buildingDeliveryAddressController,
        hasFrpRoom: _hasFrpRoom,
        validationErrors: _validationErrors,
        onHasFrpRoomChanged: (value) => setState(() => _hasFrpRoom = value),
        onAddBuilding: _addBuilding,
        onRemoveBuilding: _removeBuildingAt,
      ),
      YorksV1ProjectCreationStage.attachments => _AttachmentsStage(
        draft: draft,
        language: language,
        nameController: _attachmentNameController,
        mimeTypeController: _attachmentMimeTypeController,
        sizeBytesController: _attachmentSizeBytesController,
        validationErrors: _validationErrors,
        onAddAttachment: _addAttachment,
        onRemoveAttachment: _removeAttachmentAt,
      ),
      YorksV1ProjectCreationStage.reviewAndCreate => _ReviewStage(
        draft: draft,
        language: language,
        validationErrors: _validationErrors,
        teamDirectory: teamDirectory!,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stageBody,
        const SizedBox(height: AppSpacing.lg),
        _StageActions(
          stage: stage,
          language: language,
          saving: saving,
          onBack: _back,
          onContinue: _continue,
          onSkip: _skipAttachments,
          onCreate: _createProject,
        ),
      ],
    );
  }

  void _synchronizeControllers(YorksV1ProjectCreationDraft draft) {
    _setControllerText(_referenceController, draft.reference);
    _setControllerText(_nameController, draft.name);
    _setControllerText(_clientController, draft.clientName ?? '');
    _setControllerText(
      _jobOrContractController,
      draft.jobOrContractReference ?? '',
    );
    _setControllerText(_siteController, draft.siteLocation ?? '');
    _setControllerText(_notesController, draft.notes ?? '');
    _setControllerText(
      _consultantController,
      _partyFor(draft, YorksV1ProjectPartyKind.consultant)?.name ?? '',
    );
    _setControllerText(
      _mainContractorController,
      _partyFor(draft, YorksV1ProjectPartyKind.mainContractor)?.name ?? '',
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  YorksV1ProjectCreationDraft _currentDraft() {
    final authUserId = _activeAuthUserId;
    if (authUserId == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthenticated,
      );
    }
    return _pendingDraft ??
        ref.read(yorksV1ProjectCreationDraftProvider(authUserId));
  }

  void _queueDraft(
    YorksV1ProjectCreationDraft Function(YorksV1ProjectCreationDraft current)
    transform,
  ) {
    if (_activeAuthUserId == null) return;
    _pendingDraft = transform(_currentDraft());
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_flushPendingDraft());
    });
  }

  Future<void> _flushPendingDraft() async {
    _draftSaveTimer?.cancel();
    final pending = _pendingDraft;
    final authUserId = _activeAuthUserId;
    if (pending == null || authUserId == null) return;
    _pendingDraft = null;
    await ref
        .read(yorksV1ProjectCreationDraftProvider(authUserId).notifier)
        .save(pending);
  }

  Future<void> _saveDraft(YorksV1ProjectCreationDraft draft) async {
    _draftSaveTimer?.cancel();
    _pendingDraft = null;
    final authUserId = _activeAuthUserId;
    if (authUserId == null) return;
    await ref
        .read(yorksV1ProjectCreationDraftProvider(authUserId).notifier)
        .save(draft);
  }

  Future<void> _selectStage(YorksV1ProjectCreationStage target) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (target.index > current.currentStage.index) return;
    await _setStage(target);
  }

  Future<void> _setStage(YorksV1ProjectCreationStage stage) async {
    final authUserId = _activeAuthUserId;
    if (authUserId == null) return;
    final current = _currentDraft();
    _draftSaveTimer?.cancel();
    _pendingDraft = null;
    await ref
        .read(yorksV1ProjectCreationDraftProvider(authUserId).notifier)
        .save(current.copyWith(currentStage: stage));
    if (!mounted) return;
    _validationErrors = const {};
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _continue() async {
    await _flushPendingDraft();
    final draft = _currentDraft();
    final errors = _errorsForStage(draft.currentStage, draft);
    if (draft.currentStage == YorksV1ProjectCreationStage.projectDetails &&
        !(_detailsFormKey.currentState?.validate() ?? false)) {
      _presentValidationErrors(errors.isEmpty ? _requiredFieldErrors : errors);
      return;
    }
    if (errors.isNotEmpty) {
      _presentValidationErrors(errors);
      return;
    }
    final next = draft.currentStage.next;
    if (next != null) await _setStage(next);
  }

  Future<void> _skipAttachments() async {
    await _flushPendingDraft();
    await _setStage(YorksV1ProjectCreationStage.reviewAndCreate);
  }

  Future<void> _back() async {
    await _flushPendingDraft();
    if (!mounted) return;
    final current = _currentDraft().currentStage;
    final previous = current.previous;
    if (previous == null) {
      await Navigator.of(context).maybePop();
      return;
    }
    await _setStage(previous);
  }

  Set<YorksV1ProjectValidationCode> get _requiredFieldErrors => {
    YorksV1ProjectValidationCode.missingProjectReference,
    YorksV1ProjectValidationCode.missingProjectName,
  };

  Set<YorksV1ProjectValidationCode> _errorsForStage(
    YorksV1ProjectCreationStage stage,
    YorksV1ProjectCreationDraft draft,
  ) {
    final all = draft.toCreationInput().validate();
    return switch (stage) {
      YorksV1ProjectCreationStage.projectDetails =>
        all
            .where(
              (error) =>
                  error ==
                      YorksV1ProjectValidationCode.missingProjectReference ||
                  error == YorksV1ProjectValidationCode.missingProjectName ||
                  error == YorksV1ProjectValidationCode.invalidDateRange,
            )
            .toSet(),
      YorksV1ProjectCreationStage.partiesAndAccess =>
        all
            .where(
              (error) =>
                  error == YorksV1ProjectValidationCode.invalidProjectParty ||
                  error == YorksV1ProjectValidationCode.duplicateProjectParty ||
                  error == YorksV1ProjectValidationCode.duplicateMember ||
                  error == YorksV1ProjectValidationCode.missingMemberAuthUserId,
            )
            .toSet(),
      YorksV1ProjectCreationStage.buildings =>
        all
            .where(
              (error) =>
                  error == YorksV1ProjectValidationCode.missingBuilding ||
                  error == YorksV1ProjectValidationCode.invalidBuilding ||
                  error == YorksV1ProjectValidationCode.duplicateBuildingCode,
            )
            .toSet(),
      YorksV1ProjectCreationStage.attachments =>
        all
            .where(
              (error) =>
                  error == YorksV1ProjectValidationCode.invalidAttachment,
            )
            .toSet(),
      YorksV1ProjectCreationStage.reviewAndCreate => all,
    };
  }

  void _presentValidationErrors(Set<YorksV1ProjectValidationCode> errors) {
    if (!mounted) return;
    setState(() => _validationErrors = Set.unmodifiable(errors));
    _showMessage(_messageForValidation(errors), error: true);
  }

  TranslatableString _messageForValidation(
    Set<YorksV1ProjectValidationCode> errors,
  ) {
    if (errors.contains(YorksV1ProjectValidationCode.invalidDateRange)) {
      return YorksV1ProjectStrings.endDateAfterStart;
    }
    if (errors.contains(YorksV1ProjectValidationCode.missingBuilding) ||
        errors.contains(YorksV1ProjectValidationCode.invalidBuilding)) {
      return YorksV1ProjectStrings.atLeastOneBuilding;
    }
    if (errors.contains(YorksV1ProjectValidationCode.duplicateBuildingCode)) {
      return YorksV1ProjectStrings.duplicateBuildingCode;
    }
    if (errors.contains(YorksV1ProjectValidationCode.duplicateMember)) {
      return YorksV1ProjectStrings.duplicateMember;
    }
    if (errors.contains(YorksV1ProjectValidationCode.missingProjectReference) ||
        errors.contains(YorksV1ProjectValidationCode.missingProjectName)) {
      return YorksV1ProjectStrings.requiredField;
    }
    return YorksV1ProjectStrings.stageNeedsAttention;
  }

  void _showMessage(TranslatableString copy, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.error : null,
          content: Text(copy.primary),
        ),
      );
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    await _flushPendingDraft();
    if (!mounted) return;
    final draft = _currentDraft();
    final selected = isStartDate ? draft.startDate : draft.endDate;
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: selected == null ? today : DateUtils.dateOnly(selected),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    await _saveDraft(
      isStartDate
          ? draft.copyWith(startDate: DateUtils.dateOnly(date))
          : draft.copyWith(endDate: DateUtils.dateOnly(date)),
    );
  }

  void _setSingleParty(YorksV1ProjectPartyKind kind, String name) {
    _queueDraft((current) {
      final existing = _partyFor(current, kind);
      final parties = <YorksV1ProjectPartyInput>[
        for (final party in current.parties)
          if (party.kind != kind) party,
      ];
      if (name.trim().isNotEmpty) {
        parties.add(
          YorksV1ProjectPartyInput(
            kind: kind,
            name: name,
            contactName: existing?.contactName,
            contactPhone: existing?.contactPhone,
            contactEmail: existing?.contactEmail,
            address: existing?.address,
          ),
        );
      }
      return current.copyWith(parties: parties);
    });
  }

  Future<void> _addNamedParty(
    YorksV1ProjectPartyKind kind,
    TextEditingController controller,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      _showMessage(YorksV1ProjectStrings.requiredField, error: true);
      return;
    }
    await _flushPendingDraft();
    final current = _currentDraft();
    await _saveDraft(
      current.copyWith(
        parties: [
          ...current.parties,
          YorksV1ProjectPartyInput(kind: kind, name: name),
        ],
      ),
    );
    controller.clear();
  }

  Future<void> _removePartyAt(int index) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (index < 0 || index >= current.parties.length) return;
    await _saveDraft(
      current.copyWith(
        parties: [
          for (var item = 0; item < current.parties.length; item++)
            if (item != index) current.parties[item],
        ],
      ),
    );
  }

  Future<void> _addInitialMember(
    YorksV1ProjectTeamDirectoryMember member,
    YorksV1ProjectMembershipRole projectRole,
  ) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (current.initialMembers.any(
      (assigned) => assigned.authUserId == member.authUserId,
    )) {
      _showMessage(YorksV1ProjectStrings.duplicateMember, error: true);
      return;
    }
    await _saveDraft(
      current.copyWith(
        initialMembers: [
          ...current.initialMembers,
          YorksV1InitialProjectMemberInput(
            authUserId: member.authUserId,
            projectRole: projectRole,
          ),
        ],
      ),
    );
  }

  Future<void> _removeInitialMemberAt(int index) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (index < 0 || index >= current.initialMembers.length) return;
    await _saveDraft(
      current.copyWith(
        initialMembers: [
          for (var item = 0; item < current.initialMembers.length; item++)
            if (item != index) current.initialMembers[item],
        ],
      ),
    );
  }

  Future<void> _addBuilding() async {
    final name = _buildingNameController.text.trim();
    if (name.isEmpty) {
      _showMessage(YorksV1ProjectStrings.requiredField, error: true);
      return;
    }
    await _flushPendingDraft();
    final current = _currentDraft();
    final building = YorksV1ProjectBuildingInput(
      code: _buildingCodeController.text,
      name: name,
      floorsOrLevels: _buildingFloorsController.text
          .split(RegExp(r'[\n,]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      hasFrpRoom: _hasFrpRoom,
      deliveryAddress: _emptyToNull(_buildingDeliveryAddressController.text),
    );
    await _saveDraft(
      current.copyWith(buildings: [...current.buildings, building]),
    );
    _buildingCodeController.clear();
    _buildingNameController.clear();
    _buildingFloorsController.clear();
    _buildingDeliveryAddressController.clear();
    if (mounted) setState(() => _hasFrpRoom = false);
  }

  Future<void> _removeBuildingAt(int index) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (index < 0 || index >= current.buildings.length) return;
    await _saveDraft(
      current.copyWith(
        buildings: [
          for (var item = 0; item < current.buildings.length; item++)
            if (item != index) current.buildings[item],
        ],
      ),
    );
  }

  Future<void> _addAttachment() async {
    final fileName = _attachmentNameController.text.trim();
    if (fileName.isEmpty) {
      _showMessage(YorksV1ProjectStrings.requiredField, error: true);
      return;
    }
    final rawSize = _attachmentSizeBytesController.text.trim();
    final sizeBytes = rawSize.isEmpty ? null : int.tryParse(rawSize);
    if (rawSize.isNotEmpty && (sizeBytes == null || sizeBytes < 0)) {
      _showMessage(YorksV1ProjectStrings.stageNeedsAttention, error: true);
      return;
    }
    await _flushPendingDraft();
    final current = _currentDraft();
    await _saveDraft(
      current.copyWith(
        attachments: [
          ...current.attachments,
          YorksV1ProjectAttachmentInput(
            fileName: fileName,
            mimeType: _emptyToNull(_attachmentMimeTypeController.text),
            sizeBytes: sizeBytes,
          ),
        ],
      ),
    );
    _attachmentNameController.clear();
    _attachmentMimeTypeController.clear();
    _attachmentSizeBytesController.clear();
  }

  Future<void> _removeAttachmentAt(int index) async {
    await _flushPendingDraft();
    final current = _currentDraft();
    if (index < 0 || index >= current.attachments.length) return;
    await _saveDraft(
      current.copyWith(
        attachments: [
          for (var item = 0; item < current.attachments.length; item++)
            if (item != index) current.attachments[item],
        ],
      ),
    );
  }

  Future<void> _createProject() async {
    if (_isCreating) return;
    await _flushPendingDraft();
    final draft = _currentDraft();
    final loadedDirectory = ref
        .read(yorksV1ActiveProjectTeamDirectoryProvider)
        .asData
        ?.value;
    if (loadedDirectory != null &&
        _hasUnavailableInitialMember(draft, loadedDirectory)) {
      _showMessage(
        YorksV1ProjectStrings.teamMemberNoLongerAvailable,
        error: true,
      );
      if (draft.currentStage != YorksV1ProjectCreationStage.partiesAndAccess) {
        await _setStage(YorksV1ProjectCreationStage.partiesAndAccess);
      }
      return;
    }
    final errors = draft.toCreationInput().validate();
    if (errors.isNotEmpty) {
      _presentValidationErrors(errors);
      final targetStage = _firstInvalidStage(errors);
      if (targetStage != draft.currentStage) await _setStage(targetStage);
      return;
    }

    setState(() => _isCreating = true);
    try {
      final result = await ref
          .read(yorksV1ProjectCommandControllerProvider.notifier)
          .createProject(draft.toCreationInput());

      final authUserId = _activeAuthUserId;
      if (authUserId != null) {
        await ref
            .read(yorksV1ProjectCreationDraftProvider(authUserId).notifier)
            .discard();
      }
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createdProject = result.project;
      });
      widget.onProjectCreated?.call(result.project);
    } on YorksV1DomainException catch (error) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showMessage(YorksV1ProjectStrings.errorFor(error.code), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showMessage(
        YorksV1ProjectStrings.errorFor(
          YorksV1DomainErrorCode.unexpectedResponse,
        ),
        error: true,
      );
    }
  }

  YorksV1ProjectCreationStage _firstInvalidStage(
    Set<YorksV1ProjectValidationCode> errors,
  ) {
    for (final stage in YorksV1ProjectCreationStage.values) {
      if (_errorsForStage(stage, _currentDraft()).isNotEmpty) return stage;
    }
    return YorksV1ProjectCreationStage.reviewAndCreate;
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState({
    required this.title,
    required this.description,
    required this.language,
  });

  final TranslatableString title;
  final TranslatableString description;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: NexusPageShell(
          eyebrow: YorksV1ProjectStrings.projects.primary,
          title: title.primary,
          child: NexusSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _LocalizedCopy(
                    copy: description,
                    language: language,
                    englishStyle: AppTypography.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatedProjectState extends ConsumerWidget {
  const _CreatedProjectState({required this.project, required this.language});

  final YorksV1Project project;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boqEnabled = ref.watch(yorksV1FeatureFlagsProvider).boq;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: NexusPageShell(
          eyebrow: YorksV1ProjectStrings.projectCreationEyebrow.primary,
          title: YorksV1ProjectStrings.projectCreated.primary,
          child: NexusSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.md),
                _LocalizedCopy(
                  copy: YorksV1ProjectStrings.projectCreatedDescription,
                  language: language,
                  englishStyle: AppTypography.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ReviewValue(
                  label: YorksV1ProjectStrings.yorksReference,
                  value: project.reference,
                  language: language,
                ),
                const SizedBox(height: AppSpacing.md),
                _ReviewValue(
                  label: YorksV1ProjectStrings.projectName,
                  value: project.name,
                  language: language,
                ),
                if (boqEnabled) ...[
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: YorksV1BoqStrings.worksheets.primary,
                    icon: Icons.folder_open_outlined,
                    onPressed: () =>
                        context.go(RoutePaths.yorksV1BoqGroupsPath(project.id)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _R35ProjectCreationFrame extends StatelessWidget {
  const _R35ProjectCreationFrame({
    required this.currentStage,
    required this.content,
    this.navigation,
  });

  final YorksV1ProjectCreationStage currentStage;
  final Widget content;
  final Widget? navigation;

  @override
  Widget build(BuildContext context) {
    final sidebarMinHeight = MediaQuery.sizeOf(context).height * 0.75;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _R35CreationStageHeader(stage: currentStage),
        const Divider(height: 1, color: AppColors.line),
        Padding(padding: const EdgeInsets.all(AppSpacing.xxxl), child: content),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: navigation == null
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 270,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: sidebarMinHeight),
                    child: ColoredBox(
                      color: AppColors.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              YorksV1ProjectStrings.projectSetup.primary,
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              YorksV1ProjectStrings
                                  .projectSetupDescription
                                  .primary,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            navigation!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.line),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _R35CreationStageHeader extends StatelessWidget {
  const _R35CreationStageHeader({required this.stage});

  final YorksV1ProjectCreationStage stage;

  @override
  Widget build(BuildContext context) {
    final step = YorksV1ProjectStrings.stepOf.primary
        .replaceFirst('{current}', '${stage.index + 1}')
        .replaceFirst(
          '{total}',
          '${YorksV1ProjectCreationStage.values.length}',
        );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.blue,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _stageCopy(stage).primary,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                YorksV1ProjectStrings.stepSaved.primary,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageNavigation extends StatelessWidget {
  const _StageNavigation({
    required this.currentStage,
    required this.language,
    required this.vertical,
    required this.onSelect,
  });

  final YorksV1ProjectCreationStage currentStage;
  final AppLanguage language;
  final bool vertical;
  final ValueChanged<YorksV1ProjectCreationStage> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final stage in YorksV1ProjectCreationStage.values)
        _StageNavigationItem(
          stage: stage,
          currentStage: currentStage,
          language: language,
          onTap: stage.index <= currentStage.index
              ? () => onSelect(stage)
              : null,
        ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            SizedBox(width: 172, child: children[index]),
            if (index != children.length - 1)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StageNavigationItem extends StatelessWidget {
  const _StageNavigationItem({
    required this.stage,
    required this.currentStage,
    required this.language,
    required this.onTap,
  });

  final YorksV1ProjectCreationStage stage;
  final YorksV1ProjectCreationStage currentStage;
  final AppLanguage language;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = stage == currentStage;
    final copy = _stageCopy(stage);
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.blueContainer
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          key: ValueKey('yorks-v1-project-stage-${stage.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.navy
                          : AppColors.neutralContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${stage.index + 1}',
                      style: AppTypography.labelLarge.copyWith(
                        color: selected ? AppColors.onPrimary : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _LocalizedCopy(
                      copy: copy,
                      language: language,
                      englishStyle: AppTypography.labelLarge.copyWith(
                        color: selected ? AppColors.navy : AppColors.ink,
                      ),
                      secondaryStyle: AppTypography.labelSmall,
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
}

class _DetailsStage extends StatelessWidget {
  const _DetailsStage({
    required this.formKey,
    required this.language,
    required this.referenceController,
    required this.nameController,
    required this.clientController,
    required this.jobOrContractController,
    required this.siteController,
    required this.notesController,
    required this.startDate,
    required this.endDate,
    required this.validationErrors,
    required this.onReferenceChanged,
    required this.onNameChanged,
    required this.onClientChanged,
    required this.onJobOrContractChanged,
    required this.onSiteChanged,
    required this.onNotesChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
  });

  final GlobalKey<FormState> formKey;
  final AppLanguage language;
  final TextEditingController referenceController;
  final TextEditingController nameController;
  final TextEditingController clientController;
  final TextEditingController jobOrContractController;
  final TextEditingController siteController;
  final TextEditingController notesController;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final ValueChanged<String> onReferenceChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onClientChanged;
  final ValueChanged<String> onJobOrContractChanged;
  final ValueChanged<String> onSiteChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;

  @override
  Widget build(BuildContext context) {
    final required = YorksV1ProjectStrings.requiredField.primary;
    return Form(
      key: formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final fields = [
            LedgerTextField(
              key: const ValueKey('yorks-v1-project-reference'),
              controller: referenceController,
              label: YorksV1ProjectStrings.yorksReference.active(language),
              hintText: YorksV1ProjectStrings.yorksReference.active(language),
              onChanged: onReferenceChanged,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? required : null,
            ),
            LedgerTextField(
              key: const ValueKey('yorks-v1-project-name'),
              controller: nameController,
              label: YorksV1ProjectStrings.projectName.active(language),
              hintText: YorksV1ProjectStrings.projectName.active(language),
              onChanged: onNameChanged,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? required : null,
            ),
            LedgerTextField(
              key: const ValueKey('yorks-v1-project-client'),
              controller: clientController,
              label: YorksV1ProjectStrings.client.active(language),
              hintText: YorksV1ProjectStrings.client.active(language),
              onChanged: onClientChanged,
            ),
            LedgerTextField(
              key: const ValueKey('yorks-v1-project-job-contract'),
              controller: jobOrContractController,
              label: YorksV1ProjectStrings.jobOrContractReference.active(
                language,
              ),
              hintText: YorksV1ProjectStrings.jobOrContractReference.active(
                language,
              ),
              onChanged: onJobOrContractChanged,
            ),
            LedgerTextField(
              key: const ValueKey('yorks-v1-project-site'),
              controller: siteController,
              label: YorksV1ProjectStrings.siteLocation.active(language),
              hintText: YorksV1ProjectStrings.siteLocation.active(language),
              onChanged: onSiteChanged,
            ),
            _DateField(
              copy: YorksV1ProjectStrings.startDate,
              value: startDate,
              language: language,
              onTap: onSelectStartDate,
            ),
            _DateField(
              copy: YorksV1ProjectStrings.endDate,
              value: endDate,
              language: language,
              onTap: onSelectEndDate,
              error:
                  validationErrors.contains(
                    YorksV1ProjectValidationCode.invalidDateRange,
                  )
                  ? YorksV1ProjectStrings.endDateAfterStart.primary
                  : null,
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: [
                    for (final field in fields)
                      SizedBox(
                        width: (constraints.maxWidth - AppSpacing.lg) / 2,
                        child: field,
                      ),
                  ],
                )
              else
                ..._withGaps(fields),
              const SizedBox(height: AppSpacing.lg),
              LedgerTextField(
                key: const ValueKey('yorks-v1-project-notes'),
                controller: notesController,
                label: YorksV1ProjectStrings.notes.active(language),
                hintText: YorksV1ProjectStrings.notes.active(language),
                maxLines: 4,
                onChanged: onNotesChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.copy,
    required this.value,
    required this.language,
    required this.onTap,
    this.error,
  });

  final TranslatableString copy;
  final DateTime? value;
  final AppLanguage language;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final selected = value == null
        ? YorksV1ProjectStrings.selectDate.primary
        : MaterialLocalizations.of(context).formatMediumDate(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocalizedCopy(
          copy: copy,
          language: language,
          englishStyle: AppTypography.titleSmall,
          secondaryStyle: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: ValueKey('yorks-v1-project-date-${copy.primary}'),
          onPressed: onTap,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(selected),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            error!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _PartiesAndAccessStage extends StatelessWidget {
  const _PartiesAndAccessStage({
    required this.draft,
    required this.language,
    required this.consultantController,
    required this.mainContractorController,
    required this.subcontractorController,
    required this.otherContractorController,
    required this.validationErrors,
    required this.creatorRole,
    required this.creatorAuthUserId,
    required this.teamDirectory,
    required this.onConsultantChanged,
    required this.onMainContractorChanged,
    required this.onAddSubcontractor,
    required this.onAddOtherContractor,
    required this.onRemoveParty,
    required this.onAddInitialMember,
    required this.onRemoveInitialMember,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final TextEditingController consultantController;
  final TextEditingController mainContractorController;
  final TextEditingController subcontractorController;
  final TextEditingController otherContractorController;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final YorksV1Role creatorRole;
  final String creatorAuthUserId;
  final AsyncValue<List<YorksV1ProjectTeamDirectoryMember>> teamDirectory;
  final ValueChanged<String> onConsultantChanged;
  final ValueChanged<String> onMainContractorChanged;
  final VoidCallback onAddSubcontractor;
  final VoidCallback onAddOtherContractor;
  final ValueChanged<int> onRemoveParty;
  final void Function(
    YorksV1ProjectTeamDirectoryMember member,
    YorksV1ProjectMembershipRole projectRole,
  )
  onAddInitialMember;
  final ValueChanged<int> onRemoveInitialMember;

  @override
  Widget build(BuildContext context) {
    final subcontractors = <_IndexedParty>[
      for (var index = 0; index < draft.parties.length; index++)
        if (draft.parties[index].kind == YorksV1ProjectPartyKind.subcontractor)
          _IndexedParty(index, draft.parties[index]),
    ];
    final otherContractors = <_IndexedParty>[
      for (var index = 0; index < draft.parties.length; index++)
        if (draft.parties[index].kind ==
            YorksV1ProjectPartyKind.otherContractor)
          _IndexedParty(index, draft.parties[index]),
    ];
    final hasPartyError =
        validationErrors.contains(
          YorksV1ProjectValidationCode.invalidProjectParty,
        ) ||
        validationErrors.contains(
          YorksV1ProjectValidationCode.duplicateProjectParty,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusSectionCard(
          title: YorksV1ProjectStrings.partiesAndAccess.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final fields = [
                    LedgerTextField(
                      key: const ValueKey('yorks-v1-project-consultant'),
                      controller: consultantController,
                      label: YorksV1ProjectStrings.consultant.active(language),
                      hintText: YorksV1ProjectStrings.consultant.active(
                        language,
                      ),
                      onChanged: onConsultantChanged,
                    ),
                    LedgerTextField(
                      key: const ValueKey('yorks-v1-project-main-contractor'),
                      controller: mainContractorController,
                      label: YorksV1ProjectStrings.mainContractor.active(
                        language,
                      ),
                      hintText: YorksV1ProjectStrings.mainContractor.active(
                        language,
                      ),
                      onChanged: onMainContractorChanged,
                    ),
                  ];
                  if (!wide) return Column(children: _withGaps(fields));
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      for (final field in fields)
                        SizedBox(
                          width: (constraints.maxWidth - AppSpacing.lg) / 2,
                          child: field,
                        ),
                    ],
                  );
                },
              ),
              if (hasPartyError) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  YorksV1ProjectStrings.stageNeedsAttention.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _NamedPartyAdder(
                key: const ValueKey('yorks-v1-project-subcontractors'),
                label: YorksV1ProjectStrings.subcontractors,
                language: language,
                controller: subcontractorController,
                entries: subcontractors,
                onAdd: onAddSubcontractor,
                onRemove: onRemoveParty,
              ),
              const SizedBox(height: AppSpacing.lg),
              _NamedPartyAdder(
                key: const ValueKey('yorks-v1-project-other-contractors'),
                label: YorksV1ProjectStrings.otherContractors,
                language: language,
                controller: otherContractorController,
                entries: otherContractors,
                onAdd: onAddOtherContractor,
                onRemove: onRemoveParty,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: YorksV1ProjectStrings.projectTeam.primary,
          description: YorksV1ProjectStrings.accessDescription.primary,
          child: _InitialTeamAccessEditor(
            draft: draft,
            language: language,
            creatorRole: creatorRole,
            creatorAuthUserId: creatorAuthUserId,
            teamDirectory: teamDirectory,
            onAddMember: onAddInitialMember,
            onRemoveMember: onRemoveInitialMember,
          ),
        ),
      ],
    );
  }
}

class _InitialTeamAccessEditor extends StatelessWidget {
  const _InitialTeamAccessEditor({
    required this.draft,
    required this.language,
    required this.creatorRole,
    required this.creatorAuthUserId,
    required this.teamDirectory,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final YorksV1Role creatorRole;
  final String creatorAuthUserId;
  final AsyncValue<List<YorksV1ProjectTeamDirectoryMember>> teamDirectory;
  final void Function(
    YorksV1ProjectTeamDirectoryMember member,
    YorksV1ProjectMembershipRole projectRole,
  )
  onAddMember;
  final ValueChanged<int> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return teamDirectory.when(
      loading: () => Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _LocalizedCopy(
              copy: YorksV1ProjectStrings.loadingTeamDirectory,
              language: language,
              englishStyle: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
      error: (_, _) => _TeamDirectoryUnavailable(
        draft: draft,
        language: language,
        onRemoveMember: onRemoveMember,
      ),
      data: (members) {
        final memberByAuthUserId = {
          for (final member in members) member.authUserId: member,
        };
        final selectedAuthUserIds = draft.initialMembers
            .map((member) => member.authUserId)
            .toSet();
        final availableMembers = members
            .where(
              (member) =>
                  member.authUserId != creatorAuthUserId &&
                  !selectedAuthUserIds.contains(member.authUserId),
            )
            .toList(growable: false);
        final initialProjectEngineerCount = draft.initialMembers
            .where(
              (member) =>
                  member.projectRole ==
                  YorksV1ProjectMembershipRole.projectEngineer,
            )
            .length;
        final siteCreator = creatorRole == YorksV1Role.siteEngineer;
        final projectEngineerChoices = siteCreator
            ? availableMembers
                  .where(
                    (member) =>
                        initialProjectEngineerCount == 0 &&
                        member.eligibleRole == YorksV1Role.projectEngineer,
                  )
                  .toList(growable: false)
            : availableMembers;
        final siteEngineerChoices = siteCreator
            ? const <YorksV1ProjectTeamDirectoryMember>[]
            : availableMembers;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LocalizedCopy(
              copy: YorksV1ProjectStrings.initialProjectEngineerHint,
              language: language,
              englishStyle: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _InitialTeamRolePicker(
              projectRole: YorksV1ProjectMembershipRole.projectEngineer,
              label: YorksV1ProjectStrings.projectEngineers,
              selectLabel: YorksV1ProjectStrings.selectProjectEngineer,
              language: language,
              choices: projectEngineerChoices,
              selectedCount: selectedAuthUserIds.length,
              onAdd: (member) => onAddMember(
                member,
                YorksV1ProjectMembershipRole.projectEngineer,
              ),
            ),
            if (!siteCreator) ...[
              const SizedBox(height: AppSpacing.lg),
              _InitialTeamRolePicker(
                projectRole: YorksV1ProjectMembershipRole.siteEngineer,
                label: YorksV1ProjectStrings.siteEngineers,
                selectLabel: YorksV1ProjectStrings.selectSiteEngineer,
                language: language,
                choices: siteEngineerChoices,
                selectedCount: selectedAuthUserIds.length,
                onAdd: (member) => onAddMember(
                  member,
                  YorksV1ProjectMembershipRole.siteEngineer,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _InitialTeamMemberChips(
              initialMembers: draft.initialMembers,
              memberByAuthUserId: memberByAuthUserId,
              language: language,
              onRemove: onRemoveMember,
            ),
          ],
        );
      },
    );
  }
}

class _InitialTeamRolePicker extends StatelessWidget {
  const _InitialTeamRolePicker({
    required this.projectRole,
    required this.label,
    required this.selectLabel,
    required this.language,
    required this.choices,
    required this.selectedCount,
    required this.onAdd,
  });

  final YorksV1ProjectMembershipRole projectRole;
  final TranslatableString label;
  final TranslatableString selectLabel;
  final AppLanguage language;
  final List<YorksV1ProjectTeamDirectoryMember> choices;
  final int selectedCount;
  final ValueChanged<YorksV1ProjectTeamDirectoryMember> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocalizedCopy(
          copy: label,
          language: language,
          englishStyle: AppTypography.titleSmall,
          secondaryStyle: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'yorks-v1-project-team-picker-${projectRole.name}-$selectedCount',
          ),
          isExpanded: true,
          decoration: InputDecoration(labelText: selectLabel.active(language)),
          hint: Text(selectLabel.active(language)),
          items: [
            for (final member in choices)
              DropdownMenuItem(
                value: member.authUserId,
                child: Text(
                  _safeMemberDisplayName(member),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: choices.isEmpty
              ? null
              : (authUserId) {
                  if (authUserId == null) return;
                  for (final member in choices) {
                    if (member.authUserId == authUserId) {
                      onAdd(member);
                      return;
                    }
                  }
                },
        ),
        if (choices.isEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _LocalizedCopy(
            copy: YorksV1ProjectStrings.noEligibleTeamMembers,
            language: language,
            englishStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _InitialTeamMemberChips extends StatelessWidget {
  const _InitialTeamMemberChips({
    required this.initialMembers,
    required this.memberByAuthUserId,
    required this.language,
    required this.onRemove,
  });

  final List<YorksV1InitialProjectMemberInput> initialMembers;
  final Map<String, YorksV1ProjectTeamDirectoryMember> memberByAuthUserId;
  final AppLanguage language;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (initialMembers.isEmpty) {
      return _LocalizedCopy(
        copy: YorksV1ProjectStrings.accessDescription,
        language: language,
        englishStyle: AppTypography.bodyMedium,
      );
    }
    final hasUnavailableMember = initialMembers.any(
      (member) => !memberByAuthUserId.containsKey(member.authUserId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasUnavailableMember) ...[
          _LocalizedCopy(
            copy: YorksV1ProjectStrings.teamMemberNoLongerAvailable,
            language: language,
            englishStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < initialMembers.length; index++)
              InputChip(
                label: Text(
                  _safeMemberDisplayName(
                    memberByAuthUserId[initialMembers[index].authUserId],
                  ),
                ),
                avatar: Icon(
                  initialMembers[index].projectRole ==
                          YorksV1ProjectMembershipRole.projectEngineer
                      ? Icons.engineering_outlined
                      : Icons.badge_outlined,
                  size: 18,
                ),
                onDeleted: onRemove == null ? null : () => onRemove!(index),
              ),
          ],
        ),
      ],
    );
  }
}

class _TeamDirectoryUnavailable extends StatelessWidget {
  const _TeamDirectoryUnavailable({
    required this.draft,
    required this.language,
    required this.onRemoveMember,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final ValueChanged<int> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocalizedCopy(
          copy: YorksV1ProjectStrings.teamDirectoryUnavailable,
          language: language,
          englishStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.error,
          ),
        ),
        if (draft.initialMembers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _InitialTeamMemberChips(
            initialMembers: draft.initialMembers,
            memberByAuthUserId: const {},
            language: language,
            onRemove: onRemoveMember,
          ),
        ],
      ],
    );
  }
}

class _NamedPartyAdder extends StatelessWidget {
  const _NamedPartyAdder({
    super.key,
    required this.label,
    required this.language,
    required this.controller,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final TranslatableString label;
  final AppLanguage language;
  final TextEditingController controller;
  final List<_IndexedParty> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocalizedCopy(
          copy: label,
          language: language,
          englishStyle: AppTypography.titleSmall,
          secondaryStyle: AppTypography.labelSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LedgerTextField(
                controller: controller,
                label: label.active(language),
                hintText: label.active(language),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: SecondaryButton(
                label: YorksV1ProjectStrings.add.primary,
                onPressed: onAdd,
                isExpanded: false,
                icon: Icons.add,
              ),
            ),
          ],
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final entry in entries)
                InputChip(
                  label: Text(entry.party.name),
                  onDeleted: () => onRemove(entry.index),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BuildingsStage extends StatelessWidget {
  const _BuildingsStage({
    required this.draft,
    required this.language,
    required this.codeController,
    required this.nameController,
    required this.floorsController,
    required this.deliveryAddressController,
    required this.hasFrpRoom,
    required this.validationErrors,
    required this.onHasFrpRoomChanged,
    required this.onAddBuilding,
    required this.onRemoveBuilding,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController floorsController;
  final TextEditingController deliveryAddressController;
  final bool hasFrpRoom;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final ValueChanged<bool> onHasFrpRoomChanged;
  final VoidCallback onAddBuilding;
  final ValueChanged<int> onRemoveBuilding;

  @override
  Widget build(BuildContext context) {
    final buildingError =
        validationErrors.contains(
          YorksV1ProjectValidationCode.missingBuilding,
        ) ||
        validationErrors.contains(
          YorksV1ProjectValidationCode.invalidBuilding,
        ) ||
        validationErrors.contains(
          YorksV1ProjectValidationCode.duplicateBuildingCode,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusSectionCard(
          title: YorksV1ProjectStrings.buildings.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.blueContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.blueContainerStrong),
                ),
                child: _LocalizedCopy(
                  copy: YorksV1ProjectStrings.commonScopeDescription,
                  language: language,
                  englishStyle: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final fields = [
                    LedgerTextField(
                      key: const ValueKey('yorks-v1-building-code'),
                      controller: codeController,
                      label: YorksV1ProjectStrings.buildingCode.active(
                        language,
                      ),
                      hintText: YorksV1ProjectStrings.buildingCode.active(
                        language,
                      ),
                    ),
                    LedgerTextField(
                      key: const ValueKey('yorks-v1-building-name'),
                      controller: nameController,
                      label: YorksV1ProjectStrings.buildingName.active(
                        language,
                      ),
                      hintText: YorksV1ProjectStrings.buildingName.active(
                        language,
                      ),
                    ),
                  ];
                  if (!wide) return Column(children: _withGaps(fields));
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      for (final field in fields)
                        SizedBox(
                          width: (constraints.maxWidth - AppSpacing.lg) / 2,
                          child: field,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerTextField(
                key: const ValueKey('yorks-v1-building-floors'),
                controller: floorsController,
                label: YorksV1ProjectStrings.floorsOrLevels.active(language),
                hintText: YorksV1ProjectStrings.floorsOrLevels.active(language),
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerTextField(
                key: const ValueKey('yorks-v1-building-delivery-address'),
                controller: deliveryAddressController,
                label: YorksV1ProjectStrings.deliveryAddress.active(language),
                hintText: YorksV1ProjectStrings.deliveryAddress.active(
                  language,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: hasFrpRoom,
                onChanged: (value) => onHasFrpRoomChanged(value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: _LocalizedCopy(
                  copy: YorksV1ProjectStrings.hasFrpRoom,
                  language: language,
                  englishStyle: AppTypography.titleSmall,
                  secondaryStyle: AppTypography.labelSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: YorksV1ProjectStrings.addBuilding.primary,
                onPressed: onAddBuilding,
                icon: Icons.add_business_outlined,
              ),
              if (buildingError) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  validationErrors.contains(
                        YorksV1ProjectValidationCode.duplicateBuildingCode,
                      )
                      ? YorksV1ProjectStrings.duplicateBuildingCode.primary
                      : YorksV1ProjectStrings.atLeastOneBuilding.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: YorksV1ProjectStrings.commonScope.primary,
          child: draft.buildings.isEmpty
              ? _LocalizedCopy(
                  copy: YorksV1ProjectStrings.noBuildingsAdded,
                  language: language,
                  englishStyle: AppTypography.bodyMedium,
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < draft.buildings.length;
                      index++
                    ) ...[
                      _BuildingSummary(
                        building: draft.buildings[index],
                        language: language,
                        onRemove: () => onRemoveBuilding(index),
                      ),
                      if (index != draft.buildings.length - 1)
                        const Divider(height: AppSpacing.xxl),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _BuildingSummary extends StatelessWidget {
  const _BuildingSummary({
    required this.building,
    required this.language,
    required this.onRemove,
  });

  final YorksV1ProjectBuildingInput building;
  final AppLanguage language;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.apartment_outlined, color: AppColors.navy),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(building.name, style: AppTypography.titleMedium),
              if (building.code.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(building.normalizedCode, style: AppTypography.bodySmall),
              ],
              if (building.floorsOrLevels.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  building.floorsOrLevels.join(', '),
                  style: AppTypography.bodySmall,
                ),
              ],
              if (_emptyToNull(building.deliveryAddress) != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(building.deliveryAddress!, style: AppTypography.bodySmall),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: YorksV1ProjectStrings.remove.primary,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _AttachmentsStage extends StatelessWidget {
  const _AttachmentsStage({
    required this.draft,
    required this.language,
    required this.nameController,
    required this.mimeTypeController,
    required this.sizeBytesController,
    required this.validationErrors,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final TextEditingController nameController;
  final TextEditingController mimeTypeController;
  final TextEditingController sizeBytesController;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final VoidCallback onAddAttachment;
  final ValueChanged<int> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return NexusSectionCard(
      title: YorksV1ProjectStrings.attachments.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LocalizedCopy(
            copy: YorksV1ProjectStrings.attachmentsOptionalDescription,
            language: language,
            englishStyle: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          LedgerTextField(
            key: const ValueKey('yorks-v1-attachment-file-name'),
            controller: nameController,
            label: YorksV1ProjectStrings.attachmentFileName.active(language),
            hintText: YorksV1ProjectStrings.attachmentFileName.active(language),
          ),
          const SizedBox(height: AppSpacing.lg),
          LedgerTextField(
            key: const ValueKey('yorks-v1-attachment-mime-type'),
            controller: mimeTypeController,
            label: YorksV1ProjectStrings.attachmentType.active(language),
            hintText: YorksV1ProjectStrings.attachmentType.active(language),
          ),
          const SizedBox(height: AppSpacing.lg),
          LedgerTextField(
            key: const ValueKey('yorks-v1-attachment-size-bytes'),
            controller: sizeBytesController,
            label: YorksV1ProjectStrings.attachmentSize.active(language),
            hintText: YorksV1ProjectStrings.attachmentSize.active(language),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: YorksV1ProjectStrings.addAttachment.primary,
            onPressed: onAddAttachment,
            icon: Icons.attach_file,
          ),
          if (validationErrors.contains(
            YorksV1ProjectValidationCode.invalidAttachment,
          )) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              YorksV1ProjectStrings.stageNeedsAttention.primary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (draft.attachments.isEmpty)
            _LocalizedCopy(
              copy: YorksV1ProjectStrings.noAttachmentsAdded,
              language: language,
              englishStyle: AppTypography.bodyMedium,
            )
          else
            Column(
              children: [
                for (
                  var index = 0;
                  index < draft.attachments.length;
                  index++
                ) ...[
                  _AttachmentSummary(
                    attachment: draft.attachments[index],
                    onRemove: () => onRemoveAttachment(index),
                  ),
                  if (index != draft.attachments.length - 1)
                    const Divider(height: AppSpacing.xxl),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AttachmentSummary extends StatelessWidget {
  const _AttachmentSummary({required this.attachment, required this.onRemove});

  final YorksV1ProjectAttachmentInput attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.description_outlined, color: AppColors.navy),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attachment.fileName, style: AppTypography.titleMedium),
              if (attachment.mimeType?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(attachment.mimeType!, style: AppTypography.bodySmall),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: YorksV1ProjectStrings.remove.primary,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _ReviewStage extends StatelessWidget {
  const _ReviewStage({
    required this.draft,
    required this.language,
    required this.validationErrors,
    required this.teamDirectory,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final AsyncValue<List<YorksV1ProjectTeamDirectoryMember>> teamDirectory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusSectionCard(
          title: YorksV1ProjectStrings.reviewBeforeCreate.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocalizedCopy(
                copy: YorksV1ProjectStrings.connectedCreationDescription,
                language: language,
                englishStyle: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ReviewValue(
                label: YorksV1ProjectStrings.yorksReference,
                value: draft.reference,
                language: language,
              ),
              const SizedBox(height: AppSpacing.md),
              _ReviewValue(
                label: YorksV1ProjectStrings.projectName,
                value: draft.name,
                language: language,
              ),
              if (_emptyToNull(draft.clientName) != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ReviewValue(
                  label: YorksV1ProjectStrings.client,
                  value: draft.clientName!,
                  language: language,
                ),
              ],
              if (_emptyToNull(draft.siteLocation) != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ReviewValue(
                  label: YorksV1ProjectStrings.siteLocation,
                  value: draft.siteLocation!,
                  language: language,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: YorksV1ProjectStrings.buildings.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocalizedCopy(
                copy: YorksV1ProjectStrings.commonScopeDescription,
                language: language,
                englishStyle: AppTypography.bodyMedium,
              ),
              if (draft.buildings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final building in draft.buildings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(building.name, style: AppTypography.bodyMedium),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: YorksV1ProjectStrings.partiesAndAccess.primary,
          child: _ReviewPartiesAndAccess(
            draft: draft,
            language: language,
            teamDirectory: teamDirectory,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NexusSectionCard(
          title: YorksV1ProjectStrings.attachments.primary,
          child: draft.attachments.isEmpty
              ? _LocalizedCopy(
                  copy: YorksV1ProjectStrings.noAttachmentsAdded,
                  language: language,
                  englishStyle: AppTypography.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final attachment in draft.attachments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          attachment.fileName,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                  ],
                ),
        ),
        if (validationErrors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _ValidationBanner(language: language),
        ],
      ],
    );
  }
}

class _ReviewPartiesAndAccess extends StatelessWidget {
  const _ReviewPartiesAndAccess({
    required this.draft,
    required this.language,
    required this.teamDirectory,
  });

  final YorksV1ProjectCreationDraft draft;
  final AppLanguage language;
  final AsyncValue<List<YorksV1ProjectTeamDirectoryMember>> teamDirectory;

  @override
  Widget build(BuildContext context) {
    final namedParties = draft.parties
        .where((party) => party.name.trim().isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (namedParties.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final party in namedParties) Chip(label: Text(party.name)),
            ],
          ),
        if (draft.initialMembers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          teamDirectory.when(
            loading: () => _LocalizedCopy(
              copy: YorksV1ProjectStrings.loadingTeamDirectory,
              language: language,
              englishStyle: AppTypography.bodyMedium,
            ),
            error: (_, _) => _InitialTeamMemberChips(
              initialMembers: draft.initialMembers,
              memberByAuthUserId: const {},
              language: language,
              onRemove: null,
            ),
            data: (members) => _InitialTeamMemberChips(
              initialMembers: draft.initialMembers,
              memberByAuthUserId: {
                for (final member in members) member.authUserId: member,
              },
              language: language,
              onRemove: null,
            ),
          ),
        ],
        if (namedParties.isEmpty && draft.initialMembers.isEmpty)
          _LocalizedCopy(
            copy: YorksV1ProjectStrings.accessDescription,
            language: language,
            englishStyle: AppTypography.bodyMedium,
          ),
      ],
    );
  }
}

class _ReviewValue extends StatelessWidget {
  const _ReviewValue({
    required this.label,
    required this.value,
    required this.language,
  });

  final TranslatableString label;
  final String value;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: _LocalizedCopy(
            copy: label,
            language: language,
            englishStyle: AppTypography.labelLarge,
            secondaryStyle: AppTypography.labelSmall,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(value, style: AppTypography.bodyMedium)),
      ],
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: _LocalizedCopy(
        copy: YorksV1ProjectStrings.stageNeedsAttention,
        language: language,
        englishStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onErrorContainer,
        ),
      ),
    );
  }
}

class _StageActions extends StatelessWidget {
  const _StageActions({
    required this.stage,
    required this.language,
    required this.saving,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
    required this.onCreate,
  });

  final YorksV1ProjectCreationStage stage;
  final AppLanguage language;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isReview = stage == YorksV1ProjectCreationStage.reviewAndCreate;
    final isAttachments = stage == YorksV1ProjectCreationStage.attachments;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth <= AppSpacing.compactBreakpoint;
        final back = SecondaryButton(
          label: YorksV1ProjectStrings.back.primary,
          onPressed: saving ? null : onBack,
          icon: Icons.arrow_back,
          isExpanded: stacked,
        );
        final primary = PrimaryButton(
          key: ValueKey('yorks-v1-project-${isReview ? 'create' : 'continue'}'),
          label: isReview
              ? YorksV1ProjectStrings.createAndView.primary
              : YorksV1ProjectStrings.next.primary,
          onPressed: saving ? null : (isReview ? onCreate : onContinue),
          icon: isReview ? Icons.add_business_outlined : Icons.arrow_forward,
          isTrailingIcon: true,
          isLoading: saving,
          isExpanded: stacked,
        );
        final skip = SecondaryButton(
          label: YorksV1ProjectStrings.skipForNow.primary,
          onPressed: saving ? null : onSkip,
          isExpanded: stacked,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (isAttachments) ...[
                const SizedBox(height: AppSpacing.sm),
                skip,
              ],
              const SizedBox(height: AppSpacing.sm),
              back,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: back),
            const SizedBox(width: AppSpacing.sm),
            if (isAttachments) ...[
              Expanded(child: skip),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(flex: 2, child: primary),
          ],
        );
      },
    );
  }
}

class _LocalizedCopy extends StatelessWidget {
  const _LocalizedCopy({
    required this.copy,
    required this.language,
    this.englishStyle,
    this.secondaryStyle,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle? englishStyle;
  final TextStyle? secondaryStyle;

  @override
  Widget build(BuildContext context) {
    return YorksV1ActiveText(
      copy: copy,
      language: language,
      style: englishStyle ?? secondaryStyle,
    );
  }
}

class _IndexedParty {
  const _IndexedParty(this.index, this.party);

  final int index;
  final YorksV1ProjectPartyInput party;
}

YorksV1ProjectPartyInput? _partyFor(
  YorksV1ProjectCreationDraft draft,
  YorksV1ProjectPartyKind kind,
) {
  for (final party in draft.parties) {
    if (party.kind == kind) return party;
  }
  return null;
}

TranslatableString _stageCopy(YorksV1ProjectCreationStage stage) {
  return switch (stage) {
    YorksV1ProjectCreationStage.projectDetails =>
      YorksV1ProjectStrings.projectDetails,
    YorksV1ProjectCreationStage.partiesAndAccess =>
      YorksV1ProjectStrings.partiesAndAccess,
    YorksV1ProjectCreationStage.buildings => YorksV1ProjectStrings.buildings,
    YorksV1ProjectCreationStage.attachments =>
      YorksV1ProjectStrings.attachments,
    YorksV1ProjectCreationStage.reviewAndCreate =>
      YorksV1ProjectStrings.reviewAndCreate,
  };
}

String? _emptyToNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

bool _hasUnavailableInitialMember(
  YorksV1ProjectCreationDraft draft,
  List<YorksV1ProjectTeamDirectoryMember> directory,
) {
  final activeAuthUserIds = {for (final member in directory) member.authUserId};
  return draft.initialMembers.any(
    (member) => !activeAuthUserIds.contains(member.authUserId),
  );
}

String _safeMemberDisplayName(YorksV1ProjectTeamDirectoryMember? member) {
  if (member == null ||
      member.displayName.trim().isEmpty ||
      member.displayName.trim() == member.authUserId.trim() ||
      YorksV1ProjectTeamDirectoryMember.isEmailLikeDisplayName(
        member.displayName,
      )) {
    return YorksV1ProjectStrings.profileId.primary;
  }
  return member.displayName;
}

List<Widget> _withGaps(List<Widget> children) {
  return [
    for (var index = 0; index < children.length; index++) ...[
      children[index],
      if (index != children.length - 1) const SizedBox(height: AppSpacing.lg),
    ],
  ];
}
