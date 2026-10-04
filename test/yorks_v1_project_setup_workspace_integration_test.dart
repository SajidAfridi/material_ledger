import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_navigation_history.dart';
import 'package:material_ledger/app/yorks_v1_workspace_search.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/constants/app_spacing.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/yorks_mobile_ui.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_project_create_flow_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_project.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_setup_operation.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_creation_draft.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_setup_shell_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_search.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_creation_draft_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_reference_advisory_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_setup_navigation_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_team_directory_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_search_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_draft_storage_native.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_repository.dart';
import 'package:material_ledger/shared/widgets/notification_bell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/yorks_v1_permission_test_support.dart';

const _owner = 'workspace-setup-test-owner';
const _navigationKey = ValueKey('project-setup-workspace-navigation');
const _searchKey = ValueKey('project-setup-workspace-search');
const _drawerKey = ValueKey('yorks-workspace-navigation-drawer');
const _sidebarToggleKey = ValueKey('yorks-workspace-sidebar-toggle');
const _saveDraftKey = ValueKey('project-setup-save-draft');
const _engineerCapabilities = <String>{
  YorksV1CapabilityKeys.projectsView,
  YorksV1CapabilityKeys.projectsCreate,
  YorksV1CapabilityKeys.projectsEdit,
  YorksV1CapabilityKeys.materialRequestsView,
};
const _canonicalEngineerPaths = <String>{
  RoutePaths.engineerHome,
  RoutePaths.yorksV1Projects,
  RoutePaths.yorksV1MaterialRequests,
  RoutePaths.yorksV1DuctSizer,
  RoutePaths.yorksV1EspCalculator,
};

