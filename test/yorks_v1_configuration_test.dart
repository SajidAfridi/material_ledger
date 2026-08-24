import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/admin/presentation/screens/yorks_v1_configuration_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_configuration.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_configuration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late _FakeConfigurationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = _FakeConfigurationRepository(_configurationFixture());
  });

  test('configuration projection decodes draft, validation and history', () {
    final configuration = YorksV1ConfigurationCentre.fromJson(
      _configurationFixture(),
    );

    expect(configuration.publishedLabel, 'v1.3.0');
    expect(configuration.draftChangeCount, 1);
    expect(configuration.hasDraft, isTrue);
    expect(
      configuration.affectedAreas,
      contains(YorksV1ConfigurationArea.notifications),
    );
    expect(configuration.validation.canPublish, isTrue);
    expect(configuration.history.single.publishedBy, 'Khaled S. Sleiman');
    expect(configuration.boolValue('notifications.push_enabled'), isFalse);
  });

  testWidgets('desktop Configuration matches the R38 information hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpConfiguration(tester, preferences, repository);

    expect(find.text('Configuration Centre'), findsOneWidget);
    expect(find.text('DRAFT FIRST'), findsOneWidget);
    expect(find.text('PROTECTED WORKFLOW'), findsOneWidget);
    expect(find.text('HISTORICAL SAFETY'), findsOneWidget);
    expect(find.text('Configuration areas'), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-review-publish')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Company & Regional').first);
    await tester.pumpAndSettle();
    expect(find.text('Organisation identity'), findsOneWidget);
    expect(find.text('Legal Company Name'), findsOneWidget);
    expect(find.text('Regional & language settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px layout uses focused navigation without page overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpConfiguration(tester, preferences, repository);

    expect(find.text('Configuration Centre'), findsOneWidget);
    expect(find.text('DRAFT FIRST'), findsOneWidget);
    expect(find.text('Critical rules stay locked'), findsNothing);
    expect(find.byKey(const Key('configuration-scroll-view')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('configuration-search')),
      'material',
    );
    await tester.pumpAndSettle();
    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('BOQ & Materials'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('BOQ & Materials').last);
    await tester.pumpAndSettle();
    expect(find.text('Material categories'), findsOneWidget);
    expect(find.text('Controlled units'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation and Restore Defaults use controlled dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpConfiguration(tester, preferences, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Validate').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-validation-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();

    final restore = find.widgetWithText(TextButton, 'Restore defaults').first;
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.text('Restore defaults in this draft?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore defaults'));
    await tester.pumpAndSettle();

    expect(repository.restoreCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Admin can review both published Phase 3 workflow controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpConfiguration(tester, preferences, repository);

    await tester.tap(find.text('Material Requests').first);
    await tester.pumpAndSettle();
    expect(find.text('Authorized creator may self-approve'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);

    await tester.tap(find.text('Procurement & Inventory').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Require external-source readiness confirmation'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification delivery health shows authoritative backend facts',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpConfiguration(tester, preferences, repository);

      await tester.enterText(
        find.byKey(const Key('configuration-search')),
        'notification',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications').last);
      await tester.pumpAndSettle();
      expect(find.text('Notification delivery health'), findsOneWidget);
      expect(find.text('Push deliveries are pending'), findsOneWidget);
      expect(find.text('Active devices'), findsOneWidget);
      expect(find.text('Pending delivery'), findsOneWidget);
      expect(find.text('Failures in the last 24 hours'), findsOneWidget);
      expect(find.text('Last successful delivery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publish review includes exact staged master data actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _configurationFixture();
    fixture['master_actions'] = [
      {
        'id': 'ca820000-0000-4000-8000-000000000001',
        'entity_kind': 'material_unit',
        'action_kind': 'create',
        'target_id': 'ca820000-0000-4000-8000-000000000002',
        'payload': {
          'name': 'Length metre',
          'short_code': 'm',
          'unit_type': 'length',
          'decimal_places': 2,
        },
      },
    ];

    await _pumpConfiguration(
      tester,
      preferences,
      _FakeConfigurationRepository(fixture),
    );

    await tester.tap(find.byKey(const Key('configuration-review-publish')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-publish-dialog')),
      findsOneWidget,
    );
    expect(find.text('Length metre'), findsOneWidget);
    expect(find.text('Material unit'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-Admin receives a fail-closed Configuration surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1ConfigurationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: YorksV1ConfigurationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Configuration is available only to an active Admin.'),
      findsOneWidget,
    );
    expect(find.text('Configuration Centre'), findsNothing);
  });

  for (final evidence in <({String name, Size size})>[
    (name: 'desktop_1366x768', size: const Size(1366, 768)),
    (name: 'tablet_900x1024', size: const Size(900, 1024)),
    (name: 'mobile_360x800', size: const Size(360, 800)),
  ]) {
    testWidgets('R38 Configuration visual evidence — ${evidence.name}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpConfiguration(tester, preferences, repository);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(YorksV1ConfigurationScreen),
        matchesGoldenFile('goldens/r38/configuration_${evidence.name}.png'),
      );
    });
  }
}

Future<void> _pumpConfiguration(
  WidgetTester tester,
  SharedPreferences preferences,
  YorksV1ConfigurationRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
        yorksV1ConfigurationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const YorksV1ConfigurationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeConfigurationRepository implements YorksV1ConfigurationRepository {
  _FakeConfigurationRepository(this.fixture);

  final Map<String, dynamic> fixture;
  int restoreCalls = 0;

  @override
  Future<YorksV1ConfigurationCentre> getConfigurationCentre() async =>
      YorksV1ConfigurationCentre.fromJson(fixture);

  @override
  Future<YorksV1RuntimeConfiguration> getRuntimeConfiguration() async =>
      YorksV1RuntimeConfiguration.fromJson({
        'schema_version': 'R38.5 / 1.1',
        'published_version': 4,
        'published_label': 'v1.3.0',
        'published_at': '2026-08-13T18:40:00Z',
        'default_timing': 'normal',
        'urgent_enabled': true,
        'allow_authorized_creator_self_approval': true,
        'require_external_source_readiness': false,
        'push_enabled': true,
      });

  @override
  Future<YorksV1ConfigurationPublicationDetail> getPublicationDetail({
    required String publicationId,
  }) async => YorksV1ConfigurationPublicationDetail.fromJson({
    'publication': fixture['history'] is List
        ? (fixture['history'] as List).first
        : const <String, Object?>{},
    'changes': const <Object?>[],
  });

  @override
  Future<List<String>> getActiveUnitCodes() async => const ['Nos', 'Meter'];

  @override
  Future<void> discardDraft({
    required int expectedRevision,
    required String idempotencyKey,
  }) async {}

  @override
  Future<String> publish({
    required String reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => 'v1.4.0';

  @override
  Future<void> restoreDefaults({
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    restoreCalls += 1;
  }

  @override
  Future<void> stageMasterAction({
    required String entityKind,
    required String actionKind,
    required String targetId,
    required Map<String, Object?> payload,
    required String? reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> stageSetting({
    required String settingKey,
    required Object value,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {}
}

Map<String, dynamic> _configurationFixture() => {
  'schema_version': 'R38.5 / 1.0',
  'environment': 'Production',
  'published_version': 4,
  'published_label': 'v1.3.0',
  'published_at': '2026-08-13T18:40:00Z',
  'published_by': 'Khaled S. Sleiman',
  'draft_revision': 7,
  'draft_base_version': 4,
  'draft_updated_at': '2026-08-14T09:00:00Z',
  'draft_updated_by': 'Owner · Admin',
  'operational_health': {
    'push_enabled': true,
    'active_device_count': 3,
    'pending_delivery_count': 1,
    'recent_failure_count': 0,
    'last_successful_delivery_at': '2026-08-14T08:55:00Z',
  },
  'settings': [
    _setting(
      'company.legal_name',
      'company_regional',
      'Yorks Air Conditioning & Refrigeration LLC-SPC',
    ),
    _setting('company.short_name', 'company_regional', 'Yorks AC. & Ref.'),
    _setting(
      'company.arabic_name',
      'company_regional',
      'يوركس للتكييف والتبريد',
    ),
    _setting(
      'company.workspace_name',
      'company_regional',
      'Yorks Project & Material Management',
    ),
    _setting('regional.country', 'company_regional', 'United Arab Emirates'),
    _setting('regional.timezone', 'company_regional', 'Asia/Dubai'),
    _setting('regional.date_format', 'company_regional', 'DD-MM-YYYY'),
    _setting('regional.currency', 'company_regional', 'AED'),
    _setting('regional.primary_language', 'company_regional', 'English'),
    _setting('regional.secondary_language', 'company_regional', 'Arabic'),
    _setting('regional.financial_year_start', 'company_regional', '1 January'),
    _setting('requests.default_timing', 'material_requests', 'normal'),
    _setting('requests.urgent_enabled', 'material_requests', true),
    _setting(
      'requests.allow_authorized_creator_self_approval',
      'material_requests',
      true,
    ),
    _setting(
      'procurement.default_source',
      'procurement_inventory',
      'warehouse',
    ),
    _setting(
      'procurement.require_external_source_readiness',
      'procurement_inventory',
      false,
    ),
    _setting('accounts.billing_stage_weights', 'accounts', {
      'design': 10,
      'material_supply': 50,
      'installation': 30,
      'commissioning_handover': 5,
      'energizing': 5,
    }),
    _setting('accounts.payment_terms_days', 'accounts', 90),
    _setting('accounts.pdc_reminder_days', 'accounts', 10),
    _setting('documents.maximum_file_size_mb', 'documents_printing', 20),
    _setting('documents.retention_years', 'documents_printing', 7),
    _setting('documents.allowed_formats', 'documents_printing', [
      'PDF',
      'DOCX',
      'XLSX',
    ]),
    _setting('documents.bilingual_header', 'documents_printing', true),
    _setting(
      'notifications.push_enabled',
      'notifications',
      false,
      draftValue: false,
      changed: true,
    ),
    _setting('notifications.email_enabled', 'notifications', false),
    _setting('security.session_timeout_hours', 'security_audit', 8),
    _setting('security.minimum_password_length', 'security_audit', 10),
    _setting('security.admin_mfa_required', 'security_audit', false),
    _setting('security.log_exports', 'security_audit', true),
    _setting('security.log_access_changes', 'security_audit', true),
    _setting('security.audit_retention_years', 'security_audit', 7),
    _setting(
      'numbering.project_pattern',
      'numbering_data',
      'Admin-controlled unique reference',
    ),
    _setting(
      'numbering.material_request_pattern',
      'numbering_data',
      '{PROJECT_REF}-MR{NNN}',
    ),
    _setting(
      'numbering.dispatch_pattern',
      'numbering_data',
      '{PROJECT_REF}-DSP{NNN}',
    ),
    _setting(
      'numbering.return_pattern',
      'numbering_data',
      '{PROJECT_REF}-RTN{NNN}',
    ),
    _setting(
      'numbering.invoice_pattern',
      'numbering_data',
      'INV-{PROJECT}-{###}',
    ),
  ],
  'master_actions': [],
  'material_categories': [
    {
      'id': '41000000-0000-4000-8000-000000000001',
      'name': 'Air Terminals',
      'is_system': true,
      'is_active': true,
      'item_count': 12,
    },
  ],
  'material_units': [
    {
      'id': 'c3810000-0000-4000-8000-000000000001',
      'name': 'Number',
      'short_code': 'Nos',
      'unit_type': 'count',
      'decimal_places': 0,
      'is_system': true,
      'is_active': true,
    },
  ],
  'boq_group_templates': [
    {
      'template_key': 'ac_units',
      'display_name': 'AC Units',
      'display_order': 1,
      'is_frozen': true,
      'is_active': true,
    },
    {
      'template_key': 'ventilation_fans',
      'display_name': 'Ventilation Fans',
      'display_order': 2,
      'is_frozen': true,
      'is_active': true,
    },
  ],
  'history': [
    {
      'id': 'c3800000-0000-4000-8000-000000000004',
      'version_number': 4,
      'version_label': 'v1.3.0',
      'reason': 'Aligned request approval and notification rules',
      'affected_areas': ['material_requests', 'notifications'],
      'published_at': '2026-08-13T18:40:00Z',
      'published_by': 'Khaled S. Sleiman',
      'published_by_exact_role': 'admin',
      'change_count': 7,
    },
  ],
  'validation': {
    'status': 'recommendations',
    'blocking': [],
    'recommendations': [
      {
        'code': 'admin_mfa_recommended',
        'area': 'security_audit',
        'message': 'Admin MFA is not enabled.',
      },
    ],
  },
};

Map<String, dynamic> _setting(
  String key,
  String area,
  Object value, {
  Object? draftValue,
  bool changed = false,
}) => {
  'key': key,
  'area': area,
  'type': value is bool
      ? 'boolean'
      : value is num
      ? 'integer'
      : value is List
      ? 'string_array'
      : value is Map
      ? 'weights'
      : 'string',
  'published_value': value,
  'draft_value': draftValue,
  'effective_value': draftValue ?? value,
  'changed': changed,
  'control_mode': _configurationControlMode(key),
  'impact_scope': [area],
  'enforcement_target': _configurationEnforcementTarget(key),
  if (changed) 'staged_by': 'Owner · Admin',
  if (changed) 'staged_at': '2026-08-14T09:00:00Z',
};

String _configurationControlMode(String key) {
  const operational = {
    'requests.default_timing',
    'requests.urgent_enabled',
    'requests.allow_authorized_creator_self_approval',
    'procurement.require_external_source_readiness',
    'notifications.push_enabled',
  };
  const protected = {
    'regional.currency',
    'procurement.default_source',
    'documents.maximum_file_size_mb',
    'documents.allowed_formats',
    'documents.bilingual_header',
    'security.log_exports',
    'security.log_access_changes',
  };
  if (operational.contains(key)) return 'operational';
  if (key.startsWith('company.') ||
      key.startsWith('numbering.') ||
      protected.contains(key)) {
    return 'protected';
  }
  return 'planned';
}

String _configurationEnforcementTarget(String key) => switch (key) {
  'requests.default_timing' => 'mr_draft_default_timing',
  'requests.urgent_enabled' => 'mr_urgent_submission_guard',
  'requests.allow_authorized_creator_self_approval' => 'mr_self_approval_guard',
  'procurement.require_external_source_readiness' =>
    'procurement_external_readiness_guard',
  'notifications.push_enabled' => 'notification_push_outbox',
  _ when key.startsWith('company.') => 'controlled_document_identity',
  'regional.currency' => 'aed_commercial_boundary',
  'procurement.default_source' => 'warehouse_first_arrangement',
  'documents.maximum_file_size_mb' ||
  'documents.allowed_formats' ||
  'documents.bilingual_header' => 'storage_document_contract',
  'security.log_exports' ||
  'security.log_access_changes' => 'append_only_audit_contract',
  _ when key.startsWith('numbering.') => 'trusted_server_numbering',
  _ when _configurationControlMode(key) == 'protected' => 'product_invariant',
  _ => 'retained_reference',
};
