import '../../../../../shared/models/app_language.dart';
import '../../../../../shared/models/yorks_v1_configuration.dart';

abstract final class YorksV1ConfigurationStrings {
  static String text(AppLanguage language, String key) {
    return _localized[language.code]?[key] ?? _english[key] ?? key;
  }

  static String area(AppLanguage language, YorksV1ConfigurationArea area) =>
      text(language, 'area.${area.wireName}');

  static String issue(AppLanguage language, String code, String fallback) {
    final key = 'issue.$code';
    return _localized[language.code]?[key] ?? _english[key] ?? fallback;
  }

  static String enforcement(AppLanguage language, String targetCode) {
    final key = 'enforcement.$targetCode';
    return _localized[language.code]?[key] ?? _english[key] ?? targetCode;
  }

  static const Map<String, String> _english = {
    'title': 'Configuration Centre',
    'subtitle':
        'Control the defaults, master data and protected rules used by Projects, building BOQs, Material Requests, Procurement, Accounts and controlled documents.',
    'validate': 'Validate',
    'review_publish': 'Review & publish',
    'discard_draft': 'Discard draft',
    'restore_defaults': 'Restore defaults',
    'save_draft': 'Save to draft',
    'control_coverage': 'Control coverage',
    'control_coverage_help':
        'Only operational controls change live application behaviour. Protected rules remain enforced and planned controls are visible for future activation.',
    'operational': 'Operational',
    'operational_help': 'Published changes are enforced by the application.',
    'protected_control': 'Protected',
    'protected_control_help':
        'This rule is enforced by the trusted workflow and cannot be weakened here.',
    'planned': 'Planned',
    'planned_help':
        'This control is visible for planning but is not active in production.',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'read_only': 'Read only',
    'control_read_only_error':
        'This control is read-only here. Review its enforcement policy for the authoritative source.',
    'enforced_by': 'Enforced by {target}',
    'affects_areas': 'Affects {areas}',
    'draft_last_updated': 'Shared draft updated by {actor} · {time}',
    'staged_by': 'Staged by {actor} · {time}',
    'exact_changes': 'Exact staged changes',
    'master_data_action': 'Master data change',
    'material_category': 'Material category',
    'material_unit': 'Material unit',
    'target_reference': 'Target reference',
    'action_reason': 'Action reason',
    'published_value': 'Published value',
    'draft_value': 'Draft value',
    'shared_draft': 'Shared Admin draft',
    'view_changes': 'View changes',
    'publication_details': 'Publication details',
    'before': 'Before',
    'after': 'After',
    'notification_delivery_health': 'Notification delivery health',
    'notification_delivery_health_help':
        'Live backend delivery facts for the published push policy. Draft changes do not alter this status until publication.',
    'active_devices': 'Active devices',
    'pending_delivery': 'Pending delivery',
    'recent_delivery_failures': 'Failures in the last 24 hours',
    'last_successful_delivery': 'Last successful delivery',
    'no_successful_delivery': 'No successful delivery recorded',
    'push_delivery_disabled': 'Push delivery is disabled',
    'push_delivery_disabled_help':
        'The published push policy is off. In-app notifications remain authoritative.',
    'push_delivery_operational': 'Push delivery is operational',
    'push_delivery_operational_help':
        'Active devices are enrolled and the backend reports no pending or failed deliveries.',
    'push_delivery_failures': 'Delivery failures need attention',
    'push_delivery_failures_help':
        'The backend recorded one or more failed push deliveries in the last 24 hours.',
    'delivery_queue_pending': 'Push deliveries are pending',
    'delivery_queue_pending_help':
        'The backend queue still has deliveries awaiting a confirmed outcome.',
    'no_active_devices': 'No active notification devices',
    'no_active_devices_help':
        'Push is enabled, but no active device enrollment is available for delivery.',
    'enforcement.mr_draft_default_timing':
        'new Material Request draft defaults',
    'enforcement.mr_urgent_submission_guard':
        'the trusted urgent Material Request submission guard',
    'enforcement.mr_self_approval_guard':
        'the trusted Engineering self-approval command',
    'enforcement.procurement_external_readiness_guard':
        'the trusted Procurement arrangement command',
    'enforcement.notification_push_outbox':
        'the notification push outbox trigger',
    'enforcement.controlled_document_identity':
        'the Yorks legal and controlled-document identity contract',
    'enforcement.aed_commercial_boundary':
        'the protected AED commercial boundary',
    'enforcement.warehouse_first_arrangement':
        'the protected Warehouse-first arrangement contract',
    'enforcement.storage_document_contract':
        'the protected storage and controlled-document contract',
    'enforcement.append_only_audit_contract':
        'the mandatory append-only audit contract',
    'enforcement.trusted_server_numbering':
        'the trusted server numbering command',
    'enforcement.product_invariant': 'a protected Yorks V1 product invariant',
    'enforcement.retained_reference':
        'a retained reference with no active runtime consumer',
    'cancel': 'Cancel',
    'close': 'Close',
    'publish': 'Publish configuration',
    'publishing': 'Publishing…',
    'search': 'Find a setting…',
    'retry': 'Try again',
    'loading': 'Loading controlled configuration…',
    'load_failed': 'Configuration could not be loaded.',
    'admin_only': 'Configuration is available only to an active Admin.',
    'draft_first': 'Draft first',
    'draft_first_title': 'Nothing changes while you edit',
    'draft_first_body':
        'Validate and review affected areas before publication.',
    'protected_workflow': 'Protected workflow',
    'protected_workflow_title': 'Critical rules stay locked',
    'protected_workflow_body':
        'Configuration cannot weaken traceability or quantity integrity.',
    'historical_safety': 'Historical safety',
    'historical_safety_title': 'Issued records keep their values',
    'historical_safety_body':
        'Published defaults mainly affect future records.',
    'configuration_areas': 'Configuration areas',
    'configuration_areas_help':
        'Choose a focused area. User assignments and Audit Trail stay separate Admin modules.',
    'published_configuration': 'Published configuration',
    'draft_changes': 'Draft changes',
    'controlled_master_data': 'Controlled master data',
    'published_version': 'Published version',
    'published': 'Published',
    'draft': 'Draft',
    'current': 'Current',
    'audited': 'Audited',
    'no_unpublished_changes': 'No unpublished changes',
    'validation': 'Validation',
    'ready': 'Ready',
    'recommendations': 'Recommendations',
    'blocked': 'Blocked',
    'validation_help':
        'Publishability comes from real rules, not an invented score.',
    'configuration_validation': 'Configuration validation',
    'validation_detail':
        'Only real errors and recommendations are shown before publication.',
    'ready_to_publish': 'Ready to publish',
    'ready_body':
        'Master data and operational rules are internally consistent.',
    'must_correct': 'Must be corrected',
    'recommended_before_production': 'Recommended before production',
    'protected_operational_rules': 'Protected operational rules',
    'protected_operational_rules_help':
        'Core Yorks workflow rules are visible here but cannot be casually weakened.',
    'what_change_affects': 'What a published change affects',
    'existing_records_unchanged':
        'Existing controlled records remain unchanged',
    'existing_records_body':
        'Issued requests, arrangements, dispatches, receipts, returns and controlled documents keep the values that were authoritative when they were created.',
    'recent_activity': 'Configuration activity',
    'activity_help': 'Every publication records who changed what and why.',
    'no_history': 'No configuration publication history is available.',
    'reason': 'Publication reason',
    'reason_hint': 'Explain why these controlled defaults are changing.',
    'reason_required':
        'Enter at least 8 characters for the publication reason.',
    'affected_areas': 'Affected areas',
    'publish_notice':
        'Publication is server-confirmed and audited. Existing issued records are not rewritten.',
    'publish_success': 'Configuration published',
    'draft_saved': 'Draft change saved',
    'action_failed': 'The configuration change was not saved.',
    'draft_conflict':
        'The shared draft changed on another device. The latest version has been loaded; review it and try again.',
    'invalid_value': 'Review this value or master-data choice and try again.',
    'validation_blocked_action':
        'Resolve the blocking validation issues before publishing.',
    'server_rejected_action':
        'The controlled configuration service rejected this action.',
    'unexpected_response_action':
        'The server did not confirm the configuration action.',
    'discard_title': 'Discard all draft changes?',
    'discard_body':
        'This removes unpublished setting and master-data changes. Published configuration is unaffected.',
    'discard': 'Discard draft',
    'discarded': 'Draft discarded',
    'restore_title': 'Restore defaults in this draft?',
    'restore_body':
        'Defaults are staged only. Nothing becomes active until validation and publication.',
    'restored': 'Defaults staged in draft',
    'area.overview': 'Control Centre',
    'area.company_regional': 'Company & Regional',
    'area.projects_teams': 'Projects & Teams',
    'area.boq_materials': 'BOQ & Materials',
    'area.material_requests': 'Material Requests',
    'area.procurement_inventory': 'Procurement & Inventory',
    'area.accounts': 'Accounts',
    'area.documents_printing': 'Documents & Printing',
    'area.notifications': 'Notifications',
    'area.security_audit': 'Security & Audit',
    'area.numbering_data': 'Numbering & Data',
    'area.history': 'Configuration History',
    'organisation_identity': 'Organisation identity',
    'organisation_identity_help':
        'Formal company identity used throughout Yorks and controlled documents.',
    'regional_language': 'Regional & language settings',
    'regional_language_help':
        'Defaults used on desktop, tablet, mobile and generated documents.',
    'legal_company_name': 'Legal Company Name',
    'short_application_name': 'Short Application Name',
    'arabic_company_name': 'Arabic Company Name',
    'workspace_name': 'Workspace Name',
    'country': 'Country',
    'timezone': 'Timezone',
    'date_format': 'Date Format',
    'currency': 'Currency',
    'primary_language': 'Primary Language',
    'secondary_language': 'Secondary Language',
    'financial_year_start': 'Financial Year Start',
    'project_creation': 'Project creation & responsibility',
    'project_creation_help':
        'Approved role and project-membership rules are protected server-side.',
    'roles_allowed': 'Roles allowed to create projects',
    'role': 'Role',
    'create': 'Create',
    'edit': 'Edit',
    'assign_team': 'Assign Team',
    'protected_note': 'Protected Note',
    'allowed': 'Allowed',
    'assigned_projects': 'Assigned projects',
    'all_projects': 'All projects',
    'view_only': 'View only',
    'active_membership_required': 'Active membership required',
    'may_create_submit_mr': 'May create and submit Material Requests',
    'organization_wide_pe': 'Organization-wide Project Engineer authority',
    'audited_override': 'Audited override',
    'project_engineer': 'Project Engineer',
    'site_engineer': 'Site Engineer',
    'senior_mechanical_engineer': 'Senior Mechanical Engineer',
    'project_manager': 'Project Manager',
    'workshop_in_charge': 'Workshop In-Charge',
    'document_controller': 'Document Controller',
    'procurement': 'Procurement',
    'admin': 'Admin',
    'no_weighted_progress': 'Weighted completeness is not part of Yorks V1',
    'no_weighted_progress_body':
        'Project progress stays factual and stage-based. Configuration cannot introduce a weighted completion score.',
    'boq_scope_rules': 'BOQ scope & folder rules',
    'master_categories': 'Material categories',
    'master_units': 'Controlled units',
    'items': 'items',
    'default_boq_structure': 'Default BOQ folder structure',
    'default_boq_structure_help':
        'Every new Common or building scope receives this protected order.',
    'number': 'No.',
    'folder': 'Folder',
    'default': 'Default',
    'action': 'Action',
    'add_category': 'Add category',
    'add_unit': 'Add unit',
    'archive': 'Archive',
    'active': 'Active',
    'archived': 'Archived',
    'system': 'Yorks default',
    'custom': 'Custom',
    'name': 'Name',
    'parent_category': 'Parent category (optional)',
    'short_code': 'Short code',
    'unit_type': 'Unit type',
    'decimal_places': 'Decimal places',
    'add_to_draft': 'Add to draft',
    'archive_title': 'Archive master data?',
    'archive_reason': 'Archive reason',
    'archive_reason_hint':
        'Explain why this option should no longer be selectable.',
    'archive_history_notice':
        'Historical records keep the original value. This change is staged in the draft.',
    'request_lifecycle': 'Material Request lifecycle',
    'request_rules': 'Request creation & approval rules',
    'request_timing': 'Request timing',
    'controlled_columns': 'Controlled request columns',
    'created': 'Created',
    'engineering_approval': 'Engineering Approval',
    'arrangement': 'Procurement Arrangement',
    'ready_delivery': 'Ready for Delivery',
    'dispatch': 'Dispatch',
    'received': 'Received',
    'completed': 'Completed',
    'default_timing': 'Default timing',
    'normal': 'Normal',
    'urgent': 'Urgent',
    'scheduled': 'Scheduled',
    'arrangement_policy': 'Arrangement policy',
    'sourcing': 'Warehouse & supplier sourcing',
    'dispatch_receipt_controls': 'Dispatch & receipt controls',
    'billing_baseline': 'Billing stage baseline',
    'billing_baseline_help':
        'Configuration is retained for controlled future use; no deferred Accounts route is enabled here.',
    'total': 'Total',
    'payment_terms': 'Payment terms (days)',
    'pdc_reminder': 'PDC reminder (days)',
    'file_version_control': 'File & version control',
    'file_policy': 'File policy',
    'maximum_file_size': 'Maximum file size (MB)',
    'retention_years': 'Retention (years)',
    'allowed_formats': 'Allowed formats',
    'bilingual_header': 'Bilingual controlled header',
    'notification_channels': 'Notification channels',
    'notification_rules': 'Operational notification rules',
    'noise_control': 'Noise control',
    'in_app': 'In-app notifications',
    'always_enabled': 'Always enabled',
    'push': 'Push notifications',
    'email': 'Email notifications',
    'authentication_policy': 'Authentication & session policy',
    'session_timeout': 'Session timeout (hours)',
    'minimum_password': 'Minimum password length',
    'admin_mfa': 'Admin MFA',
    'protected_security': 'Protected security controls',
    'audit_retention': 'Audit retention (years)',
    'controlled_numbering': 'Controlled numbering',
    'data_safety': 'Data safety defaults',
    'environment_information': 'Environment information',
    'environment': 'Environment',
    'configuration_schema': 'Configuration schema',
    'project_pattern': 'Project',
    'mr_pattern': 'Material Request',
    'dispatch_pattern': 'Internal Dispatch',
    'return_pattern': 'Material Return',
    'invoice_pattern': 'Client Invoice',
    'version_history': 'Published configuration versions',
    'version_history_help':
        'Every publication records the Admin, reason, affected areas and time.',
    'version': 'Version',
    'published_by': 'Published by',
    'published_at': 'Published',
    'changes': 'Changes',
    'search_results': 'Search results',
    'no_search_results': 'No configuration settings match this search.',
    'open_configuration_area': 'Open this configuration area',
    'controlled_master_summary':
        '{templates} BOQ folders + {categories} categories + {units} units',
    'procurement_project_access': 'Procurement project access',
    'procurement_project_access_body':
        'Procurement may view active Projects and BOQs but cannot create or edit Engineering records.',
    'building_specific_boq': 'Building-specific BOQ',
    'building_specific_boq_body':
        'Every physical building owns an independent BOQ; Common is only for shared material.',
    'engineering_approval_first': 'Engineering approval first',
    'engineering_approval_first_body':
        'A Material Request must receive Engineering approval before Procurement arrangement starts.',
    'quantity_integrity': 'Quantity integrity',
    'quantity_integrity_body':
        'Arrangement and dispatch cannot exceed requested, approved, outstanding or available quantities.',
    'append_only_audit': 'Append-only audit',
    'append_only_audit_body':
        'Critical actions remain attributable and cannot be silently rewritten.',
    'creation_only': 'Creation only',
    'no': 'No',
    'unique_york_reference': 'Unique York Reference',
    'unique_york_reference_body': 'Duplicate York references are rejected.',
    'multiple_engineers': 'Multiple Engineers per Project',
    'multiple_engineers_body':
        'Dated Project and Site Engineer memberships are supported.',
    'assigned_site_engineer_mr': 'Any assigned Site Engineer may raise an MR',
    'assigned_site_engineer_mr_body':
        'Active project membership is checked by the server.',
    'physical_building_required': 'At least one physical building required',
    'physical_building_required_body':
        'Every project has a real building scope plus Common.',
    'procurement_create_projects': 'Procurement may create projects',
    'procurement_create_projects_body':
        'Protected by the approved Yorks separation of duties.',
    'procurement_view_only_help':
        'Procurement stays view-only for Engineering project records.',
    'approved_v1_exception':
        'This deliberate production exception follows the approved Yorks V1 product contract.',
    'boq_scope_rules_help':
        'Workshop Materials and independent building workbooks remain protected.',
    'overview_summary_only': 'Overview is summary-only',
    'overview_summary_only_body':
        'Overview never becomes a persisted scope, edit target or Material Request source.',
    'common_independent': 'Common is independent',
    'common_independent_body':
        'Common contains only material genuinely shared by the project.',
    'building_owns_boq': 'Every building owns its BOQ',
    'building_owns_boq_body':
        'Rows, quantities, imports and request sources do not merge across buildings.',
    'default_folders': 'Workshop Materials default folder',
    'default_folders_body':
        'Every new real scope receives Workshop Materials plus project-wide custom folder names.',
    'master_draft_help':
        'New and archived choices stay in the draft until publication.',
    'units_active_help':
        'Only active published units are intended for future material entry.',
    'decimal_places_value': '{count} decimal places',
    'request_lifecycle_path':
        'Created → Engineering Approval → Procurement Arrangement → Ready for Delivery → Dispatch → Received → Completed',
    'request_rules_help':
        'Controls what users may do before Procurement receives a request.',
    'engineering_before_procurement': 'Engineering approval before Procurement',
    'engineering_before_procurement_body':
        'Procurement cannot start arrangement until Engineering approval.',
    'authorized_creator_self_approval': 'Authorized creator may self-approve',
    'authorized_creator_self_approval_body':
        'When enabled, a Project Engineer, global Engineering role or Admin who creates a request may approve it. Site Engineers never gain approval authority.',
    'editable_before_approval': 'Editable before Engineering approval',
    'editable_before_approval_body':
        'Creator and an authorized Project Engineer may correct the request before approval.',
    'comments_from_creation': 'Comments from request creation',
    'comments_from_creation_body':
        'Mentions notify authorized project participants.',
    'private_drafts': 'Private drafts',
    'private_drafts_body':
        'Drafts remain creator-only with controlled Admin support.',
    'inventory_search_items': 'Inventory search when adding items',
    'inventory_search_items_body':
        'Engineering receives descriptive suggestions without stock or commercial fields.',
    'site_photo_receipt': 'Site photo after receipt',
    'site_photo_receipt_body':
        'Confirmed receipts may include authorized evidence.',
    'timing_modes_help': 'Approved timing modes remain intentionally simple.',
    'urgent_request_body': 'Urgent requests remain clearly marked.',
    'scheduled_requirement': 'Requires scheduled date',
    'controlled_columns_help':
        'These fields form the controlled Yorks request table.',
    'field': 'Field',
    'required': 'Required',
    'source': 'Source',
    'yes': 'Yes',
    'item_description': 'Item Description',
    'boq_inventory_custom': 'BOQ / Inventory / Custom',
    'brand_origin': 'Brand / Origin',
    'requester': 'Requester',
    'quantity': 'Quantity',
    'server_cap': 'Server cap',
    'unit': 'Unit',
    'controlled_master': 'Controlled master',
    'unit_cost': 'Unit Cost',
    'capability': 'Capability',
    'commercial_users': 'Commercial users',
    'backend': 'Backend',
    'total_cost': 'Total Cost',
    'calculated': 'Calculated',
    'server_derived': 'Server-derived',
    'arrangement_policy_help':
        'Procurement arranges only Engineering-approved requests.',
    'external_source_readiness_required':
        'Require external-source readiness confirmation',
    'external_source_readiness_required_body':
        'When enabled, Procurement must confirm that every external quantity is available or firmly committed before saving. Supplier name remains optional.',
    'default_source': 'Default source',
    'warehouse': 'Warehouse',
    'external_supplier': 'External supplier',
    'partial_allowed': 'Partial arrangement allowed',
    'partial_allowed_body': 'A Partial decision requires an explicit reason.',
    'cannot_provide_allowed': 'Cannot Provide Now allowed',
    'cannot_provide_allowed_body':
        'Zero arranged quantity and an explicit reason are required.',
    'reservation_enforced': 'Warehouse reservation enforced',
    'reservation_enforced_body':
        'Approved Warehouse quantity reserves stock atomically.',
    'dispatch_reference_required': 'Dispatch reference required',
    'dispatch_reference_required_body':
        'Reference and dispatch date are mandatory.',
    'prevent_over_dispatch': 'Prevent over-dispatch',
    'prevent_over_dispatch_body':
        'Dispatch is capped by approved outstanding and available stock.',
    'receipt_exception_tracking': 'Receipt exception tracking',
    'receipt_exception_tracking_body':
        'Missing and Damaged quantity remains replacement-eligible.',
    'sourcing_help':
        'V1 keeps sourcing practical without introducing a full RFQ or Purchase Order suite.',
    'warehouse_reservation': 'Warehouse reservation',
    'warehouse_reservation_body':
        'One authoritative reservation ledger owns the commitment.',
    'external_source': 'External source',
    'external_source_body': 'External supply never mutates Warehouse stock.',
    'arrangement_decisions': 'Full / Partial / Cannot Provide Now',
    'arrangement_decisions_body':
        'Each request line has exactly one current arrangement decision.',
    'dispatch_controls_help': 'Trusted quantity rules are applied server-side.',
    'control': 'Control',
    'value': 'Value',
    'authority': 'Authority',
    'dispatch_quantity_cap': 'Dispatch quantity cap',
    'dispatch_quantity_formula': 'Approved − good received − in transit',
    'server_rpc': 'Server RPC',
    'warehouse_stock_cap': 'Warehouse stock cap',
    'available_at_commit': 'Available at commit',
    'receipt_outcomes': 'Receipt outcomes',
    'receipt_outcome_values': 'Received / Missing / Damaged',
    'engineer_review': 'Engineer review',
    'delivery_order': 'Delivery Order',
    'immutable_dispatch_revision': 'Immutable dispatch/review revision',
    'trusted_command': 'Trusted command',
    'client_invoice_pdc': 'Client invoice & PDC policy',
    'deferred_route_help':
        'Defaults are retained without enabling a deferred route.',
    'certification_separate': 'Certification and payment stay separate',
    'certification_separate_body':
        'Claimable, Claimed, Certified and Paid remain different facts. Configuration does not grant Accounts access.',
    'file_controls_help':
        'Rules that protect formal project and operational records.',
    'private_linked_files': 'Private linked files',
    'private_linked_files_body':
        'Documents inherit authorized project and workflow access.',
    'required_revisions': 'Required revisions',
    'required_revisions_body': 'Controlled documents carry explicit revisions.',
    'approved_version_locking': 'Approved-version locking',
    'approved_version_locking_body':
        'Published files are never silently overwritten.',
    'a4_pdf_consistency': 'A4 PDF consistency',
    'a4_pdf_consistency_body':
        'Preview, download and print use the same controlled bytes.',
    'bilingual_header_body':
        'Yorks English and Arabic identity stays consistent in future documents.',
    'file_policy_help':
        'Reasonable office defaults shared by browser, tablet and mobile.',
    'notification_channels_help':
        'Use notifications for ownership and exceptions, not noise.',
    'in_app_body': 'Always enabled for controlled workflow ownership.',
    'push_body': 'Mobile and installed-app alerts when the app is closed.',
    'email_body': 'Office reminder channel for selected due dates.',
    'notification_rules_help':
        'Each event targets users responsible for the next action.',
    'event': 'Event',
    'recipient': 'Recipient',
    'channels': 'Channels',
    'mr_submitted': 'MR submitted',
    'assigned_project_engineer': 'Assigned Project Engineer',
    'in_app_push': 'In-app + Push',
    'engineering_approval_event': 'Engineering approval',
    'arrangement_saved': 'Arrangement saved',
    'requester_site_engineer': 'Requester / Site Engineer',
    'materials_dispatched': 'Materials dispatched',
    'receipt_exception': 'Receipt exception',
    'procurement_project_engineer': 'Procurement + Project Engineer',
    'return_submitted': 'Material Return submitted',
    'noise_control_help': 'Keep the workspace calm and useful.',
    'no_self_loops': 'No self-notification loops',
    'no_self_loops_body':
        'An actor is not alerted for their routine action unless it creates a new obligation.',
    'mentions_notify': 'Mentions notify explicitly',
    'mentions_notify_body':
        '@mentions notify only users authorized to view the linked record.',
    'critical_reminders': 'Critical reminders survive mute',
    'critical_reminders_body':
        'Security and controlled due-date alerts remain visible.',
    'authentication_policy_help':
        'Security controls apply to browser, tablet and mobile.',
    'admin_mfa_body': 'Recommended for production Admin accounts.',
    'protected_security_help':
        'Core authorization controls cannot be weakened from the interface.',
    'deny_inactive_users': 'Deny inactive users',
    'deny_inactive_users_body': 'Deactivated accounts fail closed immediately.',
    'append_only_audit_security_body':
        'Critical audit entries cannot be rewritten or removed.',
    'commercial_enforcement': 'Backend commercial enforcement',
    'commercial_enforcement_body':
        'Unauthorized projections contain no commercial schema or value.',
    'log_exports': 'Log exports',
    'log_exports_body': 'Track controlled register exports.',
    'log_access_changes': 'Log access changes',
    'log_access_changes_body':
        'User, role and capability changes create audit events.',
    'audit_retention_help':
        'Historical attribution remains available for management review.',
    'controlled_numbering_help':
        'New records use these patterns; issued references never change retroactively.',
    'delivery_order_reference': 'Official reference entered at dispatch',
    'data_safety_help':
        'Operational records and migrations favor preservation over convenience.',
    'preserve_issued_references': 'Preserve issued references',
    'preserve_issued_references_body':
        'Pattern changes apply only to future records.',
    'no_fuzzy_backfills': 'No fuzzy historical backfills',
    'no_fuzzy_backfills_body':
        'Migration never guesses categories, scopes or roles into history.',
    'controlled_schema_versioning': 'Controlled schema versioning',
    'controlled_schema_versioning_body':
        'Every publication records the active configuration schema.',
    'environment_information_help':
        'Reference only; deployment authority remains outside this screen.',
    'protected_label': 'Protected',
    'archive_tooltip': 'Archive',
    'unit_count': 'Count',
    'unit_length': 'Length',
    'unit_area': 'Area',
    'unit_volume': 'Volume',
    'unit_weight': 'Weight',
    'unit_other': 'Other',
    'online_required': 'Configuration changes require an online connection.',
    'service_unavailable':
        'The controlled configuration service is unavailable.',
    'field_required': 'This field is required.',
    'minimum_characters': 'Enter at least {count} characters.',
    'default_currency': 'AED',
    'billing_design': 'Design',
    'billing_material_supply': 'Material Supply',
    'billing_installation': 'Installation',
    'billing_commissioning_handover': 'Commissioning & Handover',
    'billing_energizing': 'Energizing',
    'blocking_issue_count': '{count} blocking issue(s) prevent publication.',
    'recommendations_review':
        'Recommendations are optional but should be reviewed.',
    'issue.billing_weights_total':
        'Billing stage weights must total exactly 100%.',
    'issue.company_legal_name_required': 'Legal Company Name is required.',
    'issue.languages_must_differ':
        'Primary and secondary languages must be different.',
    'issue.arabic_company_name_recommended':
        'Add the formal Arabic company name for bilingual controlled documents.',
    'issue.admin_mfa_recommended': 'Admin MFA is not enabled.',
    'issue.push_notifications_recommended':
        'Push notifications are disabled; mobile reminders may be missed.',
    'issue.material_category_conflict':
        'A staged material category now conflicts with existing master data.',
    'issue.material_unit_conflict':
        'A staged material unit now conflicts with existing master data.',
    'issue.master_archive_conflict':
        'A staged archive is no longer valid against current master data.',
    'protected': 'Protected',
  };

