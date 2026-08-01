import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/brand_logo.dart';
import 'package:material_ledger/features/engineer/presentation/screens/plan_build_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/project_workspace_screen.dart';
import 'package:material_ledger/shared/models/material_plan.dart';
import 'package:material_ledger/shared/models/nexus_feature_flags.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/project_workspace_strings.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_plan_provider.dart';
import 'package:material_ledger/shared/providers/nexus_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:material_ledger/shared/sync/outbox.dart';
import 'package:material_ledger/shared/sync/sync_backend.dart';
import 'package:material_ledger/shared/sync/sync_engine.dart';

const _password = 'test-only-local-password';

Future<ProviderContainer> _container({
  NexusFeatureFlags featureFlags = const NexusFeatureFlags(
    projects: true,
    browseMaterials: true,
    phase1Planning: true,
    procurementReview: true,
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      localDemoPasswordProvider.overrideWithValue(_password),
      nexusFeatureFlagsProvider.overrideWithValue(featureFlags),
      syncEngineProvider.overrideWith((ref) {
        final engine = SyncEngine(
          backend: ref.watch(syncBackendProvider),
          outbox: ref.watch(outboxProvider.notifier),
          connectivity: ref.watch(connectivityProvider),
        );
        ref.onDispose(engine.dispose);
        return engine;
      }),
    ],
  );
}

Future<void> _signIn(ProviderContainer container, String email) async {
  await container.read(authControllerProvider).signOut();
  final result = await container
      .read(authControllerProvider)
      .signIn(email: email, password: _password);
  expect(result, SignInResult.ok);
}

const _firstVersionLines = <PlanItem>[
  PlanItem(
    id: 'line-1',
    materialId: 'mat-001',
    description: 'Copper Pipe',
    size: '22 mm',
    modelSerial: 'CP-22',
    makeOrigin: 'Yorks / UAE',
    quantity: 12,
    unitSymbol: 'm',
    note: 'Level 1 riser',
  ),
  PlanItem(
    id: 'line-2',
    description: 'Custom access panel',
    quantity: 3,
    unitSymbol: 'pcs',
    isCustom: true,
    buildingId: 'building-1',
  ),
];