void main() {
  setUpAll(() async {
    final font = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await font.load();
  });

  for (final size in [
    const Size(1536, 1024),
    const Size(1366, 768),
    const Size(1280, 800),
    const Size(360, 800),
  ]) {
    final desktop = size.width >= AppSpacing.yorksV1ShellDesktopBreakpoint;
    final wideContent = size.width - AppSpacing.sidebarWidth >= 1100;
    final platform = desktop
        ? 'desktop ${size.width.toInt()}x${size.height.toInt()}'
        : 'phone ${size.width.toInt()}x${size.height.toInt()}';

    testWidgets(
      '$platform Projects opens setup inside the original workspace chrome',
      (tester) async {
        final fixture = await _pumpWorkspace(
          tester,
          size: size,
          initialLocation: RoutePaths.yorksV1Projects,
        );
        final originalHeader = desktop
            ? tester.getRect(find.byKey(_sidebarToggleKey))
            : tester.getRect(find.byType(YorksMobileAppBar));
        await _openCreateProject(tester);
        final shell = find.byKey(
          ValueKey('project-setup-${wideContent ? 'desktop' : 'mobile'}-shell'),
        );
        expect(find.byType(YorksV1ProjectCreateFlowScreen), findsOneWidget);
        expect(find.byKey(_navigationKey), findsNothing);
        expect(find.byKey(_searchKey), findsNothing);
        expect(
          find.byKey(const ValueKey('project-setup-mobile-header')),
          findsNothing,
        );
        expect(find.byKey(_drawerKey), findsNothing);
        expect(find.byKey(_saveDraftKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        if (desktop) {
          expect(find.byKey(_sidebarToggleKey), findsOneWidget);
          expect(tester.getRect(find.byKey(_sidebarToggleKey)), originalHeader);
          expect(find.byType(NotificationBell), findsOneWidget);
          expect(
            find.text(YorksV1ShellStrings.companyName.primary),
            findsNWidgets(2),
          );
          expect(
            find.text(YorksV1ShellStrings.companyLegalName.primary),
            findsOneWidget,
          );
          _expectEngineerNavigation(_sidebarSurface());
          expect(
            tester.getRect(shell),
            Rect.fromLTWH(
              AppSpacing.sidebarWidth,
              AppSpacing.topBarHeight,
              size.width - AppSpacing.sidebarWidth,
              size.height - AppSpacing.topBarHeight,
            ),
          );
          if (wideContent) {
            final rail = tester.getRect(
              find.byKey(const ValueKey('project-setup-desktop-rail')),
            );
            expect(rail.left, AppSpacing.sidebarWidth);
            expect(rail.top, AppSpacing.topBarHeight);
            expect(rail.right, lessThan(tester.getRect(shell).right));
          } else {
            expect(
              find.byKey(const ValueKey('project-setup-desktop-rail')),
              findsNothing,
            );
          }
          // Collapsing the universal sidebar changes its own width. The
          // project stage rail stays inside the work area and never takes over
          // the application's left edge.
          await tester.tap(find.byKey(_sidebarToggleKey));
          await tester.pumpAndSettle();
          expect(fixture.container.read(yorksV1SidebarExpandedProvider), false);
          final collapsedContent = find.byKey(
            const ValueKey('project-setup-desktop-shell'),
          );
          expect(
            tester.getRect(collapsedContent).left,
            AppSpacing.sidebarCollapsedWidth,
          );
          expect(
            tester
                .getRect(
                  find.byKey(const ValueKey('project-setup-desktop-rail')),
                )
                .left,
            AppSpacing.sidebarCollapsedWidth,
          );
          expect(find.byKey(_sidebarToggleKey), findsOneWidget);
          expect(find.byType(NotificationBell), findsOneWidget);
          await tester.tap(find.byKey(_sidebarToggleKey));
          await tester.pumpAndSettle();
          expect(fixture.container.read(yorksV1SidebarExpandedProvider), true);
          _expectEngineerNavigation(_sidebarSurface());
        } else {
          expect(find.byKey(_sidebarToggleKey), findsNothing);
          expect(find.byType(YorksMobileAppBar), findsOneWidget);
          expect(
            tester.getRect(find.byType(YorksMobileAppBar)),
            originalHeader,
          );
          final header = tester.getRect(find.byType(YorksMobileAppBar));
          expect(tester.getRect(shell).top, header.bottom);
          expect(tester.getRect(shell).width, size.width);
          // The canonical workspace intentionally omits bottom navigation for
          // focused setup routes so it cannot cover the feature's fixed actions.
          expect(
            find.byKey(const ValueKey('yorks-mobile-navigation')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('yorks-compact-navigation-legacy')),
            findsNothing,
          );
        }
        expect(
          fixture.container.read(yorksNavigationHistoryProvider).locations,
          [RoutePaths.yorksV1Projects, RoutePaths.engineerCreateProject],
        );
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform shared search retains permitted canonical destinations',
      (tester) async {
        final fixture = await _pumpWorkspace(tester, size: size);
        // Ctrl+K belongs to the universal shell on every viewport, not a
        // replacement search widget built by project setup.
        await _openWorkspaceSearch(tester);
        final dialog = tester.widget<YorksV1WorkspaceSearchDialog>(
          find.byType(YorksV1WorkspaceSearchDialog),
        );
        expect(
          dialog.targets.map((target) => target.path).toSet(),
          _canonicalEngineerPaths,
        );
        expect(
          dialog.targets.map((target) => target.path),
          isNot(contains(RoutePaths.users)),
        );
        _expectEngineerNavigation(find.byType(YorksV1WorkspaceSearchDialog));
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform workspace navigation guards automatic-only draft and resumes it',
      (tester) async {
        final fixture = await _pumpWorkspace(tester, size: size);
        final originalDraftId = fixture.container
            .read(yorksV1ProjectSetupCreationDraftProvider(_owner))
            .draftId;
        const proposedName =
            'Unpublished proposal preserved through navigation';
        await tester.enterText(
          find.byKey(const ValueKey('yorks-v1-project-name')),
          proposedName,
        );
        if (desktop) {
          await tester.tap(
            find.descendant(
              of: _sidebarSurface(),
              matching: find.text(YorksV1ShellStrings.projects.primary),
            ),
          );
        } else {
          await tester.tap(
            find
                .text(YorksV1ProjectSetupShellStrings.returnToProjects.primary)
                .first,
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.text(YorksV1ProjectStrings.leaveSetupTitle.primary),
          findsOneWidget,
        );
        expect(
          fixture.router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.engineerCreateProject,
        );
        await tester.tap(find.text(YorksV1ProjectStrings.keepWorking.primary));
        await tester.pumpAndSettle();
        expect(find.byType(YorksV1ProjectCreateFlowScreen), findsOneWidget);
        expect(
          fixture.router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.engineerCreateProject,
        );
        if (desktop) {
          await tester.tap(
            find.descendant(
              of: _sidebarSurface(),
              matching: find.text(YorksV1ShellStrings.projects.primary),
            ),
          );
        } else {
          await tester.tap(
            find
                .text(YorksV1ProjectSetupShellStrings.returnToProjects.primary)
                .first,
          );
        }
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(YorksV1ProjectStrings.leaveWithSavedDraft.primary),
        );
        await tester.pumpAndSettle();
        _expectPortfolio(fixture);
        final draft = fixture.container.read(
          yorksV1ProjectSetupCreationDraftProvider(_owner),
        );
        expect(draft.name, proposedName);
        expect(draft.storageState, YorksV1ProjectDraftStorageState.saved);
        expect(draft.acknowledgedRevision, draft.revision);

        await _openCreateProject(tester);
        _expectResumedDraft(tester, fixture, originalDraftId, proposedName);
        expect(
          fixture.container.read(yorksNavigationHistoryProvider).locations,
          [
            RoutePaths.engineerCreateProject,
            RoutePaths.yorksV1Projects,
            RoutePaths.engineerCreateProject,
          ],
        );
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform explicit Save draft acknowledges storage and Back resumes that draft',
      (tester) async {
        final fixture = await _pumpWorkspace(
          tester,
          size: size,
          initialLocation: RoutePaths.yorksV1Projects,
        );
        await _openCreateProject(tester);
        final originalDraftId = fixture.container
            .read(yorksV1ProjectSetupCreationDraftProvider(_owner))
            .draftId;
        const proposedName = 'Explicitly saved inside Yorks workspace';
        await tester.enterText(
          find.byKey(const ValueKey('yorks-v1-project-name')),
          proposedName,
        );
        await tester.tap(find.byKey(_saveDraftKey));
        await tester.pumpAndSettle();
        final saved = fixture.container.read(
          yorksV1ProjectSetupCreationDraftProvider(_owner),
        );
        expect(saved.storageState, YorksV1ProjectDraftStorageState.saved);
        expect(saved.acknowledgedRevision, saved.revision);
        expect(
          find.text(YorksV1ProjectStrings.draftSaved.primary),
          findsOneWidget,
        );
        final storageKey = yorksV1ProjectDraftStorageKey(
          backendIdentity: fixture.container.read(
            yorksV1ProjectDraftBackendIdentityProvider,
          ),
          ownerAuthUserId: _owner,
          mode: YorksV1ProjectDraftMode.create,
        );
        final stored = fixture.preferences.getString(storageKey);
        expect(stored, isNotNull);
        final envelope = jsonDecode(stored!) as Map<String, dynamic>;
        final restored = YorksV1ProjectCreationDraft.fromJson(
          Map<String, dynamic>.from(envelope['draft'] as Map),
        );
        expect(restored.draftId, originalDraftId);
        expect(restored.name, proposedName);

        // Match the reported Save draft -> Back to projects sequence. A
        // confirmed explicit save of unchanged input needs no leave warning.
        await tester.tap(
          find
              .text(YorksV1ProjectSetupShellStrings.returnToProjects.primary)
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(YorksV1ProjectStrings.leaveSetupTitle.primary),
          findsNothing,
        );
        _expectPortfolio(fixture);
        await _openCreateProject(tester);
        _expectResumedDraft(tester, fixture, originalDraftId, proposedName);
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manual save and unfinished input survive desktop phone and transient viewport resize',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        initialLocation: RoutePaths.yorksV1Projects,
      );
      await _openCreateProject(tester);
      final flowState = tester.state(
        find.byType(YorksV1ProjectCreateFlowScreen),
      );
      final draftId = fixture.container
          .read(yorksV1ProjectSetupCreationDraftProvider(_owner))
          .draftId;
      const proposedName = 'Viewport recovery preserves the saved proposal';
      const partialDate = '12/10/';
      const notes = 'Unpublished notes remain local through every layout.';
      await tester.enterText(
        find.byKey(const ValueKey('yorks-v1-project-name')),
        proposedName,
      );
      final date = find.byKey(
        ValueKey('yorks-v1-project-date-${YorksV1ProjectStrings.startDate.en}'),
      );
      await tester.ensureVisible(date);
      await tester.enterText(date, partialDate);
      final notesField = find.byKey(const ValueKey('yorks-v1-project-notes'));
      await tester.ensureVisible(notesField);
      await tester.enterText(notesField, notes);
      await tester.tap(find.byKey(_saveDraftKey));
      await tester.pumpAndSettle();
      expect(
        find.text(YorksV1ProjectStrings.draftSaved.primary),
        findsOneWidget,
      );
      final saved = fixture.container.read(
        yorksV1ProjectSetupCreationDraftProvider(_owner),
      );
      expect(saved.isAcknowledged, true);
      expect(saved.rawEditorState['dateStartText'], partialDate);
      final notesEditor = tester.widget<EditableText>(
        find.descendant(of: notesField, matching: find.byType(EditableText)),
      );
      final controller = notesEditor.controller;
      final focusNode = notesEditor.focusNode;
      const selection = TextSelection(baseOffset: 4, extentOffset: 15);
      controller.selection = selection;
      focusNode.requestFocus();
      await tester.pump();

      for (final size in const [Size(360, 800), Size(1, 1), Size(1536, 1024)]) {
        await _resizeWorkspace(tester, size);
        expect(
          tester.state(find.byType(YorksV1ProjectCreateFlowScreen)),
          same(flowState),
        );
        final current = fixture.container.read(
          yorksV1ProjectSetupCreationDraftProvider(_owner),
        );
        expect(current.draftId, draftId);
        expect(current.name, proposedName);
        expect(current.notes, notes);
        expect(current.rawEditorState['dateStartText'], partialDate);
        expect(current.isAcknowledged, true);
        expect(tester.takeException(), isNull);
      }
      final resumedEditor = tester.widget<EditableText>(
        find.descendant(of: notesField, matching: find.byType(EditableText)),
      );
      expect(resumedEditor.controller, same(controller));
      expect(resumedEditor.focusNode, same(focusNode));
      expect(controller.selection, selection);
      expect(controller.text, notes);
      // The temporarily hidden 1×1 body has no keyboard target. Its original
      // focus node remains usable once the real viewport returns.
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, true);

      await tester.tap(
        find
            .text(YorksV1ProjectSetupShellStrings.returnToProjects.primary)
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(YorksV1ProjectStrings.leaveSetupTitle.primary),
        findsNothing,
      );
      _expectPortfolio(fixture);
      await _openCreateProject(tester);
      _expectResumedDraft(tester, fixture, draftId, proposedName);
      final restored = fixture.container.read(
        yorksV1ProjectSetupCreationDraftProvider(_owner),
      );
      expect(restored.rawEditorState['dateStartText'], partialDate);
      expect(restored.notes, notes);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'universal desktop Back keeps rejected draft exit history and resumes with Forward',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        initialLocation: RoutePaths.yorksV1Projects,
      );
      await _openCreateProject(tester);
      final originalDraftId = fixture.container
          .read(yorksV1ProjectSetupCreationDraftProvider(_owner))
          .draftId;
      const proposedName = 'Guarded universal history proposal';
      await tester.enterText(
        find.byKey(const ValueKey('yorks-v1-project-name')),
        proposedName,
      );
      final before = fixture.container.read(yorksNavigationHistoryProvider);
      await tester.tap(find.byKey(const ValueKey('yorks-workspace-back')));
      await tester.pumpAndSettle();
      expect(
        find.text(YorksV1ProjectStrings.leaveSetupTitle.primary),
        findsOneWidget,
      );
      await tester.tap(find.text(YorksV1ProjectStrings.keepWorking.primary));
      await tester.pumpAndSettle();
      expect(
        fixture.router.routerDelegate.currentConfiguration.last.matchedLocation,
        RoutePaths.engineerCreateProject,
      );
      final retained = fixture.container.read(yorksNavigationHistoryProvider);
      expect(retained.locations, before.locations);
      expect(retained.cursor, before.cursor);
      expect(
        find.byKey(const ValueKey('yorks-workspace-sidebar-toggle')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('yorks-workspace-back')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(YorksV1ProjectStrings.leaveWithSavedDraft.primary),
      );
      await tester.pumpAndSettle();
      _expectPortfolio(fixture);
      await tester.tap(find.byKey(const ValueKey('yorks-workspace-forward')));
      await tester.pumpAndSettle();
      _expectResumedDraft(tester, fixture, originalDraftId, proposedName);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connected loading permissions expose only verification, never the setup feature',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        permission: const YorksV1CurrentPermissionSnapshotState(
          isInitialLoading: true,
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey('yorks-permission-verification-shell')),
        findsOneWidget,
      );
      expect(find.byType(YorksV1ProjectCreateFlowScreen), findsNothing);
      expect(find.byKey(const ValueKey('yorks-v1-project-name')), findsNothing);
      expect(find.byKey(_navigationKey), findsNothing);
      expect(find.byKey(_searchKey), findsNothing);
      expect(find.byKey(_drawerKey), findsNothing);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1536, 1024), const Size(360, 800)]) {
    for (final historical in ['files', 'activation', 'pointer', 'uncertain']) {
      testWidgets(
        historical == 'uncertain'
            ? '${size.width} Projects Create retains uncertain core intent without replay'
            : '${size.width} Projects Create starts fresh after historical confirmed $historical recovery',
        (tester) async {
          late YorksV1ProjectCreationDraft oldDraft;
          late String storageKey;
          late String originalJournal;
          late String retiredJson;
          final fixture = await _pumpWorkspace(
            tester,
            size: size,
            initialLocation: RoutePaths.yorksV1Projects,
            seed: (container, preferences) async {
              final provider = yorksV1ProjectSetupCreationDraftProvider(_owner);
              final notifier = container.read(provider.notifier);
              await notifier.initialized;
              await notifier.save(
                container
                    .read(provider)
                    .copyWith(
                      reference: 'OLD-CONFIRMED',
                      name: 'Old created project',
                      currentStage: YorksV1ProjectCreationStage.reviewAndCreate,
                      buildings: const [
                        YorksV1ProjectBuildingInput(
                          name: 'Old physical building',
                        ),
                      ],
                      attachments: const [
                        YorksV1ProjectAttachmentInput(
                          localId: 'old-file',
                          fileName: 'private-old-plan.pdf',
                          mimeType: 'application/pdf',
                          sizeBytes: 4,
                        ),
                      ],
                      rawEditorState: const {
                        'private_unfinished_text':
                            'Retain original private recovery',
                      },
                    ),
              );
              oldDraft = container.read(provider);
              storageKey = notifier.storageKey;
              final core = YorksV1ProjectSetupCommand(
                kind: YorksV1ProjectSetupCommandKind.create,
                idempotencyKey: oldDraft.creationIdempotencyKey,
                payload: oldDraft.toCreationInput().toRpcPayload(),
                status: historical == 'uncertain'
                    ? YorksV1ProjectSetupCommandStatus.outcomeUncertain
                    : YorksV1ProjectSetupCommandStatus.confirmedSuccess,
                attempts: 1,
                result: historical == 'uncertain'
                    ? null
                    : {
                        'project': {
                          'id': 'old-confirmed-project',
                          'reference': oldDraft.reference,
                          'name': oldDraft.name,
                          'state': 'draft',
                          'record_version': 0,
                          'created_at': '2026-10-04T00:00:00Z',
                        },
                        'idempotency_key': oldDraft.creationIdempotencyKey,
                      },
              );
              final operation = YorksV1ProjectSetupOperation(
                backendIdentity: oldDraft.backendIdentity,
                ownerAuthUserId: _owner,
                draftId: oldDraft.draftId,
                mode: YorksV1ProjectSetupMode.create,
                core: core,
                activation: historical == 'activation'
                    ? YorksV1ProjectSetupCommand(
                        kind: YorksV1ProjectSetupCommandKind.activate,
                        idempotencyKey: 'old-activation-intent',
                        payload: {
                          'project_id': 'old-confirmed-project',
                          'expected_version': 0,
                          'target_state': 'active',
                        },
                        status:
                            YorksV1ProjectSetupCommandStatus.outcomeUncertain,
                        attempts: 1,
                      )
                    : null,
                files: const [
                  YorksV1ProjectSetupFile(
                    localId: 'old-file',
                    idempotencyKey: 'old-file-intent',
                    fileName: 'private-old-plan.pdf',
                    mimeType: 'application/pdf',
                    sizeBytes: 4,
                    classification: YorksV1DocumentClassification.operational,
                  ),
                ],
              );
              originalJournal = jsonEncode(operation.toJson());
              await preferences.setString(
                '$storageKey:journal:${oldDraft.draftId}',
                originalJournal,
              );
              await preferences.setString(
                '$storageKey:latest_operation',
                jsonEncode({
                  'journal_key': '$storageKey:journal:${oldDraft.draftId}',
                }),
              );
              if (historical == 'pointer') {
                await notifier.retire(resultProjectId: 'old-confirmed-project');
                container.invalidate(provider);
                await container.read(provider.notifier).initialized;
                retiredJson = preferences.getString(
                  '$storageKey:retired:${oldDraft.draftId}',
                )!;
              }
            },
          );
          await _openCreateProject(tester);
          final provider = yorksV1ProjectSetupCreationDraftProvider(_owner);
          final fresh = fixture.container.read(provider);
          if (historical == 'uncertain') {
            expect(fresh.draftId, oldDraft.draftId);
            expect(
              fresh.creationIdempotencyKey,
              oldDraft.creationIdempotencyKey,
            );
            expect(fresh.reference, oldDraft.reference);
            expect(
              find.byKey(const ValueKey('yorks-v1-project-operation-outcome')),
              findsOneWidget,
            );
            expect(
              find.text(YorksV1ProjectStrings.checkSavedStatus.primary),
              findsWidgets,
            );
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('yorks-v1-project-create')),
                matching: find.text(
                  YorksV1ProjectStrings.createProject.primary,
                ),
              ),
              findsNothing,
            );
            expect(
              fixture.preferences.getString(
                '$storageKey:journal:${oldDraft.draftId}',
              ),
              originalJournal,
            );
            expect(
              fixture.preferences.getString(
                '$storageKey:retired:${oldDraft.draftId}',
              ),
              isNull,
            );
            expect(fixture.commands.calls, 0);
            expect(tester.takeException(), isNull);
            return;
          }
          expect(fresh.draftId, isNot(oldDraft.draftId));
          expect(
            fresh.creationIdempotencyKey,
            isNot(oldDraft.creationIdempotencyKey),
          );
          expect(
            fresh.currentStage,
            YorksV1ProjectCreationStage.projectDetails,
          );
          expect(fresh.reference, isEmpty);
          expect(fresh.name, isEmpty);
          expect(fresh.buildings, isEmpty);
          expect(fresh.attachments, isEmpty);
          expect(fresh.rawEditorState, isEmpty);
          expect(
            fixture
                .router
                .routerDelegate
                .currentConfiguration
                .last
                .matchedLocation,
            RoutePaths.engineerCreateProject,
          );
          final name = tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('yorks-v1-project-name')),
              matching: find.byType(EditableText),
            ),
          );
          expect(name.controller.text, isEmpty);
          expect(find.textContaining('Old created project'), findsNothing);
          expect(
            find.byKey(const ValueKey('yorks-v1-project-operation-outcome')),
            findsNothing,
          );
          expect(
            find.text(YorksV1ProjectStrings.projectCreated.primary),
            findsNothing,
          );
          expect(
            fixture.preferences.getString(
              '$storageKey:journal:${oldDraft.draftId}',
            ),
            originalJournal,
          );
          final retired = fixture.preferences.getString(
            '$storageKey:retired:${oldDraft.draftId}',
          )!;
          if (historical == 'pointer') expect(retired, retiredJson);
          final retainedDraft = YorksV1ProjectCreationDraft.fromJson(
            Map<String, dynamic>.from(
              (jsonDecode(retired) as Map)['draft'] as Map,
            ),
          );
          expect(retainedDraft.draftId, oldDraft.draftId);
          expect(retainedDraft.attachments.single.localId, 'old-file');
          expect(
            retainedDraft.rawEditorState['private_unfinished_text'],
            'Retain original private recovery',
          );
          expect(fixture.commands.calls, 0);
          await tester.tap(
            find
                .text(YorksV1ProjectSetupShellStrings.returnToProjects.primary)
                .first,
          );
          await tester.pumpAndSettle();
          _expectPortfolio(fixture);
          await _openCreateProject(tester);
          expect(fixture.container.read(provider).draftId, fresh.draftId);
          expect(fixture.container.read(provider).name, isEmpty);
          expect(
            fixture.preferences.getString(
              '$storageKey:journal:${oldDraft.draftId}',
            ),
            originalJournal,
          );
          expect(fixture.commands.calls, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'confirmed create denial cannot expose an editor inside the universal workspace',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        permission: yorksV1TrustedFeaturePermissionState(
          role: YorksV1Role.projectEngineer,
          capabilities: const {YorksV1CapabilityKeys.projectsView},
        ),
      );
      expect(
        find.text(YorksV1ProjectStrings.noPermission.primary),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('yorks-v1-project-name')), findsNothing);
      expect(
        find.byKey(const ValueKey('yorks-v1-project-create')),
        findsNothing,
      );
      expect(find.byKey(_navigationKey), findsNothing);
      expect(find.byKey(_searchKey), findsNothing);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _sidebarSurface() => find
    .ancestor(
      of: find.text(YorksV1ShellStrings.companyLegalName.primary),
      matching: find.byType(SafeArea),
    )
    .first;