  static const Map<String, Map<String, String>> _localized = {
    'ar': {
      'title': 'مركز الإعدادات',
      'subtitle':
          'التحكم في الإعدادات الافتراضية والبيانات الرئيسية والقواعد المحمية للمشاريع وطلبات المواد والمشتريات والمستندات.',
      'validate': 'تحقق',
      'review_publish': 'مراجعة ونشر',
      'discard_draft': 'تجاهل المسودة',
      'restore_defaults': 'استعادة الافتراضيات',
      'save_draft': 'حفظ في المسودة',
      'control_coverage': 'نطاق التحكم',
      'control_coverage_help':
          'العناصر التشغيلية فقط تغير سلوك التطبيق. تبقى القواعد المحمية مفعلة وتظهر العناصر المخططة للتفعيل مستقبلاً.',
      'operational': 'تشغيلي',
      'operational_help': 'تطبق التغييرات المنشورة في التطبيق.',
      'protected_control': 'محمي',
      'protected_control_help':
          'هذه القاعدة مفروضة من سير العمل الموثوق ولا يمكن إضعافها من هنا.',
      'planned': 'مخطط',
      'planned_help': 'هذا التحكم معروض للتخطيط وغير مفعل في الإنتاج.',
      'enabled': 'مفعل',
      'disabled': 'معطل',
      'read_only': 'للقراءة فقط',
      'control_read_only_error':
          'عنصر التحكم هذا للقراءة فقط هنا. راجع سياسة التطبيق لمعرفة المصدر المعتمد.',
      'enforced_by': 'يطبق بواسطة {target}',
      'affects_areas': 'يؤثر في {areas}',
      'draft_last_updated': 'حدث المسودة المشتركة {actor} · {time}',
      'staged_by': 'أعدها {actor} · {time}',
      'exact_changes': 'التغييرات المعدة بالضبط',
      'master_data_action': 'تغيير في البيانات الرئيسية',
      'material_category': 'فئة المواد',
      'material_unit': 'وحدة المواد',
      'target_reference': 'مرجع العنصر',
      'action_reason': 'سبب الإجراء',
      'published_value': 'القيمة المنشورة',
      'draft_value': 'قيمة المسودة',
      'shared_draft': 'مسودة المسؤولين المشتركة',
      'view_changes': 'عرض التغييرات',
      'publication_details': 'تفاصيل النشر',
      'before': 'قبل',
      'after': 'بعد',
      'notification_delivery_health': 'حالة تسليم الإشعارات',
      'notification_delivery_health_help':
          'حقائق مباشرة من الخادم لسياسة الإشعارات المنشورة. لا تؤثر تغييرات المسودة قبل النشر.',
      'active_devices': 'الأجهزة النشطة',
      'pending_delivery': 'قيد التسليم',
      'recent_delivery_failures': 'إخفاقات آخر 24 ساعة',
      'last_successful_delivery': 'آخر تسليم ناجح',
      'no_successful_delivery': 'لم يسجل أي تسليم ناجح',
      'push_delivery_disabled': 'تسليم الإشعارات معطل',
      'push_delivery_disabled_help':
          'سياسة الإشعارات المنشورة معطلة. تبقى إشعارات داخل التطبيق هي المرجع.',
      'push_delivery_operational': 'تسليم الإشعارات يعمل',
      'push_delivery_operational_help':
          'الأجهزة النشطة مسجلة ولا توجد عمليات تسليم معلقة أو فاشلة.',
      'push_delivery_failures': 'إخفاقات التسليم تحتاج إلى مراجعة',
      'push_delivery_failures_help':
          'سجل الخادم عملية أو أكثر من عمليات تسليم الإشعارات الفاشلة خلال آخر 24 ساعة.',
      'delivery_queue_pending': 'عمليات تسليم معلقة',
      'delivery_queue_pending_help':
          'ما زالت قائمة انتظار الخادم تحتوي على عمليات تسليم تنتظر نتيجة مؤكدة.',
      'no_active_devices': 'لا توجد أجهزة إشعارات نشطة',
      'no_active_devices_help':
          'الإشعارات مفعلة ولكن لا يوجد تسجيل جهاز نشط متاح للتسليم.',
      'enforcement.mr_draft_default_timing':
          'الإعدادات الافتراضية لمسودة طلب المواد الجديدة',
      'enforcement.mr_urgent_submission_guard':
          'حاجز إرسال طلب المواد العاجل الموثوق',
      'enforcement.mr_self_approval_guard':
          'أمر الموافقة الهندسية الذاتية الموثوق',
      'enforcement.procurement_external_readiness_guard':
          'أمر ترتيب المشتريات الموثوق',
      'enforcement.notification_push_outbox': 'مشغل قائمة إرسال الإشعارات',
      'enforcement.controlled_document_identity':
          'عقد الهوية القانونية والمستندات المعتمدة ليوركس',
      'enforcement.aed_commercial_boundary':
          'الحد التجاري المحمي للدرهم الإماراتي',
      'enforcement.warehouse_first_arrangement':
          'عقد الترتيب المحمي الذي يبدأ بالمستودع',
      'enforcement.storage_document_contract':
          'عقد التخزين والمستندات المعتمدة المحمي',
      'enforcement.append_only_audit_contract':
          'عقد التدقيق الإلزامي للإضافة فقط',
      'enforcement.trusted_server_numbering': 'أمر الترقيم الموثوق في الخادم',
      'enforcement.product_invariant': 'قاعدة منتج Yorks V1 محمية',
      'enforcement.retained_reference':
          'قيمة مرجعية محفوظة دون مستهلك تشغيلي نشط',
      'cancel': 'إلغاء',
      'close': 'إغلاق',
      'publish': 'نشر الإعدادات',
      'search': 'البحث عن إعداد…',
      'draft_first': 'المسودة أولاً',
      'protected_workflow': 'سير عمل محمي',
      'historical_safety': 'سلامة السجل',
      'configuration_areas': 'مناطق الإعدادات',
      'published_configuration': 'الإعدادات المنشورة',
      'draft_changes': 'تغييرات المسودة',
      'validation': 'التحقق',
      'ready': 'جاهز',
      'recommendations': 'توصيات',
      'blocked': 'محظور',
      'area.overview': 'مركز التحكم',
      'area.company_regional': 'الشركة والمنطقة',
      'area.projects_teams': 'المشاريع والفرق',
      'area.boq_materials': 'جداول الكميات والمواد',
      'area.material_requests': 'طلبات المواد',
      'area.procurement_inventory': 'المشتريات والمخزون',
      'area.accounts': 'الحسابات',
      'area.documents_printing': 'المستندات والطباعة',
      'area.notifications': 'الإشعارات',
      'area.security_audit': 'الأمان والتدقيق',
      'area.numbering_data': 'الترقيم والبيانات',
      'area.history': 'سجل الإعدادات',
      'authorized_creator_self_approval': 'يمكن للمنشئ المخوّل الاعتماد ذاتياً',
      'authorized_creator_self_approval_body':
          'عند التفعيل، يجوز لمهندس المشروع أو دور هندسي عام أو مسؤول إداري أن يعتمد الطلب الذي أنشأه. لا يحصل مهندس الموقع على صلاحية الاعتماد.',
      'external_source_readiness_required':
          'اشتراط تأكيد جاهزية المصدر الخارجي',
      'external_source_readiness_required_body':
          'عند التفعيل، يجب أن تؤكد المشتريات أن كل كمية خارجية متاحة أو ملتزم بتوفيرها قبل الحفظ. يبقى اسم المورد اختيارياً.',
      'organisation_identity': 'هوية المؤسسة',
      'regional_language': 'الإعدادات الإقليمية واللغة',
      'master_categories': 'فئات المواد',
      'master_units': 'الوحدات المعتمدة',
      'add_category': 'إضافة فئة',
      'add_unit': 'إضافة وحدة',
      'archive': 'أرشفة',
      'active': 'نشط',
      'published': 'منشور',
      'draft': 'مسودة',
      'reason': 'سبب النشر',
      'affected_areas': 'المناطق المتأثرة',
      'notification_channels': 'قنوات الإشعار',
      'authentication_policy': 'سياسة المصادقة والجلسة',
      'controlled_numbering': 'الترقيم المعتمد',
      'version_history': 'إصدارات الإعدادات المنشورة',
    },
    'ur': {
      'title': 'کنفیگریشن سینٹر',
      'validate': 'تصدیق کریں',
      'review_publish': 'جائزہ اور شائع کریں',
      'discard_draft': 'مسودہ خارج کریں',
      'search': 'سیٹنگ تلاش کریں…',
      'area.overview': 'کنٹرول سینٹر',
      'area.company_regional': 'کمپنی اور علاقائی',
      'area.projects_teams': 'پروجیکٹس اور ٹیمیں',
      'area.boq_materials': 'BOQ اور میٹیریل',
      'area.material_requests': 'میٹیریل ریکویسٹس',
      'area.procurement_inventory': 'پروکیورمنٹ اور انوینٹری',
      'area.accounts': 'اکاؤنٹس',
      'area.documents_printing': 'دستاویزات اور پرنٹنگ',
      'area.notifications': 'اطلاعات',
      'area.security_audit': 'سیکیورٹی اور آڈٹ',
      'area.numbering_data': 'نمبرنگ اور ڈیٹا',
      'area.history': 'کنفیگریشن ہسٹری',
      'authorized_creator_self_approval':
          'مجاز تخلیق کنندہ خود منظوری دے سکتا ہے',
      'authorized_creator_self_approval_body':
          'فعال ہونے پر پروجیکٹ انجینئر، ادارہ گیر انجینئرنگ کردار یا ایڈمن اپنی بنائی ہوئی درخواست منظور کر سکتا ہے۔ سائٹ انجینئر کو منظوری کا اختیار نہیں ملتا۔',
      'external_source_readiness_required':
          'بیرونی ذریعہ کی تیاری کی تصدیق لازمی کریں',
      'external_source_readiness_required_body':
          'فعال ہونے پر پروکیورمنٹ کو محفوظ کرنے سے پہلے ہر بیرونی مقدار کی دستیابی یا پکی وابستگی کی تصدیق کرنا ہوگی۔ سپلائر کا نام اختیاری رہے گا۔',
    },
    'hi': {
      'title': 'कॉन्फ़िगरेशन केंद्र',
      'validate': 'सत्यापित करें',
      'review_publish': 'समीक्षा और प्रकाशित करें',
      'discard_draft': 'ड्राफ़्ट हटाएँ',
      'search': 'सेटिंग खोजें…',
      'area.overview': 'कंट्रोल सेंटर',
      'area.company_regional': 'कंपनी और क्षेत्र',
      'area.projects_teams': 'प्रोजेक्ट और टीमें',
      'area.boq_materials': 'BOQ और सामग्री',
      'area.material_requests': 'सामग्री अनुरोध',
      'area.procurement_inventory': 'प्रोक्योरमेंट और इन्वेंटरी',
      'area.accounts': 'अकाउंट्स',
      'area.documents_printing': 'दस्तावेज़ और प्रिंटिंग',
      'area.notifications': 'सूचनाएँ',
      'area.security_audit': 'सुरक्षा और ऑडिट',
      'area.numbering_data': 'नंबरिंग और डेटा',
      'area.history': 'कॉन्फ़िगरेशन इतिहास',
      'authorized_creator_self_approval':
          'अधिकृत निर्माता स्वयं अनुमोदन कर सकता है',
      'authorized_creator_self_approval_body':
          'सक्षम होने पर प्रोजेक्ट इंजीनियर, संगठन-व्यापी इंजीनियरिंग भूमिका या एडमिन अपने बनाए अनुरोध को अनुमोदित कर सकता है। साइट इंजीनियर को अनुमोदन अधिकार नहीं मिलता।',
      'external_source_readiness_required':
          'बाहरी स्रोत की तैयारी की पुष्टि आवश्यक करें',
      'external_source_readiness_required_body':
          'सक्षम होने पर खरीद विभाग को सहेजने से पहले प्रत्येक बाहरी मात्रा की उपलब्धता या पक्की प्रतिबद्धता की पुष्टि करनी होगी। आपूर्तिकर्ता का नाम वैकल्पिक रहेगा।',
    },
  };
}
