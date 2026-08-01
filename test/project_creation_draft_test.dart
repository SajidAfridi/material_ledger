import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/project_creation_draft.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/project_creation_draft_provider.dart';

void main() {
  group('ProjectCreationDraft persistence', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    ProviderContainer container() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );

    test('restores a draft for its owner and isolates another user', () async {
      var scope = container();
      final original = scope
          .read(projectCreationDraftProvider('usr-eng'))
          .copyWith(
            currentStep: 1,
            yorksReference: 'YRA-401',
            name: 'Airport Cooling Upgrade',
            designEngineerUserIds: const ['usr-eng'],
          );
      await scope
          .read(projectCreationDraftProvider('usr-eng').notifier)
          .save(original);
      scope.dispose();

      scope = container();
      addTearDown(scope.dispose);
      final restored = scope.read(projectCreationDraftProvider('usr-eng'));
      final otherUser = scope.read(projectCreationDraftProvider('usr-proc'));

      expect(restored.currentStep, 1);
      expect(restored.yorksReference, 'YRA-401');
      expect(restored.name, 'Airport Cooling Upgrade');
      expect(otherUser.yorksReference, isEmpty);
      expect(otherUser.ownerUserId, 'usr-proc');
    });

    test(
      'discard removes persisted input and returns a fresh building',
      () async {
        final scope = container();
        addTearDown(scope.dispose);
        final notifier = scope.read(
          projectCreationDraftProvider('usr-eng').notifier,
        );
        await notifier.save(
          scope
              .read(projectCreationDraftProvider('usr-eng'))
              .copyWith(name: 'Discard me'),
        );

        await notifier.discard();

        final fresh = scope.read(projectCreationDraftProvider('usr-eng'));
        expect(fresh.name, isEmpty);
        expect(fresh.currentStep, 0);
        expect(fresh.buildings, hasLength(1));
        expect(fresh.buildings.single.code, isEmpty);
      },
    );
  });

  group('ProjectCreationDraft conversion', () {
    ProjectCreationDraft completeDraft() {
      final now = DateTime.utc(2026, 7, 24, 8);
      return ProjectCreationDraft.empty(
        ownerUserId: 'usr-eng',
        initialBuildingId: 'building-1',
      ).copyWith(
        yorksReference: ' YRA-990 ',
        name: ' Central Plant ',
        secondaryName: ' المحطة المركزية ',
        clientName: ' Client LLC ',
        contractOrJobNumber: ' JOB-44 ',
        siteLocation: ' Abu Dhabi ',
        startDate: now,
        consultant: ' MEP Consultant ',
        mainContractor: ' Main Contractor ',
        projectManagerUserId: 'usr-admin',
        designEngineerUserIds: const ['usr-eng', 'usr-eng-2'],
        subContractorNames: const ['Duct Works'],
        otherContractorNames: const ['Civil Works'],
        buildings: const [
          ProjectBuilding(
            id: 'building-1',
            code: ' B01 ',
            name: ' Plant Building ',
            floorsOrLevels: ['GF', 'Roof'],
            hasFrpRoom: true,
          ),
        ],
        attachments: [
          ProjectAttachment(
            id: 'attachment-1',
            fileName: ' drawing.pdf ',
            documentType: ' Approved drawing ',
            reference: ' DWG-1 ',
            buildingId: 'building-1',
            addedAt: now,
            addedByUserId: 'usr-eng',
            addedByRole: 'engineer',
          ),
        ],
      );
    }

    test('creates traceable engineer project with common scope', () {
      final now = DateTime.utc(2026, 7, 24, 9);
      final project = completeDraft().toProject(
        projectId: 'project-1',
        createdAt: now,
        actorUserId: 'usr-eng',
        actorRole: 'engineer',
        commonBuildingId: 'building-common',
      );

      expect(project.yorksReference, 'YRA-990');
      expect(project.name, 'Central Plant');
      expect(project.authorityRef, isNull);
      expect(project.otherContractors.single.name, 'Civil Works');
      expect(project.assignedEngineerId, 'usr-eng');
      expect(project.designEngineerUserIds, ['usr-eng', 'usr-eng-2']);
      expect(project.buildings, hasLength(2));
      expect(project.buildings.first.id, 'building-common');
      expect(project.buildings.first.scope, ProjectBuildingScope.common);
      expect(project.buildings.last.scope, ProjectBuildingScope.physical);
      expect(project.attachments.single.fileName, 'drawing.pdf');
      expect(project.lifecycleStatus, ProjectLifecycleStatus.draft);
      expect(project.createdByRole, 'engineer');
      expect(project.acceptedByProcurement, isFalse);
    });

    test('office-created project is already acknowledged', () {
      final now = DateTime.utc(2026, 7, 24, 9);
      final project = completeDraft().toProject(
        projectId: 'project-2',
        createdAt: now,
        actorUserId: 'usr-proc',
        actorRole: 'procurement',
        commonBuildingId: 'building-common',
      );

      expect(project.acceptedByProcurement, isTrue);
      expect(project.acceptedAt, now);
      expect(project.acceptedBy, 'usr-proc');
    });
  });
}
