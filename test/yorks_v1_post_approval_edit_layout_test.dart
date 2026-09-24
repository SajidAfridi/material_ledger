import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';

import 'support/yorks_v1_permission_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    var directory = File(Platform.resolvedExecutable).parent;
    while (!directory.path.endsWith('${Platform.pathSeparator}cache') &&
        directory.path != directory.parent.path) {
      directory = directory.parent;
    }
    final bytes = await File(
      '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await Future.wait([font.load(), arabic.load(), icons.load()]);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scenario in [
    (
      name: 'named procurement',
      role: YorksV1Role.procurement,
      manage: false,
      enabled: true,
    ),
    (
      name: 'ungranted procurement',
      role: YorksV1Role.procurement,
      manage: false,
      enabled: false,
    ),
    (
      name: 'approver closed window',
      role: YorksV1Role.admin,
      manage: true,
      enabled: false,
    ),
    (
      name: 'approver delegated window',
      role: YorksV1Role.admin,
      manage: true,
      enabled: true,
    ),
  ]) {
    testWidgets('request header permissions and responsive order: ${scenario.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var version = 4;
      YorksV1MaterialRequest makeRequest(bool enabled, String? editor) =>
          YorksV1MaterialRequest(
            id: 'post-edit-layout',
            projectId: 'project-layout',
            projectReference: 'YRA-123',
            projectName: 'Yorks Tower',
            scopeId: 'scope-layout',
            scopeName: 'Main Building',
            state: YorksV1MaterialRequestState.approvedForArrangement,
            recordVersion: version,
            createdAt: DateTime.utc(2026, 9, 24),
            updatedAt: DateTime.utc(2026, 9, 24),
            timing: YorksV1MaterialRequestTiming.normal,
            requestNumber: 'YRA123-MR102',
            postApprovalEditEnabled: enabled,
            procurementEditorAuthUserId: editor,
            canManagePostApprovalEdit: scenario.manage,
            canEditBeforeApproval: false,
            canEditPostApproval:
                enabled && (scenario.manage || editor == 'procurement-user'),
            lines: const [
              YorksV1MaterialRequestLine(
                id: 'line-layout',
                displayOrder: 1,
                source: YorksV1MaterialRequestLineSource.custom,
                description: 'Duct fitting',
                quantity: '3',
                unit: 'Nos',
              ),
            ],
          );
      final request = makeRequest(
        scenario.enabled,
        scenario.enabled ? 'procurement-user' : null,
      );
      final repository = _EditingRepository(request, (enabled, editor) {
        version++;
        return makeRequest(enabled, editor);
      });
      final workspace = YorksV1ArrangementWorkspace(
        requestId: request.id,
        requestState: 'approved_for_arrangement',
        requestRecordVersion: 4,
        canBegin: true,
        canSave: false,
        canDecide: false,
        arrangements: const [],
      );
      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: YorksV1MaterialRequestDetailScreen(
                requestId: 'post-edit-layout',
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
              repository,
            ),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(
                foundation: true,
                projects: true,
                boq: true,
                excel: true,
                requests: true,
                arrangement: true,
              ),
            ),
            yorksV1CurrentPermissionSnapshotProvider.overrideWith(
              (ref) => YorksV1TestPermissionController(
                yorksV1TrustedFeaturePermissionState(role: scenario.role),
              ),
            ),
            yorksV1CurrentRoleProvider.overrideWithValue(scenario.role),
            yorksV1MaterialRequestDetailProvider(
              request.id,
            ).overrideWith((ref) async => repository.request),
            yorksV1MaterialRequestDocumentProvider(request.id).overrideWith(
              (ref) async =>
                  YorksV1MaterialRequestDocumentModel.fromRequest(request),
            ),
            yorksV1ArrangementWorkspaceProvider(
              request.id,
            ).overrideWith((ref) async => workspace),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/logo.png'),
          tester.element(find.byType(MaterialApp)),
        );
      });
      await tester.pumpAndSettle();

      final actions = find.byKey(
        const ValueKey('material-request-workflow-actions'),
      );
      expect(
        find.descendant(of: actions, matching: find.text('Edit request')),
        scenario.enabled || scenario.manage ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: actions, matching: find.text('Arrange Items')),
        findsOneWidget,
      );
      final switchFinder = find.byKey(
        const ValueKey('material-request-procurement-edit-switch'),
      );
      expect(switchFinder, scenario.manage ? findsOneWidget : findsNothing);
      if (scenario.enabled || scenario.manage) {
        expect(
          tester.getCenter(find.text('Edit request')).dx,
          lessThan(tester.getCenter(find.text('Arrange Items')).dx),
        );
      }
      if (scenario.manage) {
        expect(
          tester
              .getCenter(
                find.byKey(const ValueKey('material-request-cancel-action')),
              )
              .dx,
          lessThan(tester.getCenter(find.text('Edit request')).dx),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/r35/mr_record_${scenario.enabled ? 'delegated' : 'closed'}_desktop.png',
          ),
        );
        if (!scenario.enabled) {
          await tester.tap(find.text('Edit request'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(repository.calls, isEmpty);
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
          expect(repository.calls, isEmpty);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Save access'),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Procurement Editor').last);
          await tester.pumpAndSettle();
          repository.pending = Completer<void>();
          await tester.tap(find.text('Save access'));
          await tester.pump();
          expect(tester.widget<Switch>(switchFinder).value, isFalse);
          expect(tester.widget<Switch>(switchFinder).onChanged, isNull);
          repository.pending!.complete();
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(switchFinder).value, isTrue);
          expect(repository.calls.single.editor, 'procurement-user');
          expect(repository.calls.single.version, 4);
          repository.pending = null;
        }
        repository.fail = true;
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
        await tester.pump(const Duration(seconds: 6));
        repository.fail = false;
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
        expect(repository.request.postApprovalEditEnabled, isTrue);
        expect(repository.request.procurementEditorAuthUserId, isNull);
      }
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(820, 1180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario.manage) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/r35/mr_record_${scenario.enabled ? 'delegated' : 'closed'}_tablet.png',
          ),
        );
      }
      tester.view.physicalSize = const Size(360, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const ValueKey('mobile-mr-request-approval-actions')),
        scenario.enabled || scenario.manage ? findsOneWidget : findsNothing,
      );
      expect(find.text('Arrange Items'), findsWidgets);
      expect(
        find.text('Edit request'),
        scenario.enabled || scenario.manage ? findsWidgets : findsNothing,
      );
      if (scenario.manage) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/r35/mr_record_${scenario.enabled ? 'delegated' : 'closed'}_mobile.png',
          ),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _EditingRepository
    implements
        YorksV1MaterialRequestRepository,
        YorksV1MaterialRequestPostApprovalEditRepository {
  _EditingRepository(this.request, this.update);
  YorksV1MaterialRequest request;
  final YorksV1MaterialRequest Function(bool, String?) update;
  Completer<void>? pending;
  bool fail = false;
  final calls = <({bool enabled, String? editor, int version})>[];
  @override
  Future<List<YorksV1MaterialRequestMention>> listProcurementEditors(
    String requestId,
  ) async => const [
    YorksV1MaterialRequestMention(
      authUserId: 'procurement-user',
      displayName: 'Procurement Editor',
      exactRole: 'procurement',
    ),
  ];
  @override
  Future<YorksV1MaterialRequest> setPostApprovalEdit({
    required String requestId,
    required int expectedVersion,
    required bool enabled,
    String? procurementEditorAuthUserId,
    required String idempotencyKey,
  }) async {
    calls.add((
      enabled: enabled,
      editor: procurementEditorAuthUserId,
      version: expectedVersion,
    ));
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Server rejected grant');
    request = update(enabled, procurementEditorAuthUserId);
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