Future<void> _openCreateProject(WidgetTester tester) async {
  final create = find
      .descendant(
        of: find.byType(YorksV1ProjectsScreen),
        matching: find.text(YorksV1ProjectStrings.createProject.primary),
      )
      .first;
  await tester.ensureVisible(create);
  await tester.tap(create);
  await tester.pumpAndSettle();
}

Future<void> _resizeWorkspace(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  await tester.pumpAndSettle();
}

Future<void> _openWorkspaceSearch(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  expect(find.byType(YorksV1WorkspaceSearchDialog), findsOneWidget);
}

void _expectPortfolio(_WorkspaceFixture fixture) {
  expect(
    fixture.router.routeInformationProvider.value.uri.path,
    RoutePaths.yorksV1Projects,
  );
  expect(find.byType(YorksV1ProjectsScreen), findsOneWidget);
  expect(find.byType(YorksV1ProjectCreateFlowScreen), findsNothing);
}

void _expectResumedDraft(
  WidgetTester tester,
  _WorkspaceFixture fixture,
  String originalDraftId,
  String proposedName,
) {
  expect(
    fixture.router.routerDelegate.currentConfiguration.last.matchedLocation,
    RoutePaths.engineerCreateProject,
  );
  expect(find.byType(YorksV1ProjectCreateFlowScreen), findsOneWidget);
  expect(find.byKey(_navigationKey), findsNothing);
  expect(find.byKey(_searchKey), findsNothing);
  final name = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const ValueKey('yorks-v1-project-name')),
      matching: find.byType(EditableText),
    ),
  );
  expect(name.controller.text, proposedName);
  final resumed = fixture.container.read(
    yorksV1ProjectSetupCreationDraftProvider(_owner),
  );
  expect(resumed.draftId, originalDraftId);
  expect(resumed.name, proposedName);
  expect(resumed.acknowledgedRevision, resumed.revision);
}