void main() {
  group('Batch 8 Phase 1 domain', () {
    test(
      'round-trips source, comments, version and activity without stock data',
      () {
        final now = DateTime.utc(2026, 7, 24, 4, 30);
        final plan = MaterialPlan(
          id: 'plan-round-trip',
          projectId: 'project-round-trip',
          version: 1,
          status: MaterialPlanStatus.procurementReview,
          items: [
            _firstVersionLines.first.copyWith(
              proposedSource: PlanProposedSource.warehouse,
              onHandQtySnapshot: 20,
              availableQtySnapshot: 16,
            ),
          ],
          comments: [
            PlanComment(
              id: 'comment-1',
              authorUserId: 'usr-proc',
              authorName: 'Al Asad',
              authorRole: 'Procurement',
              text: 'Use rack B stock first.',
              timestamp: now,
              lineItemId: 'line-1',
            ),
          ],
          versions: [
            MaterialPlanVersion(
              version: 1,
              items: _firstVersionLines,
              createdAt: now,
              createdByUserId: 'usr-eng',
              createdByName: 'Imran Khan',
              createdByRole: 'Engineer',
            ),
          ],
          activity: [
            MaterialPlanActivity(
              action: 'Plan submitted',
              actorName: 'Imran Khan',
              actorRole: 'Engineer',
              actorUserId: 'usr-eng',
              timestamp: now,
            ),
          ],
        );

        final json = plan.toJson();
        final decoded = MaterialPlan.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        );

        expect(decoded.status, MaterialPlanStatus.procurementReview);
        expect(
          decoded.items.single.proposedSource,
          PlanProposedSource.warehouse,
        );
        expect(decoded.comments.single.lineItemId, 'line-1');
        expect(decoded.versions.single.items, hasLength(2));
        expect(decoded.activity.single.actorUserId, 'usr-eng');
        expect(json.toString(), isNot(contains('reservedQty')));
        expect(json.toString(), isNot(contains('allocatedQty')));
        expect(
          MaterialPlanStatus.fromLabel('In review'),
          MaterialPlanStatus.procurementReview,
        );
      },
    );

    test(
      'complete role handoff preserves versions and never reserves stock',
      () async {
        final container = await _container();
        addTearDown(container.dispose);
        await _signIn(container, 'imrankhan@gmail.com');

        await container
            .read(projectsProvider.notifier)
            .addProject(
              const Project(
                id: 'project-batch-8',
                name: 'Batch 8 Grid Station',
                yorksReference: 'YRA-B8',
                assignedEngineerId: 'usr-eng',
                designEngineerUserIds: ['usr-eng'],
                buildings: [
                  ProjectBuilding(
                    id: 'building-1',
                    code: 'B1',
                    name: 'Main Building',
                  ),
                ],
              ),
            );
        final initialReserved = container
            .read(materialsProvider)
            .firstWhere((item) => item.id == 'mat-001')
            .reservedQty;

        await container
            .read(materialPlansProvider.notifier)
            .submitPlan('project-batch-8', _firstVersionLines);
        var plan = container.read(planForProjectProvider('project-batch-8'))!;
        expect(plan.status, MaterialPlanStatus.submitted);
        expect(plan.version, 1);
        expect(plan.versions, hasLength(1));
        expect(plan.currentOwnerRole, 'procurement');

        await _signIn(container, 'alasad@gmail.com');
        await container
            .read(materialPlansProvider.notifier)
            .setProposedSource(
              planId: plan.id,
              itemId: 'line-1',
              source: PlanProposedSource.warehouse,
              onHandQty: 30,
              availableQty: 24,
            );
        await container
            .read(materialPlansProvider.notifier)
            .setProposedSource(
              planId: plan.id,
              itemId: 'line-2',
              source: PlanProposedSource.externalSupplier,
            );
        await container
            .read(materialPlansProvider.notifier)
            .addComment(
              planId: plan.id,
              text: 'Custom panel requires supplier confirmation.',
              authorName: 'Al Asad',
              authorRole: 'Procurement',
              lineItemId: 'line-2',
            );
        await container
            .read(materialPlansProvider.notifier)
            .sendReadyForApproval(plan.id);

        plan = container.read(planForProjectProvider('project-batch-8'))!;
        expect(plan.status, MaterialPlanStatus.pendingEngineerApproval);
        expect(plan.allSourcesReviewed, isTrue);
        expect(plan.comments.single.lineItemId, 'line-2');
        expect(plan.currentOwnerRole, 'engineer');
        expect(
          container
              .read(materialsProvider)
              .firstWhere((item) => item.id == 'mat-001')
              .reservedQty,
          initialReserved,
        );

        // Procurement cannot perform the Engineer's final approval locally.
        await container
            .read(materialPlansProvider.notifier)
            .approvePlan(plan.id);
        expect(
          container.read(planForProjectProvider('project-batch-8'))!.status,
          MaterialPlanStatus.pendingEngineerApproval,
        );

        await _signIn(container, 'imrankhan@gmail.com');
        await container
            .read(materialPlansProvider.notifier)
            .requestChanges(
              planId: plan.id,
              rejectedItemIds: {'line-1'},
              comment: 'Increase the riser allowance.',
              authorName: 'Imran Khan',
            );
        plan = container.read(planForProjectProvider('project-batch-8'))!;
        expect(plan.status, MaterialPlanStatus.rejected);

        final revised = [
          _firstVersionLines.first.copyWith(quantity: 16),
          _firstVersionLines.last,
        ];
        await container
            .read(materialPlansProvider.notifier)
            .submitPlan('project-batch-8', revised);
        plan = container.read(planForProjectProvider('project-batch-8'))!;
        expect(plan.status, MaterialPlanStatus.procurementReview);
        expect(plan.version, 2);
        expect(plan.versions, hasLength(2));
        expect(plan.versions.first.items.first.quantity, 12);
        expect(plan.versions.last.items.first.quantity, 16);
        expect(plan.reviewedAt, isNull);
        expect(
          plan.items.every(
            (item) => item.proposedSource == PlanProposedSource.notReviewed,
          ),
          isTrue,
        );

        await _signIn(container, 'alasad@gmail.com');
        await container
            .read(materialPlansProvider.notifier)
            .markAllArranged(plan.id);
        await container
            .read(materialPlansProvider.notifier)
            .sendReadyForApproval(plan.id);

        await _signIn(container, 'imrankhan@gmail.com');
        await container
            .read(projectsProvider.notifier)
            .activateFromPlanApproval('project-batch-8');
        expect(
          container
              .read(projectsProvider.notifier)
              .byId('project-batch-8')!
              .lifecycleStatus,
          ProjectLifecycleStatus.planning,
        );

        plan = container.read(planForProjectProvider('project-batch-8'))!;
        await container
            .read(materialPlansProvider.notifier)
            .approvePlan(plan.id);
        await container
            .read(projectsProvider.notifier)
            .activateFromPlanApproval('project-batch-8');

        plan = container.read(planForProjectProvider('project-batch-8'))!;
        final project = container
            .read(projectsProvider.notifier)
            .byId('project-batch-8')!;
        expect(plan.status, MaterialPlanStatus.approved);
        expect(plan.approvedAt, isNotNull);
        expect(project.lifecycleStatus, ProjectLifecycleStatus.active);
        expect(project.phase?.state, ProjectState.active);
        expect(
          plan.activity.map((event) => event.action),
          containsAll([
            'Plan submitted',
            'Ready for approval',
            'Changes requested',
            'Plan approved',
          ]),
        );
      },
    );

    test(
      'project-specific progress validates weights and stays reporting-only',
      () async {
        final container = await _container();
        addTearDown(container.dispose);
        await _signIn(container, 'imrankhan@gmail.com');
        await container
            .read(projectsProvider.notifier)
            .addProject(
              const Project(
                id: 'project-progress',
                name: 'Progress Project',
                yorksReference: 'YRA-PROGRESS',
              ),
            );

        final invalid = [
          ...standardProjectProgressStages.take(4),
          standardProjectProgressStages.last.copyWith(weightPercent: 10),
        ];
        expect(
          await container
              .read(projectsProvider.notifier)
              .updateProgressStages('project-progress', invalid),
          isFalse,
        );

        final valid = [
          standardProjectProgressStages[0].copyWith(progressPercent: 100),
          standardProjectProgressStages[1].copyWith(progressPercent: 50),
          standardProjectProgressStages[2].copyWith(progressPercent: 20),
          standardProjectProgressStages[3],
          standardProjectProgressStages[4],
        ];
        expect(
          await container
              .read(projectsProvider.notifier)
              .updateProgressStages('project-progress', valid),
          isTrue,
        );

        final project = container
            .read(projectsProvider.notifier)
            .byId('project-progress')!;
        expect(project.weightedProgressPercent, 41);
        expect(project.lifecycleStatus, ProjectLifecycleStatus.planning);
        expect(project.progressStages.first.updatedByUserId, 'usr-eng');

        await _signIn(container, 'alasad@gmail.com');
        expect(
          await container.read(projectsProvider.notifier).updateProgressStages(
            'project-progress',
            [valid.first.copyWith(progressPercent: 90), ...valid.skip(1)],
          ),
          isFalse,
        );

        await _signIn(container, 'imrankhan@gmail.com');
        expect(
          await container.read(projectsProvider.notifier).updateProgressStages(
            'project-progress',
            [
              valid.first.copyWith(label: 'Renamed by Engineer'),
              ...valid.skip(1),
            ],
          ),
          isFalse,
        );

        await _signIn(container, 'owner@gmail.com');
        expect(
          await container.read(projectsProvider.notifier).updateProgressStages(
            'project-progress',
            [valid.first.copyWith(label: 'Cooling Design'), ...valid.skip(1)],
          ),
          isTrue,
        );
        expect(
          Project.fromJson(project.toJson()).weightedProgressPercent,
          project.weightedProgressPercent,
        );
      },
    );
  });

  group('Batch 8 responsive presentation', () {
    testWidgets('Phase 1 routes fail closed when rollout is disabled', (
      tester,
    ) async {
      final container = await _container(
        featureFlags: const NexusFeatureFlags(projects: true),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PlanBuildScreen(projectId: 'disabled-plan'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This transformed workflow is not enabled for this deployment.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('phase-one-material-line-grid')),
        findsNothing,
      );
    });

    testWidgets('brand asset is explicitly clipped to a circle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: BrandLogo(size: 48)),
        ),
      );

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(ClipOval)), const Size.square(48));
    });

    testWidgets('Phase 1 line scope stacks without mobile overflow', (
      tester,
    ) async {
      final container = await _container();
      addTearDown(container.dispose);
      await _signIn(container, 'imrankhan@gmail.com');
      await container
          .read(projectsProvider.notifier)
          .addProject(
            const Project(
              id: 'project-mobile-plan',
              name: 'Mobile Plan',
              yorksReference: 'YRA-MOBILE',
              buildings: [
                ProjectBuilding(
                  id: 'building-1',
                  code: 'B1',
                  name: 'Main Building',
                ),
              ],
            ),
          );
      await container
          .read(materialPlansProvider.notifier)
          .saveDraft('project-mobile-plan', _firstVersionLines);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PlanBuildScreen(projectId: 'project-mobile-plan'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('phase-one-material-line-grid')),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-scope-line-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Engineer can open the project-specific progress editor', (
      tester,
    ) async {
      final container = await _container();
      addTearDown(container.dispose);
      await _signIn(container, 'imrankhan@gmail.com');
      await container
          .read(projectsProvider.notifier)
          .addProject(
            const Project(
              id: 'project-progress-ui',
              name: 'Progress UI Project',
              yorksReference: 'YRA-PROGRESS-UI',
              assignedEngineerId: 'usr-eng',
              designEngineerUserIds: ['usr-eng'],
            ),
          );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProjectWorkspaceScreen(
              projectId: 'project-progress-ui',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('project-progress-card')),
        findsOneWidget,
      );
      final editProgress = find.text(
        ProjectWorkspaceStrings.editProgress.primary,
      );
      await tester.ensureVisible(editProgress);
      await tester.pumpAndSettle();
      await tester.tap(editProgress);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(ProjectWorkspaceStrings.projectProgress.primary),
        findsWidgets,
      );
      expect(find.text('Cooling Load Design'), findsWidgets);
      expect(find.text('Material Supply'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
