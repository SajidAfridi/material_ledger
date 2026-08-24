import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/yorks_app_toast.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_configuration.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_configuration_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../configuration/yorks_v1_configuration_strings.dart';

class YorksV1ConfigurationScreen extends ConsumerStatefulWidget {
  const YorksV1ConfigurationScreen({super.key});

  @override
  ConsumerState<YorksV1ConfigurationScreen> createState() =>
      _YorksV1ConfigurationScreenState();
}

class _YorksV1ConfigurationScreenState
    extends ConsumerState<YorksV1ConfigurationScreen> {
  YorksV1ConfigurationArea _selected = YorksV1ConfigurationArea.overview;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  AppLanguage get _language => ref.read(languageProvider);

  String _t(String key) => YorksV1ConfigurationStrings.text(_language, key);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    if (role != YorksV1Role.admin) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: _EmptyMessage(
            icon: Icons.lock_outline_rounded,
            title: _t('admin_only'),
          ),
        ),
      );
    }

    final asyncConfiguration = ref.watch(yorksV1ConfigurationCentreProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: asyncConfiguration.when(
        loading: () => Center(
          child: _EmptyMessage(
            icon: Icons.tune_rounded,
            title: _t('loading'),
            loading: true,
          ),
        ),
        error: (error, _) => Center(
          child: _EmptyMessage(
            icon: Icons.cloud_off_outlined,
            title: _errorText(error),
            actionLabel: _t('retry'),
            onAction: () => ref.invalidate(yorksV1ConfigurationCentreProvider),
          ),
        ),
        data: (configuration) => _buildLoaded(context, configuration),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    YorksV1ConfigurationCentre configuration,
  ) {
    final busy = ref.watch(yorksV1ConfigurationCommandProvider).isLoading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= AppSpacing.compactBreakpoint;
        final desktop = constraints.maxWidth >= 1100;
        final padding = compact
            ? const EdgeInsets.fromLTRB(14, 16, 14, 96)
            : const EdgeInsets.fromLTRB(30, 26, 30, 88);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(yorksV1ConfigurationCentreProvider);
            await ref.read(yorksV1ConfigurationCentreProvider.future);
          },
          child: ListView(
            key: const Key('configuration-scroll-view'),
            padding: padding,
            children: [
              _ConfigurationHeader(
                compact: compact,
                title: _t('title'),
                subtitle: _t('subtitle'),
                validateLabel: _t('validate'),
                reviewLabel: _t('review_publish'),
                busy: busy,
                canReview: configuration.hasDraft,
                onValidate: _showValidation,
                onReview: () => _showPublishReview(configuration),
              ),
              const Gap(18),
              _SafetyRow(
                compact: compact,
                items: [
                  _SafetyItem(
                    icon: Icons.edit_note_rounded,
                    eyebrow: _t('draft_first'),
                    title: _t('draft_first_title'),
                    body: _t('draft_first_body'),
                  ),
                  _SafetyItem(
                    icon: Icons.shield_outlined,
                    eyebrow: _t('protected_workflow'),
                    title: _t('protected_workflow_title'),
                    body: _t('protected_workflow_body'),
                  ),
                  _SafetyItem(
                    icon: Icons.history_rounded,
                    eyebrow: _t('historical_safety'),
                    title: _t('historical_safety_title'),
                    body: _t('historical_safety_body'),
                  ),
                ],
              ),
              const Gap(18),
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 250,
                      child: _ConfigurationAreaNav(
                        selected: _selected,
                        language: _language,
                        query: _query,
                        searchController: _searchController,
                        horizontal: false,
                        onQueryChanged: _changeQuery,
                        onSelected: _selectArea,
                      ),
                    ),
                    const Gap(18),
                    Expanded(
                      child: _buildWorkspace(configuration, compact: compact),
                    ),
                  ],
                )
              else ...[
                _ConfigurationAreaNav(
                  selected: _selected,
                  language: _language,
                  query: _query,
                  searchController: _searchController,
                  horizontal: true,
                  onQueryChanged: _changeQuery,
                  onSelected: _selectArea,
                ),
                const Gap(14),
                _buildWorkspace(configuration, compact: compact),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspace(
    YorksV1ConfigurationCentre configuration, {
    required bool compact,
  }) {
    if (_query.trim().isNotEmpty) {
      return _SearchResults(
        query: _query,
        language: _language,
        onOpen: _selectArea,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DraftToolbar(
          configuration: configuration,
          language: _language,
          compact: compact,
          onDiscard: configuration.hasDraft
              ? () => _confirmDiscard(configuration)
              : null,
          onRestore: () => _confirmRestoreDefaults(configuration),
          onValidate: _showValidation,
          onReview: configuration.hasDraft
              ? () => _showPublishReview(configuration)
              : null,
        ),
        const Gap(14),
        switch (_selected) {
          YorksV1ConfigurationArea.overview => _buildOverview(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.companyRegional => _buildCompany(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.projectsTeams => _buildProjects(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.boqMaterials => _buildBoqMaterials(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.materialRequests => _buildMaterialRequests(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.procurementInventory => _buildProcurement(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.accounts => _buildAccounts(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.documentsPrinting => _buildDocuments(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.notifications => _buildNotifications(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.securityAudit => _buildSecurity(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.numberingData => _buildNumbering(
            configuration,
            compact,
          ),
          YorksV1ConfigurationArea.history => _buildHistory(
            configuration,
            compact,
          ),
        },
      ],
    );
  }

  void _changeQuery(String value) {
    if (_searchController.text != value) {
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() => _query = value);
  }

  void _selectArea(YorksV1ConfigurationArea area) {
    _searchController.clear();
    setState(() {
      _selected = area;
      _query = '';
    });
  }

  Widget _buildOverview(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    final validation = configuration.validation;
    final activeTemplateCount = configuration.boqTemplates
        .where((template) => template.isActive)
        .length;
    final activeCategoryCount = configuration.categories
        .where((category) => category.isActive)
        .length;
    final activeUnitCount = configuration.units
        .where((unit) => unit.isActive)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          compact: compact,
          children: [
            _MetricCard(
              label: _t('draft_changes'),
              status: configuration.hasDraft ? _t('draft') : _t('published'),
              value: '${configuration.draftChangeCount}',
              detail: configuration.hasDraft
                  ? configuration.affectedAreas
                        .map(
                          (area) =>
                              YorksV1ConfigurationStrings.area(_language, area),
                        )
                        .join(' · ')
                  : _t('no_unpublished_changes'),
              tone: configuration.hasDraft
                  ? _MetricTone.warning
                  : _MetricTone.success,
            ),
            _MetricCard(
              label: _t('controlled_master_data'),
              status: _t('current'),
              value:
                  '${activeTemplateCount + activeCategoryCount + activeUnitCount}',
              detail: _t('controlled_master_summary')
                  .replaceAll('{templates}', '$activeTemplateCount')
                  .replaceAll('{categories}', '$activeCategoryCount')
                  .replaceAll('{units}', '$activeUnitCount'),
              tone: _MetricTone.blue,
            ),
            _MetricCard(
              label: _t('published_version'),
              status: _t('audited'),
              value: configuration.publishedLabel,
              detail:
                  '${configuration.publishedBy} · ${_formatDate(configuration.publishedAt)}',
              tone: _MetricTone.purple,
            ),
          ],
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.hub_outlined,
          title: _t('control_coverage'),
          subtitle: _t('control_coverage_help'),
          child: _ControlCoverageSummary(
            settings: configuration.settings,
            language: _language,
            draftUpdatedBy: configuration.draftUpdatedBy,
            draftUpdatedAt: configuration.draftUpdatedAt,
          ),
        ),
        const Gap(14),
        _ValidationCard(
          validation: validation,
          language: _language,
          onValidate: _showValidation,
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.verified_user_outlined,
          title: _t('protected_operational_rules'),
          subtitle: _t('protected_operational_rules_help'),
          child: Column(
            children: [
              _InfoRule(
                icon: Icons.visibility_outlined,
                title: _t('procurement_project_access'),
                body: _t('procurement_project_access_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.apartment_outlined,
                title: _t('building_specific_boq'),
                body: _t('building_specific_boq_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.approval_outlined,
                title: _t('engineering_approval_first'),
                body: _t('engineering_approval_first_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.straighten_outlined,
                title: _t('quantity_integrity'),
                body: _t('quantity_integrity_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.history_toggle_off_rounded,
                title: _t('append_only_audit'),
                body: _t('append_only_audit_body'),
                protected: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.history_rounded,
          title: _t('what_change_affects'),
          subtitle: _t('historical_safety_body'),
          child: _Notice(
            icon: Icons.inventory_2_outlined,
            title: _t('existing_records_unchanged'),
            body: _t('existing_records_body'),
            tone: _NoticeTone.blue,
          ),
        ),
        const Gap(14),
        _HistoryPreview(
          history: configuration.history.take(3).toList(),
          language: _language,
          onOpenAll: () =>
              setState(() => _selected = YorksV1ConfigurationArea.history),
        ),
      ],
    );
  }

  Widget _buildCompany(YorksV1ConfigurationCentre configuration, bool compact) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.business_outlined,
          title: _t('organisation_identity'),
          subtitle: _t('organisation_identity_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _textSetting(
                configuration,
                'company.legal_name',
                _t('legal_company_name'),
              ),
              _textSetting(
                configuration,
                'company.short_name',
                _t('short_application_name'),
              ),
              _textSetting(
                configuration,
                'company.arabic_name',
                _t('arabic_company_name'),
                textDirection: TextDirection.rtl,
              ),
              _textSetting(
                configuration,
                'company.workspace_name',
                _t('workspace_name'),
              ),
              _textSetting(configuration, 'regional.country', _t('country')),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.language_rounded,
          title: _t('regional_language'),
          subtitle: _t('regional_language_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _textSetting(configuration, 'regional.timezone', _t('timezone')),
              _textSetting(
                configuration,
                'regional.date_format',
                _t('date_format'),
              ),
              _textSetting(configuration, 'regional.currency', _t('currency')),
              _textSetting(
                configuration,
                'regional.primary_language',
                _t('primary_language'),
              ),
              _textSetting(
                configuration,
                'regional.secondary_language',
                _t('secondary_language'),
              ),
              _textSetting(
                configuration,
                'regional.financial_year_start',
                _t('financial_year_start'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjects(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    final roles = [
      [
        _t('project_engineer'),
        _t('allowed'),
        _t('assigned_projects'),
        _t('allowed'),
        _t('active_membership_required'),
      ],
      [
        _t('senior_mechanical_engineer'),
        _t('allowed'),
        _t('all_projects'),
        _t('allowed'),
        _t('organization_wide_pe'),
      ],
      [
        _t('project_manager'),
        _t('allowed'),
        _t('all_projects'),
        _t('allowed'),
        _t('organization_wide_pe'),
      ],
      [
        _t('workshop_in_charge'),
        _t('allowed'),
        _t('all_projects'),
        _t('allowed'),
        _t('organization_wide_pe'),
      ],
      [
        _t('document_controller'),
        _t('allowed'),
        _t('all_projects'),
        _t('allowed'),
        _t('organization_wide_pe'),
      ],
      [
        _t('site_engineer'),
        _t('allowed'),
        _t('assigned_projects'),
        _t('creation_only'),
        _t('may_create_submit_mr'),
      ],
      [_t('procurement'), _t('no'), _t('view_only'), _t('no'), _t('protected')],
      [
        _t('admin'),
        _t('allowed'),
        _t('all_projects'),
        _t('allowed'),
        _t('audited_override'),
      ],
    ];
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.account_tree_outlined,
          title: _t('project_creation'),
          subtitle: _t('project_creation_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('unique_york_reference'),
                body: _t('unique_york_reference_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('multiple_engineers'),
                body: _t('multiple_engineers_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('assigned_site_engineer_mr'),
                body: _t('assigned_site_engineer_mr_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('physical_building_required'),
                body: _t('physical_building_required_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('procurement_create_projects'),
                body: _t('procurement_create_projects_body'),
                value: false,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.groups_2_outlined,
          title: _t('roles_allowed'),
          subtitle: _t('procurement_view_only_help'),
          child: _DataMatrix(
            headers: [
              _t('role'),
              _t('create'),
              _t('edit'),
              _t('assign_team'),
              _t('protected_note'),
            ],
            rows: roles,
            minimumWidth: 780,
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.query_stats_outlined,
          title: _t('no_weighted_progress'),
          subtitle: _t('no_weighted_progress_body'),
          child: _Notice(
            icon: Icons.lock_outline_rounded,
            title: _t('protected_workflow'),
            body: _t('approved_v1_exception'),
            tone: _NoticeTone.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildBoqMaterials(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    final pendingCategoryArchiveIds = configuration.masterActions
        .where(
          (action) =>
              action.entityKind == 'material_category' &&
              action.actionKind == 'archive',
        )
        .map((action) => action.targetId)
        .toSet();
    final pendingUnitArchiveIds = configuration.masterActions
        .where(
          (action) =>
              action.entityKind == 'material_unit' &&
              action.actionKind == 'archive',
        )
        .map((action) => action.targetId)
        .toSet();
    final pendingCategories = configuration.masterActions
        .where(
          (action) =>
              action.entityKind == 'material_category' &&
              action.actionKind == 'create',
        )
        .map(
          (action) => YorksV1ConfigurationCategory(
            id: action.targetId,
            name: action.payload['name']?.toString() ?? '',
            parentCategoryId: action.payload['parent_category_id']?.toString(),
            isSystem: false,
            isActive: true,
            itemCount: 0,
          ),
        );
    final pendingUnits = configuration.masterActions
        .where(
          (action) =>
              action.entityKind == 'material_unit' &&
              action.actionKind == 'create',
        )
        .map(
          (action) => YorksV1ConfigurationUnit(
            id: action.targetId,
            name: action.payload['name']?.toString() ?? '',
            shortCode: action.payload['short_code']?.toString() ?? '',
            unitType: action.payload['unit_type']?.toString() ?? 'other',
            decimalPlaces:
                int.tryParse(action.payload['decimal_places'].toString()) ?? 0,
            isSystem: false,
            isActive: true,
          ),
        );
    final categories = [...configuration.categories, ...pendingCategories];
    final units = [...configuration.units, ...pendingUnits];
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.view_quilt_outlined,
          title: _t('boq_scope_rules'),
          subtitle: _t('boq_scope_rules_help'),
          child: Column(
            children: [
              _InfoRule(
                icon: Icons.dashboard_outlined,
                title: _t('overview_summary_only'),
                body: _t('overview_summary_only_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.hub_outlined,
                title: _t('common_independent'),
                body: _t('common_independent_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.apartment_outlined,
                title: _t('building_owns_boq'),
                body: _t('building_owns_boq_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.folder_copy_outlined,
                title: _t('default_folders'),
                body: _t('default_folders_body'),
                protected: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.category_outlined,
          title: _t('master_categories'),
          subtitle: _t('master_draft_help'),
          action: _SmallAction(
            icon: Icons.add_rounded,
            label: _t('add_category'),
            onPressed: () => _showAddCategory(configuration),
          ),
          child: _MasterRegister(
            compact: compact,
            rows: [
              for (final category in categories)
                _MasterRow(
                  title: category.name,
                  subtitle:
                      '${category.itemCount} ${_t('items')} · ${category.isSystem ? _t('system') : _t('custom')}',
                  active:
                      category.isActive &&
                      !pendingCategoryArchiveIds.contains(category.id),
                  pending:
                      pendingCategoryArchiveIds.contains(category.id) ||
                      pendingCategories.any(
                        (pending) => pending.id == category.id,
                      ),
                  canArchive:
                      category.isActive &&
                      !category.isSystem &&
                      !pendingCategoryArchiveIds.contains(category.id) &&
                      !pendingCategories.any(
                        (pending) => pending.id == category.id,
                      ),
                  onArchive: () => _showArchiveMaster(
                    configuration,
                    entityKind: 'material_category',
                    targetId: category.id,
                    name: category.name,
                  ),
                ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.straighten_outlined,
          title: _t('master_units'),
          subtitle: _t('units_active_help'),
          action: _SmallAction(
            icon: Icons.add_rounded,
            label: _t('add_unit'),
            onPressed: () => _showAddUnit(configuration),
          ),
          child: _MasterRegister(
            compact: compact,
            rows: [
              for (final unit in units)
                _MasterRow(
                  title: unit.shortCode,
                  subtitle:
                      '${unit.name} · ${_t('unit_${unit.unitType}')} · ${_t('decimal_places_value').replaceAll('{count}', '${unit.decimalPlaces}')}',
                  active:
                      unit.isActive && !pendingUnitArchiveIds.contains(unit.id),
                  pending:
                      pendingUnitArchiveIds.contains(unit.id) ||
                      pendingUnits.any((pending) => pending.id == unit.id),
                  canArchive:
                      unit.isActive &&
                      !unit.isSystem &&
                      !pendingUnitArchiveIds.contains(unit.id) &&
                      !pendingUnits.any((pending) => pending.id == unit.id),
                  onArchive: () => _showArchiveMaster(
                    configuration,
                    entityKind: 'material_unit',
                    targetId: unit.id,
                    name: unit.name,
                  ),
                ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.folder_copy_outlined,
          title: _t('default_boq_structure'),
          subtitle: _t('default_boq_structure_help'),
          child: _DataMatrix(
            headers: [_t('number'), _t('folder'), _t('default'), _t('action')],
            rows: [
              for (final template in configuration.boqTemplates)
                [
                  template.order.toString().padLeft(2, '0'),
                  template.name,
                  template.isFrozen ? _t('yes') : _t('no'),
                  _t('protected'),
                ],
            ],
            minimumWidth: 680,
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialRequests(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.route_outlined,
          title: _t('request_lifecycle'),
          subtitle: _t('request_lifecycle_path'),
          child: _LifecycleRail(
            labels: [
              _t('created'),
              _t('engineering_approval'),
              _t('arrangement'),
              _t('ready_delivery'),
              _t('dispatch'),
              _t('received'),
              _t('completed'),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.fact_check_outlined,
          title: _t('request_rules'),
          subtitle: _t('request_rules_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('engineering_before_procurement'),
                body: _t('engineering_before_procurement_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('editable_before_approval'),
                body: _t('editable_before_approval_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('comments_from_creation'),
                body: _t('comments_from_creation_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('private_drafts'),
                body: _t('private_drafts_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('inventory_search_items'),
                body: _t('inventory_search_items_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('site_photo_receipt'),
                body: _t('site_photo_receipt_body'),
                value: true,
              ),
              _switchSetting(
                configuration,
                'requests.allow_authorized_creator_self_approval',
                _t('authorized_creator_self_approval'),
                _t('authorized_creator_self_approval_body'),
                fallback: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.schedule_outlined,
          title: _t('request_timing'),
          subtitle: _t('timing_modes_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _selectSetting(
                configuration,
                'requests.default_timing',
                _t('default_timing'),
                values: const ['normal', 'urgent', 'scheduled'],
                fallback: 'normal',
              ),
              _switchSetting(
                configuration,
                'requests.urgent_enabled',
                _t('urgent'),
                _t('urgent_request_body'),
                fallback: true,
              ),
              _LockedValue(
                label: _t('scheduled'),
                value: _t('scheduled_requirement'),
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.view_column_outlined,
          title: _t('controlled_columns'),
          subtitle: _t('controlled_columns_help'),
          child: _DataMatrix(
            headers: [
              _t('field'),
              _t('required'),
              _t('source'),
              _t('protected'),
            ],
            rows: [
              [
                _t('item_description'),
                _t('yes'),
                _t('boq_inventory_custom'),
                '—',
              ],
              [_t('brand_origin'), _t('no'), _t('requester'), '—'],
              [_t('quantity'), _t('yes'), _t('requester'), _t('server_cap')],
              [_t('unit'), _t('yes'), _t('controlled_master'), '—'],
              [
                _t('unit_cost'),
                _t('capability'),
                _t('commercial_users'),
                _t('backend'),
              ],
              [
                _t('total_cost'),
                _t('calculated'),
                _t('server_derived'),
                _t('backend'),
              ],
            ],
            minimumWidth: 680,
          ),
        ),
      ],
    );
  }

  Widget _buildProcurement(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.inventory_2_outlined,
          title: _t('arrangement_policy'),
          subtitle: _t('arrangement_policy_help'),
          child: Column(
            children: [
              _readOnlySetting(
                configuration,
                'procurement.default_source',
                _t('default_source'),
                _t(
                  configuration.stringValue(
                    'procurement.default_source',
                    'warehouse',
                  ),
                ),
              ),
              const Gap(10),
              _switchSetting(
                configuration,
                'procurement.require_external_source_readiness',
                _t('external_source_readiness_required'),
                _t('external_source_readiness_required_body'),
              ),
              const Gap(10),
              _ProtectedToggle(
                title: _t('partial_allowed'),
                body: _t('partial_allowed_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('cannot_provide_allowed'),
                body: _t('cannot_provide_allowed_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('reservation_enforced'),
                body: _t('reservation_enforced_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('dispatch_reference_required'),
                body: _t('dispatch_reference_required_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('prevent_over_dispatch'),
                body: _t('prevent_over_dispatch_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('receipt_exception_tracking'),
                body: _t('receipt_exception_tracking_body'),
                value: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.warehouse_outlined,
          title: _t('sourcing'),
          subtitle: _t('sourcing_help'),
          child: Column(
            children: [
              _InfoRule(
                icon: Icons.inventory_outlined,
                title: _t('warehouse_reservation'),
                body: _t('warehouse_reservation_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.local_shipping_outlined,
                title: _t('external_source'),
                body: _t('external_source_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.rule_outlined,
                title: _t('arrangement_decisions'),
                body: _t('arrangement_decisions_body'),
                protected: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.verified_outlined,
          title: _t('dispatch_receipt_controls'),
          subtitle: _t('dispatch_controls_help'),
          child: _DataMatrix(
            headers: [_t('control'), _t('value'), _t('authority')],
            rows: [
              [
                _t('dispatch_quantity_cap'),
                _t('dispatch_quantity_formula'),
                _t('server_rpc'),
              ],
              [
                _t('warehouse_stock_cap'),
                _t('available_at_commit'),
                _t('server_rpc'),
              ],
              [
                _t('receipt_outcomes'),
                _t('receipt_outcome_values'),
                _t('engineer_review'),
              ],
              [
                _t('delivery_order'),
                _t('immutable_dispatch_revision'),
                _t('trusted_command'),
              ],
            ],
            minimumWidth: 650,
          ),
        ),
      ],
    );
  }

  Widget _buildAccounts(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.account_balance_wallet_outlined,
          title: _t('billing_baseline'),
          subtitle: _t('billing_baseline_help'),
          child: _controlledSetting(
            setting: _settingFor(
              configuration,
              'accounts.billing_stage_weights',
            ),
            child:
                _settingFor(
                  configuration,
                  'accounts.billing_stage_weights',
                ).isOperational
                ? _BillingWeightsEditor(
                    key: ValueKey(configuration.draftRevision),
                    values: configuration.numberMapValue(
                      'accounts.billing_stage_weights',
                    ),
                    labels: {
                      'design': _t('billing_design'),
                      'material_supply': _t('billing_material_supply'),
                      'installation': _t('billing_installation'),
                      'commissioning_handover': _t(
                        'billing_commissioning_handover',
                      ),
                      'energizing': _t('billing_energizing'),
                    },
                    busy: _isBusy,
                    saveLabel: _t('save_draft'),
                    totalLabel: _t('total'),
                    onSave: (value) => _stageSetting(
                      configuration,
                      'accounts.billing_stage_weights',
                      value,
                    ),
                  )
                : _LockedValue(
                    label: _t('billing_baseline'),
                    value: _configurationValueLabel(
                      configuration.value('accounts.billing_stage_weights'),
                    ),
                  ),
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.receipt_long_outlined,
          title: _t('client_invoice_pdc'),
          subtitle: _t('deferred_route_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _integerSetting(
                configuration,
                'accounts.payment_terms_days',
                _t('payment_terms'),
              ),
              _integerSetting(
                configuration,
                'accounts.pdc_reminder_days',
                _t('pdc_reminder'),
              ),
              _LockedValue(
                label: _t('currency'),
                value: configuration.stringValue(
                  'regional.currency',
                  _t('default_currency'),
                ),
              ),
            ],
          ),
        ),
        const Gap(14),
        _Notice(
          icon: Icons.info_outline_rounded,
          title: _t('certification_separate'),
          body: _t('certification_separate_body'),
          tone: _NoticeTone.blue,
        ),
      ],
    );
  }

  Widget _buildDocuments(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.description_outlined,
          title: _t('file_version_control'),
          subtitle: _t('file_controls_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('private_linked_files'),
                body: _t('private_linked_files_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('required_revisions'),
                body: _t('required_revisions_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('approved_version_locking'),
                body: _t('approved_version_locking_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('a4_pdf_consistency'),
                body: _t('a4_pdf_consistency_body'),
                value: true,
              ),
              _switchSetting(
                configuration,
                'documents.bilingual_header',
                _t('bilingual_header'),
                _t('bilingual_header_body'),
                fallback: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.policy_outlined,
          title: _t('file_policy'),
          subtitle: _t('file_policy_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _readOnlySetting(
                configuration,
                'documents.maximum_file_size_mb',
                _t('maximum_file_size'),
                configuration
                    .intValue('documents.maximum_file_size_mb', 20)
                    .toString(),
              ),
              _integerSetting(
                configuration,
                'documents.retention_years',
                _t('retention_years'),
              ),
              _readOnlySetting(
                configuration,
                'documents.allowed_formats',
                _t('allowed_formats'),
                configuration
                    .stringListValue('documents.allowed_formats', const [
                      'PDF',
                      'DOCX',
                      'XLSX',
                      'JPG',
                      'JPEG',
                      'PNG',
                    ])
                    .join(', '),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotifications(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.monitor_heart_outlined,
          title: _t('notification_delivery_health'),
          subtitle: _t('notification_delivery_health_help'),
          child: _NotificationDeliveryHealth(
            health: configuration.operationalHealth,
            language: _language,
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.notifications_active_outlined,
          title: _t('notification_channels'),
          subtitle: _t('notification_channels_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('in_app'),
                body: _t('in_app_body'),
                value: true,
              ),
              _switchSetting(
                configuration,
                'notifications.push_enabled',
                _t('push'),
                _t('push_body'),
                fallback: true,
              ),
              _switchSetting(
                configuration,
                'notifications.email_enabled',
                _t('email'),
                _t('email_body'),
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.rule_folder_outlined,
          title: _t('notification_rules'),
          subtitle: _t('notification_rules_help'),
          child: _DataMatrix(
            headers: [_t('event'), _t('recipient'), _t('channels')],
            rows: [
              [
                _t('mr_submitted'),
                _t('assigned_project_engineer'),
                _t('in_app_push'),
              ],
              [
                _t('engineering_approval_event'),
                _t('procurement'),
                _t('in_app_push'),
              ],
              [
                _t('arrangement_saved'),
                _t('requester_site_engineer'),
                _t('in_app_push'),
              ],
              [
                _t('materials_dispatched'),
                _t('requester_site_engineer'),
                _t('in_app_push'),
              ],
              [
                _t('receipt_exception'),
                _t('procurement_project_engineer'),
                _t('in_app_push'),
              ],
              [_t('return_submitted'), _t('procurement'), _t('in_app_push')],
            ],
            minimumWidth: 680,
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.filter_alt_outlined,
          title: _t('noise_control'),
          subtitle: _t('noise_control_help'),
          child: Column(
            children: [
              _InfoRule(
                icon: Icons.person_off_outlined,
                title: _t('no_self_loops'),
                body: _t('no_self_loops_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.alternate_email_rounded,
                title: _t('mentions_notify'),
                body: _t('mentions_notify_body'),
                protected: true,
              ),
              _InfoRule(
                icon: Icons.priority_high_rounded,
                title: _t('critical_reminders'),
                body: _t('critical_reminders_body'),
                protected: true,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.lock_outline_rounded,
          title: _t('authentication_policy'),
          subtitle: _t('authentication_policy_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _integerSetting(
                configuration,
                'security.session_timeout_hours',
                _t('session_timeout'),
              ),
              _integerSetting(
                configuration,
                'security.minimum_password_length',
                _t('minimum_password'),
              ),
              _switchSetting(
                configuration,
                'security.admin_mfa_required',
                _t('admin_mfa'),
                _t('admin_mfa_body'),
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.security_outlined,
          title: _t('protected_security'),
          subtitle: _t('protected_security_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('deny_inactive_users'),
                body: _t('deny_inactive_users_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('append_only_audit'),
                body: _t('append_only_audit_security_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('commercial_enforcement'),
                body: _t('commercial_enforcement_body'),
                value: true,
              ),
              _switchSetting(
                configuration,
                'security.log_exports',
                _t('log_exports'),
                _t('log_exports_body'),
                fallback: true,
              ),
              _switchSetting(
                configuration,
                'security.log_access_changes',
                _t('log_access_changes'),
                _t('log_access_changes_body'),
                fallback: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.history_toggle_off_rounded,
          title: _t('audit_retention'),
          subtitle: _t('audit_retention_help'),
          child: _integerSetting(
            configuration,
            'security.audit_retention_years',
            _t('audit_retention'),
          ),
        ),
      ],
    );
  }

  Widget _buildNumbering(
    YorksV1ConfigurationCentre configuration,
    bool compact,
  ) {
    return Column(
      children: [
        _ConfigCard(
          icon: Icons.tag_rounded,
          title: _t('controlled_numbering'),
          subtitle: _t('controlled_numbering_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _readOnlySetting(
                configuration,
                'numbering.project_pattern',
                _t('project_pattern'),
                configuration.stringValue(
                  'numbering.project_pattern',
                  'Admin-controlled unique reference',
                ),
              ),
              _readOnlySetting(
                configuration,
                'numbering.material_request_pattern',
                _t('mr_pattern'),
                configuration.stringValue(
                  'numbering.material_request_pattern',
                  '{PROJECT_REF}-MR{NNN}',
                ),
              ),
              _readOnlySetting(
                configuration,
                'numbering.dispatch_pattern',
                _t('dispatch_pattern'),
                configuration.stringValue(
                  'numbering.dispatch_pattern',
                  '{PROJECT_REF}-DSP{NNN}',
                ),
              ),
              _LockedValue(
                label: _t('delivery_order'),
                value: _t('delivery_order_reference'),
              ),
              _readOnlySetting(
                configuration,
                'numbering.return_pattern',
                _t('return_pattern'),
                configuration.stringValue(
                  'numbering.return_pattern',
                  '{PROJECT_REF}-RTN{NNN}',
                ),
              ),
              _LockedValue(label: _t('invoice_pattern'), value: _t('deferred')),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.storage_outlined,
          title: _t('data_safety'),
          subtitle: _t('data_safety_help'),
          child: Column(
            children: [
              _ProtectedToggle(
                title: _t('preserve_issued_references'),
                body: _t('preserve_issued_references_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('no_fuzzy_backfills'),
                body: _t('no_fuzzy_backfills_body'),
                value: true,
              ),
              _ProtectedToggle(
                title: _t('controlled_schema_versioning'),
                body: _t('controlled_schema_versioning_body'),
                value: true,
                last: true,
              ),
            ],
          ),
        ),
        const Gap(14),
        _ConfigCard(
          icon: Icons.dns_outlined,
          title: _t('environment_information'),
          subtitle: _t('environment_information_help'),
          child: _FieldGrid(
            compact: compact,
            children: [
              _LockedValue(
                label: _t('environment'),
                value: configuration.environment,
              ),
              _LockedValue(
                label: _t('configuration_schema'),
                value: configuration.schemaVersion,
              ),
              _LockedValue(
                label: _t('published_version'),
                value: configuration.publishedLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(YorksV1ConfigurationCentre configuration, bool compact) {
    return _ConfigCard(
      icon: Icons.history_rounded,
      title: _t('version_history'),
      subtitle: _t('version_history_help'),
      child: configuration.history.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _t('no_history'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            )
          : compact
          ? Column(
              children: [
                for (final publication in configuration.history)
                  _HistoryMobileCard(
                    publication: publication,
                    language: _language,
                    onTap: () => _showPublicationDetail(publication.id),
                  ),
              ],
            )
          : _ConfigurationHistoryTable(
              publications: configuration.history,
              language: _language,
              onOpen: (publication) => _showPublicationDetail(publication.id),
            ),
    );
  }

  YorksV1ConfigurationSetting _settingFor(
    YorksV1ConfigurationCentre configuration,
    String key,
  ) {
    for (final setting in configuration.settings) {
      if (setting.key == key) return setting;
    }
    final value = configuration.value(key);
    return YorksV1ConfigurationSetting(
      key: key,
      area: YorksV1ConfigurationArea.overview,
      type: 'unknown',
      publishedValue: value,
      draftValue: null,
      effectiveValue: value,
      changed: false,
    );
  }

  Widget _controlledSetting({
    required YorksV1ConfigurationSetting setting,
    required Widget child,
  }) {
    return _ConfigurationSettingControl(
      setting: setting,
      language: _language,
      child: child,
    );
  }

  Widget _switchSetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    String title,
    String body, {
    bool fallback = false,
    bool last = false,
  }) {
    final setting = _settingFor(configuration, key);
    final value = configuration.boolValue(key, fallback);
    return _controlledSetting(
      setting: setting,
      child: setting.isOperational
          ? _SwitchSetting(
              title: title,
              body: body,
              value: value,
              busy: _isBusy,
              onChanged: (next) => _stageSetting(configuration, key, next),
              last: last,
            )
          : _ReadOnlySettingValue(
              title: title,
              body: body,
              value: _t(value ? 'enabled' : 'disabled'),
              mode: setting.controlMode,
            ),
    );
  }

  Widget _selectSetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    String label, {
    required List<String> values,
    required String fallback,
  }) {
    final setting = _settingFor(configuration, key);
    final value = configuration.stringValue(key, fallback);
    return _controlledSetting(
      setting: setting,
      child: setting.isOperational
          ? _SelectSetting(
              label: label,
              value: value,
              values: values,
              displayLabel: (option) => _t(option),
              busy: _isBusy,
              onChanged: (next) => _stageSetting(configuration, key, next),
            )
          : _LockedValue(label: label, value: _t(value)),
    );
  }

  Widget _readOnlySetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    String label,
    String value,
  ) {
    return _controlledSetting(
      setting: _settingFor(configuration, key),
      child: _LockedValue(label: label, value: value),
    );
  }

  Widget _textSetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    String label, {
    TextDirection? textDirection,
    bool listValue = false,
  }) {
    final rawValue = configuration.value(key);
    final value = listValue && rawValue is List
        ? rawValue.join(', ')
        : rawValue?.toString() ?? '';
    final setting = _settingFor(configuration, key);
    return _controlledSetting(
      setting: setting,
      child: setting.isOperational
          ? _EditableSetting(
              key: ValueKey('configuration-setting-$key-$value'),
              label: label,
              value: value,
              textDirection: textDirection,
              busy: _isBusy,
              saveLabel: _t('save_draft'),
              onSave: (next) => _stageSetting(
                configuration,
                key,
                listValue
                    ? next
                          .split(',')
                          .map((part) => part.trim().toUpperCase())
                          .where((part) => part.isNotEmpty)
                          .toList()
                    : next,
              ),
            )
          : _LockedValue(label: label, value: value),
    );
  }

  Widget _integerSetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    String label,
  ) {
    final value = configuration.intValue(key);
    final setting = _settingFor(configuration, key);
    return _controlledSetting(
      setting: setting,
      child: setting.isOperational
          ? _EditableSetting(
              key: ValueKey('configuration-setting-$key-$value'),
              label: label,
              value: '$value',
              keyboardType: TextInputType.number,
              busy: _isBusy,
              saveLabel: _t('save_draft'),
              onSave: (next) async {
                final number = int.tryParse(next.trim());
                if (number == null) {
                  if (mounted) {
                    YorksAppToast.show(
                      context,
                      title: _t('invalid_value'),
                      tone: YorksAppToastTone.error,
                      dismissible: true,
                    );
                  }
                  return false;
                }
                return _stageSetting(configuration, key, number);
              },
            )
          : _LockedValue(label: label, value: '$value'),
    );
  }

  bool get _isBusy => ref.read(yorksV1ConfigurationCommandProvider).isLoading;

  Future<bool> _stageSetting(
    YorksV1ConfigurationCentre configuration,
    String key,
    Object value,
  ) async {
    if (!_settingFor(configuration, key).isOperational) {
      if (mounted) {
        YorksAppToast.show(
          context,
          title: _t('control_read_only_error'),
          tone: YorksAppToastTone.information,
          dismissible: true,
          duration: const Duration(seconds: 4),
        );
      }
      return false;
    }
    final saved = await ref
        .read(yorksV1ConfigurationCommandProvider.notifier)
        .stageSetting(
          settingKey: key,
          value: value,
          expectedRevision: configuration.draftRevision,
        );
    if (!mounted) return saved;
    YorksAppToast.show(
      context,
      title: saved ? _t('draft_saved') : _commandErrorText(),
      tone: saved ? YorksAppToastTone.success : YorksAppToastTone.error,
      dismissible: true,
      duration: const Duration(seconds: 4),
    );
    return saved;
  }

  Future<void> _showAddCategory(
    YorksV1ConfigurationCentre configuration,
  ) async {
    final result = await showDialog<_CategoryInput>(
      context: context,
      builder: (context) => _AddCategoryDialog(
        language: _language,
        categories: configuration.categories
            .where((category) => category.isActive)
            .toList(),
      ),
    );
    if (result == null || !mounted) return;
    await _stageMasterAction(
      configuration,
      entityKind: 'material_category',
      actionKind: 'create',
      payload: {'name': result.name, 'parent_category_id': result.parentId},
    );
  }

  Future<void> _showAddUnit(YorksV1ConfigurationCentre configuration) async {
    final result = await showDialog<_UnitInput>(
      context: context,
      builder: (context) => _AddUnitDialog(language: _language),
    );
    if (result == null || !mounted) return;
    await _stageMasterAction(
      configuration,
      entityKind: 'material_unit',
      actionKind: 'create',
      payload: {
        'name': result.name,
        'short_code': result.shortCode,
        'unit_type': result.unitType,
        'decimal_places': result.decimalPlaces,
      },
    );
  }

  Future<void> _showArchiveMaster(
    YorksV1ConfigurationCentre configuration, {
    required String entityKind,
    required String targetId,
    required String name,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(
        language: _language,
        title: _t('archive_title'),
        body: '$name\n${_t('archive_history_notice')}',
        label: _t('archive_reason'),
        hint: _t('archive_reason_hint'),
        actionLabel: _t('archive'),
        minimumLength: 4,
        destructive: true,
      ),
    );
    if (reason == null || !mounted) return;
    await _stageMasterAction(
      configuration,
      entityKind: entityKind,
      actionKind: 'archive',
      targetId: targetId,
      payload: const {},
      reason: reason,
    );
  }

  Future<bool> _stageMasterAction(
    YorksV1ConfigurationCentre configuration, {
    required String entityKind,
    required String actionKind,
    String? targetId,
    required Map<String, Object?> payload,
    String? reason,
  }) async {
    final saved = await ref
        .read(yorksV1ConfigurationCommandProvider.notifier)
        .stageMasterAction(
          entityKind: entityKind,
          actionKind: actionKind,
          targetId: targetId,
          payload: payload,
          reason: reason,
          expectedRevision: configuration.draftRevision,
        );
    if (!mounted) return saved;
    YorksAppToast.show(
      context,
      title: saved ? _t('draft_saved') : _commandErrorText(),
      tone: saved ? YorksAppToastTone.success : YorksAppToastTone.error,
      dismissible: true,
      duration: const Duration(seconds: 4),
    );
    return saved;
  }

  Future<void> _showPublicationDetail(String publicationId) {
    return showDialog<void>(
      context: context,
      builder: (context) => _PublicationDetailDialog(
        publicationId: publicationId,
        language: _language,
      ),
    );
  }

  Future<void> _showValidation() async {
    final fresh = await _loadFreshConfiguration();
    if (fresh == null || !mounted) return;
    await _presentValidation(fresh.validation);
  }

  Future<void> _presentValidation(YorksV1ConfigurationValidation validation) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _ValidationDialog(validation: validation, language: _language),
    );
  }

  Future<void> _showPublishReview(
    YorksV1ConfigurationCentre configuration,
  ) async {
    final fresh = await _loadFreshConfiguration();
    if (fresh == null || !mounted) return;
    if (!fresh.validation.canPublish) {
      await _presentValidation(fresh.validation);
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (context) =>
          _PublishDialog(configuration: fresh, language: _language),
    );
    if (reason == null || !mounted) return;
    final version = await ref
        .read(yorksV1ConfigurationCommandProvider.notifier)
        .publish(reason: reason, expectedRevision: fresh.draftRevision);
    if (!mounted) return;
    YorksAppToast.show(
      context,
      title: version == null ? _commandErrorText() : _t('publish_success'),
      message: version,
      tone: version == null
          ? YorksAppToastTone.error
          : YorksAppToastTone.success,
      dismissible: true,
    );
  }

  Future<void> _confirmDiscard(YorksV1ConfigurationCentre configuration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: _t('discard_title'),
        body: _t('discard_body'),
        cancelLabel: _t('cancel'),
        confirmLabel: _t('discard'),
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted) return;
    final discarded = await ref
        .read(yorksV1ConfigurationCommandProvider.notifier)
        .discardDraft(configuration.draftRevision);
    if (!mounted) return;
    YorksAppToast.show(
      context,
      title: discarded ? _t('discarded') : _commandErrorText(),
      tone: discarded ? YorksAppToastTone.success : YorksAppToastTone.error,
      dismissible: true,
    );
  }

  Future<void> _confirmRestoreDefaults(
    YorksV1ConfigurationCentre configuration,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: _t('restore_title'),
        body: _t('restore_body'),
        cancelLabel: _t('cancel'),
        confirmLabel: _t('restore_defaults'),
        destructive: false,
      ),
    );
    if (confirmed != true || !mounted) return;
    final restored = await ref
        .read(yorksV1ConfigurationCommandProvider.notifier)
        .restoreDefaults(configuration.draftRevision);
    if (!mounted) return;
    YorksAppToast.show(
      context,
      title: restored ? _t('restored') : _commandErrorText(),
      tone: restored ? YorksAppToastTone.success : YorksAppToastTone.error,
      dismissible: true,
    );
  }

  String _errorText(Object error) {
    if (error is YorksV1DomainException) {
      return switch (error.code) {
        YorksV1DomainErrorCode.unauthorized => _t('admin_only'),
        YorksV1DomainErrorCode.offline => _t('online_required'),
        YorksV1DomainErrorCode.backendUnavailable => _t('service_unavailable'),
        _ => _t('load_failed'),
      };
    }
    return _t('load_failed');
  }

  String _commandErrorText() {
    final error = ref.read(yorksV1ConfigurationCommandProvider).error;
    if (error is! YorksV1DomainException) return _t('action_failed');
    return switch (error.code) {
      YorksV1DomainErrorCode.unauthorized => _t('admin_only'),
      YorksV1DomainErrorCode.offline => _t('online_required'),
      YorksV1DomainErrorCode.conflict => _t('draft_conflict'),
      YorksV1DomainErrorCode.invalidInput => _t('invalid_value'),
      YorksV1DomainErrorCode.invalidTransition => _t(
        'validation_blocked_action',
      ),
      YorksV1DomainErrorCode.backendUnavailable => _t('service_unavailable'),
      YorksV1DomainErrorCode.unexpectedResponse => _t(
        'unexpected_response_action',
      ),
      YorksV1DomainErrorCode.serverRejected => _t('server_rejected_action'),
      _ => _t('action_failed'),
    };
  }

  Future<YorksV1ConfigurationCentre?> _loadFreshConfiguration() async {
    try {
      final fresh = await ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .getConfigurationCentre();
      ref.invalidate(yorksV1ConfigurationCentreProvider);
      return fresh;
    } catch (error) {
      if (!mounted) return null;
      YorksAppToast.show(
        context,
        title: _errorText(error),
        tone: YorksAppToastTone.error,
        dismissible: true,
      );
      return null;
    }
  }

  String _formatDate(DateTime value) =>
      DateFormat('dd MMM yyyy, HH:mm').format(value);
}

class _ConfigurationHeader extends StatelessWidget {
  const _ConfigurationHeader({
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.validateLabel,
    required this.reviewLabel,
    required this.busy,
    required this.canReview,
    required this.onValidate,
    required this.onReview,
  });

  final bool compact;
  final String title;
  final String subtitle;
  final String validateLabel;
  final String reviewLabel;
  final bool busy;
  final bool canReview;
  final VoidCallback onValidate;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : onValidate,
          icon: const Icon(Icons.task_alt_rounded, size: 18),
          label: Text(validateLabel),
        ),
        FilledButton.icon(
          key: const Key('configuration-review-publish'),
          onPressed: busy || !canReview ? null : onReview,
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_outlined, size: 18),
          label: Text(reviewLabel),
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineLarge.copyWith(
            fontSize: compact ? 22 : 28,
            color: AppColors.ink,
            letterSpacing: -.5,
          ),
        ),
        const Gap(6),
        Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.muted,
            height: 1.45,
          ),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const Gap(14), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        const Gap(24),
        actions,
      ],
    );
  }
}

class _SafetyItem {
  const _SafetyItem({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({required this.compact, required this.items});

  final bool compact;
  final List<_SafetyItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = compact ? items.take(1) : items;
    return Row(
      children: [
        for (final (index, item) in visible.indexed) ...[
          if (index > 0) const Gap(12),
          Expanded(child: _SafetyCard(item: item)),
        ],
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.item});

  final _SafetyItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blueContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, color: AppColors.blue, size: 21),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.eyebrow.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.blue,
                    fontSize: 9,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(4),
                Text(
                  item.title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(3),
                Text(
                  item.body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationAreaNav extends StatelessWidget {
  const _ConfigurationAreaNav({
    required this.selected,
    required this.language,
    required this.query,
    required this.searchController,
    required this.horizontal,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final YorksV1ConfigurationArea selected;
  final AppLanguage language;
  final String query;
  final TextEditingController searchController;
  final bool horizontal;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<YorksV1ConfigurationArea> onSelected;

  static const _areas = YorksV1ConfigurationArea.values;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      key: const Key('configuration-search'),
      controller: searchController,
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        hintText: YorksV1ConfigurationStrings.text(language, 'search'),
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => onQueryChanged(''),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        isDense: true,
      ),
    );
    if (horizontal) {
      return _ConfigSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const Gap(10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final area in _areas) ...[
                    _AreaChip(
                      area: area,
                      selected: query.isEmpty && area == selected,
                      language: language,
                      onTap: () => onSelected(area),
                    ),
                    if (area != _areas.last) const Gap(7),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _ConfigSurface(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            YorksV1ConfigurationStrings.text(language, 'configuration_areas'),
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(4),
          Text(
            YorksV1ConfigurationStrings.text(
              language,
              'configuration_areas_help',
            ),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          const Gap(12),
          search,
          const Gap(10),
          for (final area in _areas)
            _AreaNavTile(
              area: area,
              selected: query.isEmpty && area == selected,
              language: language,
              onTap: () => onSelected(area),
            ),
        ],
      ),
    );
  }
}

IconData _areaIcon(YorksV1ConfigurationArea area) => switch (area) {
  YorksV1ConfigurationArea.overview => Icons.home_outlined,
  YorksV1ConfigurationArea.companyRegional => Icons.business_outlined,
  YorksV1ConfigurationArea.projectsTeams => Icons.groups_outlined,
  YorksV1ConfigurationArea.boqMaterials => Icons.view_quilt_outlined,
  YorksV1ConfigurationArea.materialRequests => Icons.assignment_outlined,
  YorksV1ConfigurationArea.procurementInventory => Icons.inventory_2_outlined,
  YorksV1ConfigurationArea.accounts => Icons.account_balance_wallet_outlined,
  YorksV1ConfigurationArea.documentsPrinting => Icons.description_outlined,
  YorksV1ConfigurationArea.notifications => Icons.notifications_none_rounded,
  YorksV1ConfigurationArea.securityAudit => Icons.security_outlined,
  YorksV1ConfigurationArea.numberingData => Icons.tag_rounded,
  YorksV1ConfigurationArea.history => Icons.history_rounded,
};

class _AreaNavTile extends StatelessWidget {
  const _AreaNavTile({
    required this.area,
    required this.selected,
    required this.language,
    required this.onTap,
  });

  final YorksV1ConfigurationArea area;
  final bool selected;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? AppColors.blueContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    _areaIcon(area),
                    size: 18,
                    color: selected ? AppColors.blue : AppColors.muted,
                  ),
                  const Gap(9),
                  Expanded(
                    child: Text(
                      YorksV1ConfigurationStrings.area(language, area),
                      style: AppTypography.labelMedium.copyWith(
                        color: selected
                            ? AppColors.navy
                            : AppColors.inkSecondary,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
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

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.area,
    required this.selected,
    required this.language,
    required this.onTap,
  });

  final YorksV1ConfigurationArea area;
  final bool selected;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _areaIcon(area),
                  size: 18,
                  color: selected ? Colors.white : AppColors.muted,
                ),
                const Gap(7),
                Text(
                  YorksV1ConfigurationStrings.area(language, area),
                  style: AppTypography.labelMedium.copyWith(
                    color: selected ? Colors.white : AppColors.inkSecondary,
                    fontWeight: FontWeight.w700,
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

class _DraftToolbar extends StatelessWidget {
  const _DraftToolbar({
    required this.configuration,
    required this.language,
    required this.compact,
    required this.onDiscard,
    required this.onRestore,
    required this.onValidate,
    required this.onReview,
  });

  final YorksV1ConfigurationCentre configuration;
  final AppLanguage language;
  final bool compact;
  final VoidCallback? onDiscard;
  final VoidCallback onRestore;
  final VoidCallback onValidate;
  final VoidCallback? onReview;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final status = configuration.validation.status;
    final tone = switch (status) {
      YorksV1ConfigurationValidationStatus.ready => AppColors.success,
      YorksV1ConfigurationValidationStatus.recommendations => AppColors.warning,
      YorksV1ConfigurationValidationStatus.blocked => AppColors.error,
    };
    final content = [
      _StatusPill(
        label: configuration.hasDraft
            ? '${configuration.draftChangeCount} ${_t('draft_changes').toLowerCase()}'
            : _t('published_configuration'),
        color: configuration.hasDraft ? AppColors.warning : AppColors.success,
      ),
      if (configuration.hasDraft &&
          configuration.draftUpdatedBy?.trim().isNotEmpty == true)
        _StatusPill(
          label: compact
              ? '${_t('draft')} · ${configuration.draftUpdatedBy!.trim()}'
              : _t('draft_last_updated')
                    .replaceAll('{actor}', configuration.draftUpdatedBy!.trim())
                    .replaceAll(
                      '{time}',
                      _configurationDateLabel(configuration.draftUpdatedAt),
                    ),
          color: AppColors.purple,
          icon: Icons.group_outlined,
          subtle: true,
        ),
      for (final area in configuration.affectedAreas)
        _StatusPill(
          label: YorksV1ConfigurationStrings.area(language, area),
          color: AppColors.blue,
          subtle: true,
        ),
      _StatusPill(
        label: _t(status.name),
        color: tone,
        icon: status == YorksV1ConfigurationValidationStatus.blocked
            ? Icons.error_outline_rounded
            : Icons.task_alt_rounded,
      ),
    ];
    final actions = Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        if (onDiscard != null)
          TextButton(onPressed: onDiscard, child: Text(_t('discard_draft'))),
        TextButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: Text(_t('restore_defaults')),
        ),
        OutlinedButton(onPressed: onValidate, child: Text(_t('validate'))),
        FilledButton(
          onPressed: onReview,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: Text(_t('review_publish')),
        ),
      ],
    );
    return _ConfigSurface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = compact || constraints.maxWidth < 1200;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 7, runSpacing: 7, children: content),
                const Gap(10),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Wrap(spacing: 7, runSpacing: 7, children: content),
              ),
              const Gap(12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.icon,
    this.subtle = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: subtle ? .07 : .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const Gap(5),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCoverageSummary extends StatelessWidget {
  const _ControlCoverageSummary({
    required this.settings,
    required this.language,
    required this.draftUpdatedBy,
    required this.draftUpdatedAt,
  });

  final List<YorksV1ConfigurationSetting> settings;
  final AppLanguage language;
  final String? draftUpdatedBy;
  final DateTime draftUpdatedAt;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final mode in YorksV1ConfigurationControlMode.values)
        mode: settings.where((setting) => setting.controlMode == mode).length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < AppSpacing.compactBreakpoint;
            final width = stacked
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md * 2) / 3;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final mode in YorksV1ConfigurationControlMode.values)
                  SizedBox(
                    width: width,
                    child: _ControlCoverageTile(
                      mode: mode,
                      count: counts[mode] ?? 0,
                      language: language,
                    ),
                  ),
              ],
            );
          },
        ),
        if (draftUpdatedBy?.trim().isNotEmpty == true) ...[
          const Gap(AppSpacing.md),
          Text(
            _t('draft_last_updated')
                .replaceAll('{actor}', draftUpdatedBy!.trim())
                .replaceAll('{time}', _configurationDateLabel(draftUpdatedAt)),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _NotificationDeliveryHealth extends StatelessWidget {
  const _NotificationDeliveryHealth({
    required this.health,
    required this.language,
  });

  final YorksV1ConfigurationOperationalHealth health;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final (:title, :body, :tone) = _deliveryState();
    final lastSuccessfulAt = health.lastSuccessfulDeliveryAt;
    final metrics = [
      _NotificationHealthMetricData(
        label: _t('active_devices'),
        value: '${health.activeDeviceCount}',
        icon: Icons.devices_outlined,
        color: health.activeDeviceCount > 0
            ? AppColors.success
            : AppColors.warning,
      ),
      _NotificationHealthMetricData(
        label: _t('pending_delivery'),
        value: '${health.pendingDeliveryCount}',
        icon: Icons.schedule_send_outlined,
        color: health.pendingDeliveryCount > 0
            ? AppColors.warning
            : AppColors.success,
      ),
      _NotificationHealthMetricData(
        label: _t('recent_delivery_failures'),
        value: '${health.recentFailureCount}',
        icon: Icons.error_outline_rounded,
        color: health.recentFailureCount > 0
            ? AppColors.error
            : AppColors.success,
      ),
      _NotificationHealthMetricData(
        label: _t('last_successful_delivery'),
        value: lastSuccessfulAt == null
            ? _t('no_successful_delivery')
            : _configurationDateLabel(lastSuccessfulAt),
        icon: Icons.task_alt_outlined,
        color: lastSuccessfulAt == null ? AppColors.muted : AppColors.blue,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: switch (tone) {
            _NoticeTone.success => Icons.cloud_done_outlined,
            _NoticeTone.error => Icons.cloud_off_outlined,
            _NoticeTone.warning => Icons.sync_problem_outlined,
            _NoticeTone.blue => Icons.info_outline_rounded,
          },
          title: title,
          body: body,
          tone: tone,
        ),
        const Gap(AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 430
                ? 1
                : constraints.maxWidth < 760
                ? 2
                : 4;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: _NotificationHealthMetric(data: metric),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  ({String title, String body, _NoticeTone tone}) _deliveryState() {
    if (!health.pushEnabled) {
      return (
        title: _t('push_delivery_disabled'),
        body: _t('push_delivery_disabled_help'),
        tone: _NoticeTone.blue,
      );
    }
    if (health.recentFailureCount > 0) {
      return (
        title: _t('push_delivery_failures'),
        body: _t('push_delivery_failures_help'),
        tone: _NoticeTone.error,
      );
    }
    if (health.activeDeviceCount == 0) {
      return (
        title: _t('no_active_devices'),
        body: _t('no_active_devices_help'),
        tone: _NoticeTone.warning,
      );
    }
    if (health.pendingDeliveryCount > 0) {
      return (
        title: _t('delivery_queue_pending'),
        body: _t('delivery_queue_pending_help'),
        tone: _NoticeTone.warning,
      );
    }
    return (
      title: _t('push_delivery_operational'),
      body: _t('push_delivery_operational_help'),
      tone: _NoticeTone.success,
    );
  }
}

class _NotificationHealthMetricData {
  const _NotificationHealthMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _NotificationHealthMetric extends StatelessWidget {
  const _NotificationHealthMetric({required this.data});

  final _NotificationHealthMetricData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${data.label}: ${data.value}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: data.color.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, size: 20, color: data.color),
              const Gap(AppSpacing.sm),
              Text(
                data.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(color: AppColors.ink),
              ),
              const Gap(AppSpacing.xs),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlCoverageTile extends StatelessWidget {
  const _ControlCoverageTile({
    required this.mode,
    required this.count,
    required this.language,
  });

  final YorksV1ConfigurationControlMode mode;
  final int count;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final presentation = _controlModePresentation(mode, language);
    return Semantics(
      container: true,
      label: '${presentation.label}. $count. ${presentation.help}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: presentation.color.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: presentation.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                presentation.icon,
                color: presentation.color,
                size: 20,
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    presentation.help,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.sm),
            Text(
              '$count',
              style: AppTypography.headlineSmall.copyWith(
                color: presentation.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationSettingControl extends StatelessWidget {
  const _ConfigurationSettingControl({
    required this.setting,
    required this.language,
    required this.child,
  });

  final YorksV1ConfigurationSetting setting;
  final AppLanguage language;
  final Widget child;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final presentation = _controlModePresentation(
      setting.controlMode,
      language,
    );
    final affectedAreas = setting.impactScope
        .map((area) => YorksV1ConfigurationStrings.area(language, area))
        .join(', ');
    final details = <String>[
      presentation.help,
      if (affectedAreas.isNotEmpty)
        _t('affects_areas').replaceAll('{areas}', affectedAreas),
      if (setting.enforcementTarget.trim().isNotEmpty)
        _t('enforced_by').replaceAll(
          '{target}',
          YorksV1ConfigurationStrings.enforcement(
            language,
            setting.enforcementTarget,
          ),
        ),
    ];
    final stagedActor = setting.stagedBy?.trim();
    final stagedAt = setting.stagedAt;
    return Semantics(
      container: true,
      readOnly: !setting.isOperational,
      label: '${presentation.label}. ${details.join(' ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusPill(
                label: presentation.label,
                color: presentation.color,
                icon: presentation.icon,
                subtle: true,
              ),
              if (setting.changed)
                _StatusPill(
                  label: _t('draft'),
                  color: AppColors.warning,
                  icon: Icons.edit_outlined,
                  subtle: true,
                ),
            ],
          ),
          const Gap(AppSpacing.sm),
          child,
          const Gap(AppSpacing.xs),
          Text(
            details.join(' · '),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          if (setting.changed && stagedActor?.isNotEmpty == true) ...[
            const Gap(AppSpacing.xs),
            Text(
              _t('staged_by')
                  .replaceAll('{actor}', stagedActor!)
                  .replaceAll(
                    '{time}',
                    stagedAt == null
                        ? _t('draft')
                        : _configurationDateLabel(stagedAt),
                  ),
              style: AppTypography.labelSmall.copyWith(color: AppColors.blue),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlySettingValue extends StatelessWidget {
  const _ReadOnlySettingValue({
    required this.title,
    required this.body,
    required this.value,
    required this.mode,
  });

  final String title;
  final String body;
  final String value;
  final YorksV1ConfigurationControlMode mode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      readOnly: true,
      label: '$title. $body. $value.',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      body,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.md),
              _StatusPill(
                label: value,
                color: mode == YorksV1ConfigurationControlMode.protected
                    ? AppColors.blue
                    : AppColors.warning,
                icon: mode == YorksV1ConfigurationControlMode.protected
                    ? Icons.lock_outline_rounded
                    : Icons.schedule_outlined,
                subtle: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({String label, String help, Color color, IconData icon})
_controlModePresentation(
  YorksV1ConfigurationControlMode mode,
  AppLanguage language,
) {
  final key = switch (mode) {
    YorksV1ConfigurationControlMode.operational => 'operational',
    YorksV1ConfigurationControlMode.protected => 'protected_control',
    YorksV1ConfigurationControlMode.planned => 'planned',
  };
  final helpKey = switch (mode) {
    YorksV1ConfigurationControlMode.operational => 'operational_help',
    YorksV1ConfigurationControlMode.protected => 'protected_control_help',
    YorksV1ConfigurationControlMode.planned => 'planned_help',
  };
  final color = switch (mode) {
    YorksV1ConfigurationControlMode.operational => AppColors.success,
    YorksV1ConfigurationControlMode.protected => AppColors.blue,
    YorksV1ConfigurationControlMode.planned => AppColors.warning,
  };
  final icon = switch (mode) {
    YorksV1ConfigurationControlMode.operational => Icons.bolt_rounded,
    YorksV1ConfigurationControlMode.protected => Icons.lock_outline_rounded,
    YorksV1ConfigurationControlMode.planned => Icons.schedule_outlined,
  };
  return (
    label: YorksV1ConfigurationStrings.text(language, key),
    help: YorksV1ConfigurationStrings.text(language, helpKey),
    color: color,
    icon: icon,
  );
}

String _configurationDateLabel(DateTime value) =>
    DateFormat('dd MMM yyyy, HH:mm').format(value);

String _humanizeConfigurationToken(String value) => value
    .trim()
    .split(RegExp(r'[_\-.]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _configurationValueLabel(Object? value) {
  if (value == null) return '—';
  if (value is List) {
    return value.map(_configurationValueLabel).join(', ');
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return entries
        .map(
          (entry) =>
              '${_humanizeConfigurationToken(entry.key.toString())}: ${_configurationValueLabel(entry.value)}',
        )
        .join(' · ');
  }
  return value.toString();
}

String _localizedConfigurationValue(Object? value, AppLanguage language) {
  if (value is bool) {
    return YorksV1ConfigurationStrings.text(
      language,
      value ? 'enabled' : 'disabled',
    );
  }
  if (value is List) {
    return value
        .map((entry) => _localizedConfigurationValue(entry, language))
        .join(', ');
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return entries
        .map(
          (entry) =>
              '${_humanizeConfigurationToken(entry.key.toString())}: ${_localizedConfigurationValue(entry.value, language)}',
        )
        .join(' · ');
  }
  return _configurationValueLabel(value);
}

String _configurationSettingTitle(String settingKey, AppLanguage language) {
  const stringKeys = <String, String>{
    'company.legal_name': 'legal_company_name',
    'company.short_name': 'short_application_name',
    'company.arabic_name': 'arabic_company_name',
    'company.workspace_name': 'workspace_name',
    'regional.country': 'country',
    'regional.timezone': 'timezone',
    'regional.date_format': 'date_format',
    'regional.currency': 'currency',
    'regional.primary_language': 'primary_language',
    'regional.secondary_language': 'secondary_language',
    'regional.financial_year_start': 'financial_year_start',
    'requests.default_timing': 'default_timing',
    'requests.urgent_enabled': 'urgent',
    'requests.allow_authorized_creator_self_approval':
        'authorized_creator_self_approval',
    'procurement.default_source': 'default_source',
    'procurement.require_external_source_readiness':
        'external_source_readiness_required',
    'accounts.billing_stage_weights': 'billing_baseline',
    'accounts.payment_terms_days': 'payment_terms',
    'accounts.pdc_reminder_days': 'pdc_reminder',
    'documents.maximum_file_size_mb': 'maximum_file_size',
    'documents.retention_years': 'retention_years',
    'documents.allowed_formats': 'allowed_formats',
    'documents.bilingual_header': 'bilingual_header',
    'notifications.push_enabled': 'push',
    'notifications.email_enabled': 'email',
    'security.session_timeout_hours': 'session_timeout',
    'security.minimum_password_length': 'minimum_password',
    'security.admin_mfa_required': 'admin_mfa',
    'security.log_exports': 'log_exports',
    'security.log_access_changes': 'log_access_changes',
    'security.audit_retention_years': 'audit_retention',
    'numbering.project_pattern': 'project_pattern',
    'numbering.material_request_pattern': 'mr_pattern',
    'numbering.dispatch_pattern': 'dispatch_pattern',
    'numbering.return_pattern': 'return_pattern',
  };
  final key = stringKeys[settingKey];
  if (key == null) return _humanizeConfigurationToken(settingKey);
  return YorksV1ConfigurationStrings.text(language, key);
}

class _ConfigSurface extends StatelessWidget {
  const _ConfigSurface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _ConfigSurface(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackAction = action != null && constraints.maxWidth < 430;
          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blueContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.blue, size: 21),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null && !stackAction) ...[const Gap(10), action!],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
                child: stackAction
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const Gap(12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                        ],
                      )
                    : heading,
              ),
              const Divider(height: 1),
              Padding(padding: const EdgeInsets.all(16), child: child),
            ],
          );
        },
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.compact, required this.children});

  final bool compact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index != children.length - 1) const Gap(10),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[
          Expanded(child: child),
          if (index != children.length - 1) const Gap(10),
        ],
      ],
    );
  }
}

enum _MetricTone { success, warning, blue, purple }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.status,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String status;
  final String value;
  final String detail;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _MetricTone.success => AppColors.success,
      _MetricTone.warning => AppColors.warning,
      _MetricTone.blue => AppColors.blue,
      _MetricTone.purple => AppColors.purple,
    };
    return _ConfigSurface(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: .55,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: status, color: color),
            ],
          ),
          const Gap(10),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({
    required this.validation,
    required this.language,
    required this.onValidate,
  });

  final YorksV1ConfigurationValidation validation;
  final AppLanguage language;
  final VoidCallback onValidate;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final status = validation.status;
    final color = switch (status) {
      YorksV1ConfigurationValidationStatus.ready => AppColors.success,
      YorksV1ConfigurationValidationStatus.recommendations => AppColors.warning,
      YorksV1ConfigurationValidationStatus.blocked => AppColors.error,
    };
    return _ConfigCard(
      icon: Icons.task_alt_rounded,
      title: _t('configuration_validation'),
      subtitle: _t('validation_detail'),
      action: OutlinedButton(
        onPressed: onValidate,
        child: Text(_t('validate')),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              status == YorksV1ConfigurationValidationStatus.blocked
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == YorksV1ConfigurationValidationStatus.ready
                        ? _t('ready_to_publish')
                        : status == YorksV1ConfigurationValidationStatus.blocked
                        ? '${validation.blocking.length} ${_t('must_correct').toLowerCase()}'
                        : '${validation.recommendations.length} ${_t('recommendations').toLowerCase()}',
                    style: AppTypography.titleSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    status == YorksV1ConfigurationValidationStatus.ready
                        ? _t('ready_body')
                        : status == YorksV1ConfigurationValidationStatus.blocked
                        ? validation.blocking.first.message
                        : validation.recommendations.first.message,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRule extends ConsumerWidget {
  const _InfoRule({
    required this.icon,
    required this.title,
    required this.body,
    required this.protected,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool protected;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.blue),
          ),
          const Gap(11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (protected) ...[
            const Gap(10),
            _StatusPill(
              label: YorksV1ConfigurationStrings.text(
                language,
                'protected_label',
              ),
              color: AppColors.blue,
              icon: Icons.lock_outline_rounded,
              subtle: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProtectedToggle extends ConsumerWidget {
  const _ProtectedToggle({
    required this.title,
    required this.body,
    required this.value,
    this.last = false,
  });

  final String title;
  final String body;
  final bool value;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final status = YorksV1ConfigurationStrings.text(
      language,
      value ? 'enabled' : 'disabled',
    );
    final protectedLabel = YorksV1ConfigurationStrings.text(
      language,
      'protected_control',
    );
    return Semantics(
      container: true,
      readOnly: true,
      label: '$title. $body. $protectedLabel. $status.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Gap(7),
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      body,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              _StatusPill(
                label: status,
                color: value ? AppColors.blue : AppColors.muted,
                icon: Icons.lock_outline_rounded,
                subtle: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.body,
    required this.value,
    required this.busy,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String body;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Switch.adaptive(value: value, onChanged: busy ? null : onChanged),
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.compact, required this.children});

  final bool compact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index != children.length - 1) const Gap(12),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _EditableSetting extends StatefulWidget {
  const _EditableSetting({
    super.key,
    required this.label,
    required this.value,
    required this.busy,
    required this.saveLabel,
    required this.onSave,
    this.keyboardType,
    this.textDirection,
  });

  final String label;
  final String value;
  final bool busy;
  final String saveLabel;
  final Future<bool> Function(String value) onSave;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;

  @override
  State<_EditableSetting> createState() => _EditableSettingState();
}

class _EditableSettingState extends State<_EditableSetting> {
  late final TextEditingController _controller;
  bool _saving = false;

  bool get _changed => _controller.text.trim() != widget.value.trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value)
      ..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      textDirection: widget.textDirection,
      enabled: !widget.busy && !_saving,
      onSubmitted: _changed ? (_) => _save() : null,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: _changed
            ? IconButton(
                tooltip: widget.saveLabel,
                onPressed: widget.busy || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
              )
            : const Icon(Icons.cloud_done_outlined, size: 17),
      ),
    );
  }

  Future<void> _save() async {
    final next = _controller.text.trim();
    if (!_changed) return;
    setState(() => _saving = true);
    final saved = await widget.onSave(next);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) _controller.text = widget.value;
  }
}

class _SelectSetting extends StatelessWidget {
  const _SelectSetting({
    required this.label,
    required this.value,
    required this.values,
    required this.displayLabel,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final String Function(String) displayLabel;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in values)
          DropdownMenuItem(value: option, child: Text(displayLabel(option))),
      ],
      onChanged: busy
          ? null
          : (next) {
              if (next != null && next != value) onChanged(next);
            },
    );
  }
}

class _LockedValue extends StatelessWidget {
  const _LockedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 17,
          color: AppColors.blue,
        ),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _DataMatrix extends StatelessWidget {
  const _DataMatrix({
    required this.headers,
    required this.rows,
    required this.minimumWidth,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final double minimumWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minimumWidth),
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 66,
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceContainerLow,
              ),
              columnSpacing: 24,
              horizontalMargin: 14,
              columns: [
                for (final header in headers)
                  DataColumn(
                    label: Text(
                      header.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.muted,
                        fontSize: 9,
                        letterSpacing: .5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      for (var index = 0; index < headers.length; index++)
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: index == 0 ? 220 : 300,
                            ),
                            child: Text(
                              index < row.length ? row[index] : '',
                              style: AppTypography.bodySmall.copyWith(
                                color: index == 0
                                    ? AppColors.ink
                                    : AppColors.inkSecondary,
                                fontWeight: index == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _NoticeTone { blue, warning, error, success }

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (tone) {
      _NoticeTone.blue => (AppColors.blue, AppColors.blueContainer),
      _NoticeTone.warning => (AppColors.warning, AppColors.warningContainer),
      _NoticeTone.error => (AppColors.error, AppColors.errorContainer),
      _NoticeTone.success => (AppColors.success, AppColors.successContainer),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(3),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleRail extends StatelessWidget {
  const _LifecycleRail({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, label) in labels.indexed) ...[
            SizedBox(
              width: 96,
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const Gap(7),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.inkSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (index != labels.length - 1)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.only(bottom: 28),
                color: AppColors.success.withValues(alpha: .35),
              ),
          ],
        ],
      ),
    );
  }
}

class _BillingWeightsEditor extends StatefulWidget {
  const _BillingWeightsEditor({
    super.key,
    required this.values,
    required this.labels,
    required this.busy,
    required this.saveLabel,
    required this.totalLabel,
    required this.onSave,
  });

  final Map<String, num> values;
  final Map<String, String> labels;
  final bool busy;
  final String saveLabel;
  final String totalLabel;
  final Future<bool> Function(Map<String, int>) onSave;

  @override
  State<_BillingWeightsEditor> createState() => _BillingWeightsEditorState();
}

class _BillingWeightsEditorState extends State<_BillingWeightsEditor> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final entry in widget.labels.entries)
        entry.key: TextEditingController(
          text: '${widget.values[entry.key]?.toInt() ?? 0}',
        )..addListener(_refresh),
    };
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _total => _controllers.values.fold(
    0,
    (total, controller) => total + (int.tryParse(controller.text) ?? 0),
  );

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _total == 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 620;
            final width = narrow
                ? constraints.maxWidth
                : (constraints.maxWidth - 20) / 3;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in widget.labels.entries)
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _controllers[entry.key],
                      enabled: !widget.busy && !_saving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: entry.value,
                        suffixText: '%',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const Gap(12),
        Row(
          children: [
            _StatusPill(
              label: '${widget.totalLabel} $_total%',
              color: valid ? AppColors.success : AppColors.error,
              icon: valid ? Icons.check_rounded : Icons.error_outline_rounded,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: widget.busy || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(widget.saveLabel),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final values = {
      for (final entry in _controllers.entries)
        entry.key: int.tryParse(entry.value.text) ?? 0,
    };
    setState(() => _saving = true);
    await widget.onSave(values);
    if (mounted) setState(() => _saving = false);
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 11),
      ),
    );
  }
}

class _MasterRow {
  const _MasterRow({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.pending,
    required this.canArchive,
    required this.onArchive,
  });

  final String title;
  final String subtitle;
  final bool active;
  final bool pending;
  final bool canArchive;
  final VoidCallback onArchive;
}

class _MasterRegister extends ConsumerStatefulWidget {
  const _MasterRegister({required this.compact, required this.rows});

  final bool compact;
  final List<_MasterRow> rows;

  @override
  ConsumerState<_MasterRegister> createState() => _MasterRegisterState();
}

class _MasterRegisterState extends ConsumerState<_MasterRegister> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    String t(String key) => YorksV1ConfigurationStrings.text(language, key);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 380),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: widget.rows.length > 6,
        child: ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: widget.rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = widget.rows[index];
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: row.active
                            ? AppColors.successContainer
                            : AppColors.neutralContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        row.active
                            ? Icons.check_rounded
                            : Icons.archive_outlined,
                        size: 18,
                        color: row.active ? AppColors.success : AppColors.muted,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            row.pending
                                ? '${row.subtitle} · ${t('draft')}'
                                : row.subtitle,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    _StatusPill(
                      label: row.active ? t('active') : t('archived'),
                      color: row.active ? AppColors.success : AppColors.muted,
                    ),
                    if (row.canArchive) ...[
                      const Gap(5),
                      IconButton(
                        tooltip: t('archive_tooltip'),
                        onPressed: row.onArchive,
                        icon: const Icon(Icons.archive_outlined, size: 19),
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
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({
    required this.history,
    required this.language,
    required this.onOpenAll,
  });

  final List<YorksV1ConfigurationPublication> history;
  final AppLanguage language;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _ConfigCard(
      icon: Icons.history_rounded,
      title: YorksV1ConfigurationStrings.text(language, 'recent_activity'),
      subtitle: YorksV1ConfigurationStrings.text(language, 'activity_help'),
      action: TextButton(
        onPressed: onOpenAll,
        child: Text(
          YorksV1ConfigurationStrings.area(
            language,
            YorksV1ConfigurationArea.history,
          ),
        ),
      ),
      child: history.isEmpty
          ? Text(
              YorksV1ConfigurationStrings.text(language, 'no_history'),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            )
          : Column(
              children: [
                for (final (index, publication) in history.indexed)
                  _InfoRule(
                    icon: Icons.publish_outlined,
                    title:
                        '${YorksV1ConfigurationStrings.text(language, 'published_configuration')} ${publication.versionLabel}',
                    body:
                        '${publication.reason} · ${publication.publishedBy} · ${DateFormat('dd MMM, HH:mm').format(publication.publishedAt)}',
                    protected: false,
                    last: index == history.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _ConfigurationHistoryTable extends StatelessWidget {
  const _ConfigurationHistoryTable({
    required this.publications,
    required this.language,
    required this.onOpen,
  });

  final List<YorksV1ConfigurationPublication> publications;
  final AppLanguage language;
  final ValueChanged<YorksV1ConfigurationPublication> onOpen;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 920,
            child: Column(
              children: [
                Container(
                  color: AppColors.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _HistoryCell(text: _t('version'), flex: 1, heading: true),
                      _HistoryCell(
                        text: _t('published_at'),
                        flex: 2,
                        heading: true,
                      ),
                      _HistoryCell(
                        text: _t('published_by'),
                        flex: 2,
                        heading: true,
                      ),
                      _HistoryCell(text: _t('reason'), flex: 3, heading: true),
                      _HistoryCell(
                        text: _t('affected_areas'),
                        flex: 3,
                        heading: true,
                      ),
                      _HistoryCell(text: _t('changes'), flex: 1, heading: true),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                for (final (index, publication) in publications.indexed)
                  Semantics(
                    button: true,
                    label:
                        '${publication.versionLabel}. ${publication.reason}. ${_t('view_changes')}.',
                    child: Material(
                      color: AppColors.surfaceContainerLowest,
                      child: InkWell(
                        onTap: () => onOpen(publication),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: index == publications.length - 1
                              ? null
                              : const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.line),
                                  ),
                                ),
                          child: Row(
                            children: [
                              _HistoryCell(
                                text: publication.versionLabel,
                                flex: 1,
                                strong: true,
                              ),
                              _HistoryCell(
                                text: _configurationDateLabel(
                                  publication.publishedAt,
                                ),
                                flex: 2,
                              ),
                              _HistoryCell(
                                text: publication.publishedBy,
                                flex: 2,
                              ),
                              _HistoryCell(
                                text: publication.reason,
                                flex: 3,
                                strong: true,
                              ),
                              _HistoryCell(
                                text: publication.affectedAreas
                                    .map(
                                      (area) =>
                                          YorksV1ConfigurationStrings.area(
                                            language,
                                            area,
                                          ),
                                    )
                                    .join(', '),
                                flex: 3,
                              ),
                              _HistoryCell(
                                text: '${publication.changeCount}',
                                flex: 1,
                              ),
                              const SizedBox(
                                width: 32,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _HistoryCell extends StatelessWidget {
  const _HistoryCell({
    required this.text,
    required this.flex,
    this.heading = false,
    this.strong = false,
  });

  final String text;
  final int flex;
  final bool heading;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Text(
          text,
          maxLines: heading ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: heading
              ? AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                )
              : AppTypography.bodySmall.copyWith(
                  color: strong ? AppColors.ink : AppColors.inkSecondary,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                ),
        ),
      ),
    );
  }
}

class _HistoryMobileCard extends StatelessWidget {
  const _HistoryMobileCard({
    required this.publication,
    required this.language,
    required this.onTap,
  });

  final YorksV1ConfigurationPublication publication;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(
                      label: publication.versionLabel,
                      color: AppColors.purple,
                    ),
                    const Spacer(),
                    Text(
                      '${publication.changeCount} ${YorksV1ConfigurationStrings.text(language, 'changes').toLowerCase()}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ),
                const Gap(9),
                Text(
                  publication.reason,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(5),
                Text(
                  publication.affectedAreas
                      .map(
                        (area) =>
                            YorksV1ConfigurationStrings.area(language, area),
                      )
                      .join(' · '),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.blue,
                  ),
                ),
                const Gap(7),
                Text(
                  '${publication.publishedBy} · ${DateFormat('dd MMM yyyy, HH:mm').format(publication.publishedAt)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
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

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.language,
    required this.onOpen,
  });

  final String query;
  final AppLanguage language;
  final ValueChanged<YorksV1ConfigurationArea> onOpen;

  static const _terms = <YorksV1ConfigurationArea, List<String>>{
    YorksV1ConfigurationArea.companyRegional: [
      'company',
      'regional',
      'language',
      'currency',
      'timezone',
      'date',
      'workspace',
    ],
    YorksV1ConfigurationArea.projectsTeams: [
      'project',
      'team',
      'role',
      'engineer',
      'membership',
    ],
    YorksV1ConfigurationArea.boqMaterials: [
      'boq',
      'material',
      'category',
      'unit',
      'folder',
      'building',
    ],
    YorksV1ConfigurationArea.materialRequests: [
      'request',
      'approval',
      'timing',
      'urgent',
      'column',
    ],
    YorksV1ConfigurationArea.procurementInventory: [
      'procurement',
      'inventory',
      'warehouse',
      'dispatch',
      'supplier',
      'receipt',
    ],
    YorksV1ConfigurationArea.accounts: [
      'accounts',
      'billing',
      'invoice',
      'payment',
      'pdc',
    ],
    YorksV1ConfigurationArea.documentsPrinting: [
      'document',
      'printing',
      'pdf',
      'file',
      'retention',
      'format',
    ],
    YorksV1ConfigurationArea.notifications: [
      'notification',
      'push',
      'email',
      'alert',
      'mention',
    ],
    YorksV1ConfigurationArea.securityAudit: [
      'security',
      'audit',
      'password',
      'session',
      'mfa',
    ],
    YorksV1ConfigurationArea.numberingData: [
      'number',
      'pattern',
      'reference',
      'schema',
      'environment',
    ],
    YorksV1ConfigurationArea.history: [
      'history',
      'publication',
      'version',
      'reason',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = _terms.entries.where((entry) {
      final areaLabel = YorksV1ConfigurationStrings.area(
        language,
        entry.key,
      ).toLowerCase();
      return areaLabel.contains(normalized) ||
          entry.value.any((term) => term.contains(normalized));
    }).toList();
    return _ConfigCard(
      icon: Icons.search_rounded,
      title: YorksV1ConfigurationStrings.text(language, 'search_results'),
      subtitle: query,
      child: matches.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                YorksV1ConfigurationStrings.text(language, 'no_search_results'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            )
          : Column(
              children: [
                for (final (index, match) in matches.indexed)
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      minTileHeight: 54,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.blueContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _areaIcon(match.key),
                          color: AppColors.blue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        YorksV1ConfigurationStrings.area(language, match.key),
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        YorksV1ConfigurationStrings.text(
                          language,
                          'open_configuration_area',
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      shape: index == matches.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppColors.line),
                            ),
                      onTap: () => onOpen(match.key),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ValidationDialog extends StatelessWidget {
  const _ValidationDialog({required this.validation, required this.language});

  final YorksV1ConfigurationValidation validation;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final blocked = validation.blocking.isNotEmpty;
    final issues = blocked ? validation.blocking : validation.recommendations;
    return AlertDialog(
      key: const Key('configuration-validation-dialog'),
      title: Row(
        children: [
          Icon(
            blocked ? Icons.error_outline_rounded : Icons.task_alt_rounded,
            color: blocked ? AppColors.error : AppColors.success,
          ),
          const Gap(10),
          Expanded(child: Text(_t('configuration_validation'))),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Notice(
              icon: blocked
                  ? Icons.priority_high_rounded
                  : Icons.check_circle_outline_rounded,
              title: blocked
                  ? _t('must_correct')
                  : validation.recommendations.isEmpty
                  ? _t('ready_to_publish')
                  : _t('recommended_before_production'),
              body: blocked
                  ? _t(
                      'blocking_issue_count',
                    ).replaceAll('{count}', '${validation.blocking.length}')
                  : validation.recommendations.isEmpty
                  ? _t('ready_body')
                  : _t('recommendations_review'),
              tone: blocked
                  ? _NoticeTone.error
                  : validation.recommendations.isEmpty
                  ? _NoticeTone.success
                  : _NoticeTone.warning,
            ),
            if (issues.isNotEmpty) ...[
              const Gap(12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (index, issue) in issues.indexed)
                        _InfoRule(
                          icon: blocked
                              ? Icons.close_rounded
                              : Icons.lightbulb_outline_rounded,
                          title: YorksV1ConfigurationStrings.area(
                            language,
                            issue.area,
                          ),
                          body: YorksV1ConfigurationStrings.issue(
                            language,
                            issue.code,
                            issue.message,
                          ),
                          protected: false,
                          last: index == issues.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('close')),
        ),
      ],
    );
  }
}

class _PublicationDetailDialog extends ConsumerWidget {
  const _PublicationDetailDialog({
    required this.publicationId,
    required this.language,
  });

  final String publicationId;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      yorksV1ConfigurationPublicationDetailProvider(publicationId),
    );
    final height = (MediaQuery.sizeOf(context).height * .68)
        .clamp(300.0, 620.0)
        .toDouble();
    return AlertDialog(
      title: Text(_t('publication_details')),
      content: SizedBox(
        width: 680,
        height: height,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _EmptyMessage(
            icon: Icons.cloud_off_outlined,
            title: _t('service_unavailable'),
            actionLabel: _t('retry'),
            onAction: () => ref.invalidate(
              yorksV1ConfigurationPublicationDetailProvider(publicationId),
            ),
          ),
          data: (publicationDetail) {
            final publication = publicationDetail.publication;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Notice(
                  icon: Icons.verified_outlined,
                  title:
                      '${publication.versionLabel} · ${publication.publishedBy}',
                  body:
                      '${publication.reason}\n${_configurationDateLabel(publication.publishedAt)}',
                  tone: _NoticeTone.success,
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: publicationDetail.changes.isEmpty
                      ? Center(
                          child: Text(
                            _t('no_history'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: publicationDetail.changes.length,
                          separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
                          itemBuilder: (context, index) =>
                              _PublishedConfigurationChangeCard(
                                change: publicationDetail.changes[index],
                                language: language,
                              ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('close')),
        ),
      ],
    );
  }
}

class _PublishedConfigurationChangeCard extends StatelessWidget {
  const _PublishedConfigurationChangeCard({
    required this.change,
    required this.language,
  });

  final YorksV1ConfigurationPublicationChange change;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final settingKey = change.settingKey ?? change.changeKind;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _configurationSettingTitle(settingKey, language),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              _StatusPill(
                label: YorksV1ConfigurationStrings.area(language, change.area),
                color: AppColors.blue,
                subtle: true,
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final before = _ConfigurationDiffValue(
                label: _t('before'),
                value: _localizedConfigurationValue(
                  change.beforeValue,
                  language,
                ),
              );
              final after = _ConfigurationDiffValue(
                label: _t('after'),
                value: _localizedConfigurationValue(
                  change.afterValue,
                  language,
                ),
                emphasized: true,
              );
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [before, const Gap(AppSpacing.sm), after],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: before),
                  const Gap(AppSpacing.sm),
                  Expanded(child: after),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfigurationSettingDiffCard extends StatelessWidget {
  const _ConfigurationSettingDiffCard({
    required this.setting,
    required this.language,
  });

  final YorksV1ConfigurationSetting setting;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final presentation = _controlModePresentation(
      setting.controlMode,
      language,
    );
    final title = _configurationSettingTitle(setting.key, language);
    final stagedActor = setting.stagedBy?.trim();
    return Semantics(
      container: true,
      label:
          '$title. ${_t('published_value')}: ${_localizedConfigurationValue(setting.publishedValue, language)}. ${_t('draft_value')}: ${_localizedConfigurationValue(setting.draftValue, language)}.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        setting.key,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
                _StatusPill(
                  label: presentation.label,
                  color: presentation.color,
                  icon: presentation.icon,
                  subtle: true,
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            _ConfigurationDiffValue(
              label: _t('published_value'),
              value: _localizedConfigurationValue(
                setting.publishedValue,
                language,
              ),
            ),
            const Gap(AppSpacing.sm),
            _ConfigurationDiffValue(
              label: _t('draft_value'),
              value: _localizedConfigurationValue(setting.draftValue, language),
              emphasized: true,
            ),
            if (stagedActor?.isNotEmpty == true) ...[
              const Gap(AppSpacing.sm),
              Text(
                _t('staged_by')
                    .replaceAll('{actor}', stagedActor!)
                    .replaceAll(
                      '{time}',
                      setting.stagedAt == null
                          ? _t('draft')
                          : _configurationDateLabel(setting.stagedAt!),
                    ),
                style: AppTypography.labelSmall.copyWith(color: AppColors.blue),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfigurationMasterActionDiffCard extends StatelessWidget {
  const _ConfigurationMasterActionDiffCard({
    required this.action,
    required this.configuration,
    required this.language,
  });

  final YorksV1ConfigurationMasterAction action;
  final YorksV1ConfigurationCentre configuration;
  final AppLanguage language;

  String _t(String key) => YorksV1ConfigurationStrings.text(language, key);

  @override
  Widget build(BuildContext context) {
    final entityLabel = switch (action.entityKind) {
      'material_category' => _t('material_category'),
      'material_unit' => _t('material_unit'),
      _ => _humanizeConfigurationToken(action.entityKind),
    };
    final actionLabel = action.actionKind == 'archive'
        ? _t('archive')
        : _t('create');
    final targetName = _targetName();
    final details = <({String label, String value})>[
      if (action.payload['short_code']?.toString().trim().isNotEmpty == true)
        (
          label: _t('short_code'),
          value: action.payload['short_code']!.toString(),
        ),
      if (action.payload['unit_type']?.toString().trim().isNotEmpty == true)
        (
          label: _t('unit_type'),
          value: _t('unit_${action.payload['unit_type']}'),
        ),
      if (action.payload['decimal_places'] != null)
        (
          label: _t('decimal_places'),
          value: action.payload['decimal_places'].toString(),
        ),
      if (action.reason?.trim().isNotEmpty == true)
        (label: _t('action_reason'), value: action.reason!.trim()),
      if (targetName == action.targetId)
        (label: _t('target_reference'), value: action.targetId),
    ];
    final actionColor = action.actionKind == 'archive'
        ? AppColors.error
        : AppColors.success;
    return Semantics(
      container: true,
      label:
          '${_t('master_data_action')}. $entityLabel. $actionLabel. $targetName.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: actionColor.withValues(alpha: .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    action.entityKind == 'material_unit'
                        ? Icons.straighten_outlined
                        : Icons.category_outlined,
                    size: 19,
                    color: actionColor,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetName,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        entityLabel,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
                _StatusPill(
                  label: actionLabel,
                  color: actionColor,
                  icon: action.actionKind == 'archive'
                      ? Icons.archive_outlined
                      : Icons.add_rounded,
                  subtle: true,
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const Gap(AppSpacing.sm),
              for (var index = 0; index < details.length; index++) ...[
                if (index > 0) const Gap(AppSpacing.sm),
                _ConfigurationDiffValue(
                  label: details[index].label,
                  value: details[index].value,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _targetName() {
    final payloadName = action.payload['name']?.toString().trim();
    if (payloadName?.isNotEmpty == true) return payloadName!;
    if (action.entityKind == 'material_category') {
      for (final category in configuration.categories) {
        if (category.id == action.targetId) return category.name;
      }
    }
    if (action.entityKind == 'material_unit') {
      for (final unit in configuration.units) {
        if (unit.id == action.targetId) {
          return '${unit.name} (${unit.shortCode})';
        }
      }
    }
    return action.targetId;
  }
}

class _ConfigurationDiffValue extends StatelessWidget {
  const _ConfigurationDiffValue({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.blueContainer.withValues(alpha: .55)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: emphasized ? AppColors.blueContainerStrong : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
          const Gap(AppSpacing.xs),
          SelectableText(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog({required this.configuration, required this.language});

  final YorksV1ConfigurationCentre configuration;
  final AppLanguage language;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  final _controller = TextEditingController();
  bool _attempted = false;

  String _t(String key) =>
      YorksV1ConfigurationStrings.text(widget.language, key);

  bool get _valid => _controller.text.trim().length >= 8;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final changedSettings = widget.configuration.settings
        .where((setting) => setting.changed)
        .toList(growable: false);
    final changeCards = <Widget>[
      for (final setting in changedSettings)
        _ConfigurationSettingDiffCard(
          setting: setting,
          language: widget.language,
        ),
      for (final action in widget.configuration.masterActions)
        _ConfigurationMasterActionDiffCard(
          action: action,
          configuration: widget.configuration,
          language: widget.language,
        ),
    ];
    return AlertDialog(
      key: const Key('configuration-publish-dialog'),
      title: Text(_t('review_publish')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t('affected_areas'),
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final area in widget.configuration.affectedAreas)
                    _StatusPill(
                      label: YorksV1ConfigurationStrings.area(
                        widget.language,
                        area,
                      ),
                      color: AppColors.blue,
                      subtle: true,
                    ),
                ],
              ),
              if (widget.configuration.draftUpdatedBy?.trim().isNotEmpty ==
                  true) ...[
                const Gap(12),
                _Notice(
                  icon: Icons.groups_outlined,
                  title: _t('shared_draft'),
                  body: _t('draft_last_updated')
                      .replaceAll(
                        '{actor}',
                        widget.configuration.draftUpdatedBy!.trim(),
                      )
                      .replaceAll(
                        '{time}',
                        _configurationDateLabel(
                          widget.configuration.draftUpdatedAt,
                        ),
                      ),
                  tone: _NoticeTone.blue,
                ),
              ],
              if (changeCards.isNotEmpty) ...[
                const Gap(16),
                Text(
                  _t('exact_changes'),
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(8),
                for (final (index, card) in changeCards.indexed) ...[
                  card,
                  if (index != changeCards.length - 1) const Gap(AppSpacing.sm),
                ],
              ],
              const Gap(16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: _t('reason'),
                  hintText: _t('reason_hint'),
                  errorText: _attempted && !_valid
                      ? _t('reason_required')
                      : null,
                ),
              ),
              const Gap(12),
              _Notice(
                icon: Icons.history_rounded,
                title: _t('historical_safety'),
                body: _t('publish_notice'),
                tone: _NoticeTone.blue,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('cancel')),
        ),
        FilledButton.icon(
          key: const Key('configuration-confirm-publish'),
          onPressed: () {
            if (!_valid) {
              setState(() => _attempted = true);
              return;
            }
            Navigator.pop(context, _controller.text.trim());
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          icon: const Icon(Icons.publish_outlined, size: 18),
          label: Text(_t('publish')),
        ),
      ],
    );
  }
}

class _CategoryInput {
  const _CategoryInput(this.name, this.parentId);

  final String name;
  final String? parentId;
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({required this.language, required this.categories});

  final AppLanguage language;
  final List<YorksV1ConfigurationCategory> categories;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _name = TextEditingController();
  String? _parentId;
  bool _attempted = false;

  String _t(String key) =>
      YorksV1ConfigurationStrings.text(widget.language, key);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_t('add_category')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: _t('name'),
                errorText: _attempted && _name.text.trim().isEmpty
                    ? _t('field_required')
                    : null,
              ),
            ),
            const Gap(12),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: InputDecoration(labelText: _t('parent_category')),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),
            const Gap(14),
            _Notice(
              icon: Icons.edit_note_rounded,
              title: _t('draft_first'),
              body: _t('draft_first_body'),
              tone: _NoticeTone.blue,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _attempted = true);
              return;
            }
            Navigator.pop(
              context,
              _CategoryInput(_name.text.trim(), _parentId),
            );
          },
          child: Text(_t('add_to_draft')),
        ),
      ],
    );
  }
}

class _UnitInput {
  const _UnitInput({
    required this.name,
    required this.shortCode,
    required this.unitType,
    required this.decimalPlaces,
  });

  final String name;
  final String shortCode;
  final String unitType;
  final int decimalPlaces;
}

class _AddUnitDialog extends StatefulWidget {
  const _AddUnitDialog({required this.language});

  final AppLanguage language;

  @override
  State<_AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<_AddUnitDialog> {
  final _name = TextEditingController();
  final _shortCode = TextEditingController();
  String _unitType = 'count';
  int _decimalPlaces = 0;
  bool _attempted = false;

  String _t(String key) =>
      YorksV1ConfigurationStrings.text(widget.language, key);

  @override
  void dispose() {
    _name.dispose();
    _shortCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _name.text.trim().isEmpty || _shortCode.text.trim().isEmpty;
    return AlertDialog(
      title: Text(_t('add_unit')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _t('name'),
                errorText: _attempted && _name.text.trim().isEmpty
                    ? _t('field_required')
                    : null,
              ),
            ),
            const Gap(10),
            TextField(
              controller: _shortCode,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: _t('short_code'),
                errorText: _attempted && _shortCode.text.trim().isEmpty
                    ? _t('field_required')
                    : null,
              ),
            ),
            const Gap(10),
            DropdownButtonFormField<String>(
              initialValue: _unitType,
              decoration: InputDecoration(labelText: _t('unit_type')),
              items: [
                DropdownMenuItem(value: 'count', child: Text(_t('unit_count'))),
                DropdownMenuItem(
                  value: 'length',
                  child: Text(_t('unit_length')),
                ),
                DropdownMenuItem(value: 'area', child: Text(_t('unit_area'))),
                DropdownMenuItem(
                  value: 'volume',
                  child: Text(_t('unit_volume')),
                ),
                DropdownMenuItem(
                  value: 'weight',
                  child: Text(_t('unit_weight')),
                ),
                DropdownMenuItem(value: 'other', child: Text(_t('unit_other'))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _unitType = value);
              },
            ),
            const Gap(10),
            DropdownButtonFormField<int>(
              initialValue: _decimalPlaces,
              decoration: InputDecoration(labelText: _t('decimal_places')),
              items: [
                for (var value = 0; value <= 4; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _decimalPlaces = value);
              },
            ),
            const Gap(14),
            _Notice(
              icon: Icons.edit_note_rounded,
              title: _t('draft_first'),
              body: _t('draft_first_body'),
              tone: _NoticeTone.blue,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (invalid) {
              setState(() => _attempted = true);
              return;
            }
            Navigator.pop(
              context,
              _UnitInput(
                name: _name.text.trim(),
                shortCode: _shortCode.text.trim(),
                unitType: _unitType,
                decimalPlaces: _decimalPlaces,
              ),
            );
          },
          child: Text(_t('add_to_draft')),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.language,
    required this.title,
    required this.body,
    required this.label,
    required this.hint,
    required this.actionLabel,
    required this.minimumLength,
    required this.destructive,
  });

  final AppLanguage language;
  final String title;
  final String body;
  final String label;
  final String hint;
  final String actionLabel;
  final int minimumLength;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _controller.text.trim().length >= widget.minimumLength;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.body,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.inkSecondary,
                height: 1.45,
              ),
            ),
            const Gap(14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                errorText: _attempted && !valid
                    ? YorksV1ConfigurationStrings.text(
                        widget.language,
                        'minimum_characters',
                      ).replaceAll('{count}', '${widget.minimumLength}')
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            YorksV1ConfigurationStrings.text(widget.language, 'cancel'),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (!valid) {
              setState(() => _attempted = true);
              return;
            }
            Navigator.pop(context, _controller.text.trim());
          },
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive
                ? AppColors.error
                : AppColors.navy,
          ),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.error : AppColors.navy,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.blueContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(17),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.blue, size: 28),
          ),
          const Gap(14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(color: AppColors.ink),
          ),
          if (actionLabel != null && onAction != null) ...[
            const Gap(14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