void _expectEngineerNavigation(Finder surface) {
  for (final label in [
    YorksV1ShellStrings.overview,
    YorksV1ShellStrings.projects,
    YorksV1ShellStrings.materialRequests,
    YorksV1ShellStrings.ductSizer,
    YorksV1ShellStrings.espCalculator,
  ]) {
    expect(
      find.descendant(of: surface, matching: find.text(label.primary)),
      findsOneWidget,
    );
  }
  for (final label in [
    YorksV1ShellStrings.configuration,
    YorksV1ShellStrings.userManagement,
    YorksV1ShellStrings.auditTrail,
  ]) {
    expect(
      find.descendant(of: surface, matching: find.text(label.primary)),
      findsNothing,
    );
  }
}

Future<_WorkspaceFixture> _pumpWorkspace(
  WidgetTester tester, {
  Size size = const Size(1536, 1024),
  YorksV1CurrentPermissionSnapshotState? permission,
  bool settle = true,
  String initialLocation = RoutePaths.engineerCreateProject,
  Future<void> Function(ProviderContainer, SharedPreferences)? seed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final client = _NoNetworkSupabaseClient();
  final commands = _NoProjectCommands();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      supabaseClientProvider.overrideWithValue(client),
      currentUserProvider.overrideWithValue(null),
      unreadNotificationCountProvider.overrideWithValue(0),
      yorksV1WorkspaceStatusProvider.overrideWithValue(
        const YorksV1WorkspaceStatus(
          state: YorksV1WorkspaceConnectionState.connected,
        ),
      ),
      yorksV1FeatureFlagsProvider.overrideWithValue(
        const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
          projectSetup: true,
          boq: true,
          excel: true,
          requests: true,
          arrangement: true,
          logistics: true,
          returnsDocuments: true,
          documents: true,
        ),
      ),
      yorksV1AuthUserIdProvider.overrideWithValue(_owner),
      yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.projectEngineer),
      yorksV1CurrentPermissionSnapshotProvider.overrideWith(
        (ref) => YorksV1TestPermissionController(
          permission ??
              yorksV1TrustedFeaturePermissionState(
                role: YorksV1Role.projectEngineer,
                capabilities: _engineerCapabilities,
              ),
        ),
      ),
      yorksV1ProjectRepositoryProvider.overrideWithValue(commands),
      yorksV1ProjectDraftAtomicStorageProvider.overrideWithValue(
        _SupportedDraftStorage(preferences),
      ),
      yorksV1ProjectReferenceAdvisoryProvider.overrideWith(
        (ref, query) async => YorksV1ProjectReferenceAdvisory.unavailable,
      ),
      yorksV1ActiveProjectTeamDirectoryProvider.overrideWith((ref) async => []),
      yorksV1ProjectPortfolioProvider.overrideWith((ref) async => []),
      yorksV1WorkspaceSearchResultsProvider.overrideWith(
        (ref, query) async => const YorksV1WorkspaceSearchResponse(results: []),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (seed != null) await seed(container, preferences);

  // The browser-only rollout choice is tested separately. This VM integration
  // uses the same route components, canonical paths and mounted onExit guard
  // without changing kIsWeb or substituting a fake feature/navigation widget.
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.engineerCreateProject,
        onExit: (_, _) => container
            .read(yorksV1ProjectSetupNavigationGuardProvider)
            .canLeave(),
        builder: (_, _) => const YorksV1WorkspaceShell(
          featureOwnsBackNavigation: true,
          child: YorksV1ProjectCreateFlowScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.yorksV1Projects,
        builder: (_, _) =>
            const YorksV1WorkspaceShell(child: YorksV1ProjectsScreen()),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  addTearDown(() => expect(client.calls, 0));
  return _WorkspaceFixture(container, router, commands, preferences);
}

class _WorkspaceFixture {
  const _WorkspaceFixture(
    this.container,
    this.router,
    this.commands,
    this.preferences,
  );
  final ProviderContainer container;
  final GoRouter router;
  final _NoProjectCommands commands;
  final SharedPreferences preferences;
}

class _NoProjectCommands
    implements
        YorksV1ProjectRepository,
        YorksV1ProjectReviewedCommandRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Navigation must not dispatch a project command');
  }
}

/// A configured client activates the real connected permission gate, while
/// every transport access fails loudly. These UI tests override only reads
/// and local storage; navigation must never contact a shared backend.
class _NoNetworkSupabaseClient extends Fake implements SupabaseClient {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Workspace navigation must not access remote transport');
  }
}

class _SupportedDraftStorage extends SharedPreferencesProjectDraftStorage {
  _SupportedDraftStorage(super.preferences);
  @override
  bool get supportsAtomicOwnership => true;
}
