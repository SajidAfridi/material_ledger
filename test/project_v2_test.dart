import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';

const _testLocalPassword = 'test-only-local-password';

void main() {
  group('Project value objects', () {
    test('building round-trips scope, floors, FRP, and archive metadata', () {
      final archivedAt = DateTime.utc(2026, 7, 1);
      final building = ProjectBuilding(
        id: 'b-1',
        code: 'DF3W',
        name: 'District Cooling Building',
        scope: ProjectBuildingScope.common,
        floorsOrLevels: const ['Basement', 'GF', 'Roof'],
        hasFrpRoom: true,
        notes: 'Plant room included',
        active: false,
        archivedAt: archivedAt,
        archivedByUserId: 'usr-admin',
      );

      final decoded = ProjectBuilding.fromJson(building.toJson());

      expect(decoded.id, 'b-1');
      expect(decoded.code, 'DF3W');
      expect(decoded.scope, ProjectBuildingScope.common);
      expect(decoded.isProjectWide, isTrue);
      expect(decoded.floorsOrLevels, ['Basement', 'GF', 'Roof']);
      expect(decoded.hasFrpRoom, isTrue);
      expect(decoded.active, isFalse);
      expect(decoded.archivedAt, archivedAt);
      expect(decoded.archivedByUserId, 'usr-admin');
    });

    test('party decoder accepts legacy names and v2 objects', () {
      final legacy = ProjectParty.decode(
        'Civil Works Contractor',
        fallbackId: 'p-1-other-1',
      );
      final v2 = ProjectParty.decode({
        'id': 'party-2',
        'name': 'Controls Subcontractor',
      }, fallbackId: 'fallback');

      expect(legacy?.id, 'p-1-other-1');
      expect(legacy?.name, 'Civil Works Contractor');
      expect(v2?.id, 'party-2');
      expect(v2?.name, 'Controls Subcontractor');
    });
  });

  group('Project v3 serialization and migration', () {
    test('round-trips the complete v3 project aggregate', () {
      final createdAt = DateTime.utc(2026, 6, 1, 8);
      final updatedAt = DateTime.utc(2026, 7, 10, 9, 30);
      final project = Project(
        id: 'project-v2',
        yorksReference: 'YRA-322',
        name: 'Al Reef Villas',
        secondaryName: 'فلل الريف',
        contractOrJobNumber: 'B066',
        clientName: 'Al Reef Client',
        siteLocation: 'Abu Dhabi',
        consultant: 'AECOM',
        mainContractor: 'L&T',
        subContractors: const [
          ProjectParty(id: 'party-sub-1', name: 'Yorks HVAC'),
        ],
        otherContractors: const [
          ProjectParty(id: 'party-other-1', name: 'Civil Works Contractor'),
        ],
        projectManagerUserId: 'usr-pm',
        designEngineerUserIds: const ['usr-eng', 'usr-eng-2'],
        buildings: const [
          ProjectBuilding(
            id: 'building-1',
            code: 'DF3W',
            name: 'District Cooling Building',
            floorsOrLevels: ['Basement', 'GF', 'Roof'],
            hasFrpRoom: true,
          ),
        ],
        attachments: [
          ProjectAttachment(
            id: 'attachment-1',
            fileName: 'approved-drawing.pdf',
            documentType: 'Approved drawing',
            reference: 'DWG-44',
            buildingId: 'building-1',
            addedAt: createdAt,
            addedByUserId: 'usr-admin',
            addedByRole: 'admin',
          ),
        ],
        lifecycleStatus: ProjectLifecycleStatus.draft,
        createdAt: createdAt,
        createdByUserId: 'usr-admin',
        createdByRole: 'admin',
        updatedAt: updatedAt,
        updatedByUserId: 'usr-admin',
        updatedByRole: 'admin',
      );

      final decoded = Project.fromJson(project.toJson());

      expect(decoded.dataVersion, Project.currentDataVersion);
      expect(decoded.yorksReference, 'YRA-322');
      expect(decoded.secondaryName, 'فلل الريف');
      expect(decoded.nameSecondary, 'فلل الريف');
      expect(decoded.contractOrJobNumber, 'B066');
      expect(decoded.jobNumber, 'B066');
      expect(decoded.subContractors.single.name, 'Yorks HVAC');
      expect(decoded.otherContractors.single.name, 'Civil Works Contractor');
      expect(decoded.projectManagerUserId, 'usr-pm');
      expect(decoded.designEngineerUserIds, ['usr-eng', 'usr-eng-2']);
      expect(decoded.buildings.single.hasFrpRoom, isTrue);
      expect(decoded.attachments.single.fileName, 'approved-drawing.pdf');
      expect(decoded.attachments.single.buildingId, 'building-1');
      expect(decoded.lifecycleStatus, ProjectLifecycleStatus.draft);
      expect(decoded.createdAt, createdAt);
      expect(decoded.updatedAt, updatedAt);
      expect(decoded.toJson(), equals(project.toJson()));
    });

    test('migrates legacy flat location and assignment without data loss', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-1',
        'name': 'Legacy Grid Station',
        'nameSecondary': 'محطة قديمة',
        'buildingName': 'Main Utility Building',
        'floorNumbers': 'Basement, GF; Roof',
        'jobNumber': '305',
        'authorityRef': 'N-17727',
        'assignedEngineerId': 'usr-eng',
        'lastUpdated': '2026-05-01T10:30:00.000Z',
      };

      final migrated = Project.fromJson(legacy);

      expect(migrated.dataVersion, Project.currentDataVersion);
      expect(migrated.secondaryName, 'محطة قديمة');
      expect(migrated.contractOrJobNumber, '305');
      expect(migrated.designEngineerUserIds, ['usr-eng']);
      expect(migrated.buildings, hasLength(1));
      expect(migrated.buildings.single.id, 'legacy-1-building-legacy');
      expect(migrated.buildings.single.name, 'Main Utility Building');
      expect(migrated.buildings.single.floorsOrLevels, [
        'Basement',
        'GF',
        'Roof',
      ]);
      expect(migrated.buildings.single.hasFrpRoom, isFalse);
      expect(migrated.authorityRef, 'N-17727');
      expect(migrated.otherContractors, isEmpty);
      expect(migrated.migrationMetadata?.legacyAuthorityRef, 'N-17727');
      expect(
        migrated.migrationMetadata?.legacyBuildingName,
        'Main Utility Building',
      );
      expect(migrated.updatedAt, DateTime.parse('2026-05-01T10:30:00.000Z'));

      final firstCurrentJson = migrated.toJson();
      final secondCurrentJson = Project.fromJson(firstCurrentJson).toJson();
      expect(secondCurrentJson, equals(firstCurrentJson));
    });

    test('an explicit v2 empty building list is not remigrated', () {
      final decoded = Project.fromJson({
        'dataVersion': 2,
        'id': 'v2-empty',
        'name': 'No Building Yet',
        'nameSecondary': '',
        'buildingName': 'Stale legacy display value',
        'buildings': <Map<String, dynamic>>[],
      });

      expect(decoded.buildings, isEmpty);
      expect(decoded.migrationMetadata, isNull);
    });

    test('a null legacy buildings value still migrates flat location', () {
      final decoded = Project.fromJson({
        'id': 'legacy-null-buildings',
        'name': 'Null Buildings',
        'nameSecondary': '',
        'buildingName': 'Tower B',
        'floorNumbers': 'GF, Roof',
        'buildings': null,
      });

      expect(decoded.buildings, hasLength(1));
      expect(decoded.buildings.single.name, 'Tower B');
      expect(decoded.buildings.single.floorsOrLevels, ['GF', 'Roof']);
    });

    test('legacy contractor-name lists gain deterministic party ids', () {
      final decoded = Project.fromJson({
        'id': 'legacy-parties',
        'name': 'Legacy Parties',
        'nameSecondary': '',
        'subContractors': ['Yorks HVAC'],
        'otherContractors': ['Civil Works Contractor'],
      });

      expect(
        decoded.subContractors.single.id,
        'legacy-parties-subcontractor-1',
      );
      expect(
        decoded.otherContractors.single.id,
        'legacy-parties-other-contractor-1',
      );
    });
  });

  group('ProjectsNotifier v2 behavior', () {
    late ProviderContainer container;
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          localDemoPasswordProvider.overrideWithValue(_testLocalPassword),
        ],
      );
      addTearDown(container.dispose);
    });

    test('persists legacy local JSON back as idempotent v2 JSON', () async {
      container.dispose();
      SharedPreferences.setMockInitialValues({
        'projects_list_v1': jsonEncode([
          {
            'id': 'legacy-local',
            'name': 'Legacy Local',
            'nameSecondary': '',
            'buildingName': 'Tower A',
            'floorNumbers': 'GF, 1F',
            'authorityRef': 'AUTH-9',
          },
        ]),
      });
      preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          localDemoPasswordProvider.overrideWithValue(_testLocalPassword),
        ],
      );

      final loaded = container.read(projectsProvider);
      expect(loaded.single.buildings.single.name, 'Tower A');
      await Future<void>.delayed(Duration.zero);

      final persisted =
          jsonDecode(preferences.getString('projects_list_v1')!) as List;
      final row = Map<String, dynamic>.from(persisted.single as Map);
      expect(row['dataVersion'], Project.currentDataVersion);
      expect(row['authorityRef'], 'AUTH-9');
      expect(row['otherContractors'], isEmpty);
      expect(row['buildings'], hasLength(1));
      expect((row['migrationMetadata'] as Map)['legacyAuthorityRef'], 'AUTH-9');
    });

    test('enforces case-insensitive unique Yorks references', () async {
      final notifier = container.read(projectsProvider.notifier);

      expect(
        await notifier.addProject(
          const Project(
            id: 'ref-1',
            name: 'First',
            secondaryName: '',
            yorksReference: ' YRA-322 ',
          ),
        ),
        isTrue,
      );
      expect(notifier.isYorksReferenceAvailable('yra-322'), isFalse);
      expect(
        notifier.isYorksReferenceAvailable(
          'yra-322',
          excludingProjectId: 'ref-1',
        ),
        isTrue,
      );
      expect(
        await notifier.addProject(
          const Project(
            id: 'ref-2',
            name: 'Duplicate',
            secondaryName: '',
            yorksReference: 'yra-322',
          ),
        ),
        isFalse,
      );
      expect(notifier.byId('ref-2'), isNull);
    });

    test(
      'stamps creator and updater metadata from the signed-in user',
      () async {
        await container
            .read(authControllerProvider)
            .signIn(email: 'imrankhan@gmail.com', password: _testLocalPassword);
        final notifier = container.read(projectsProvider.notifier);

        expect(
          await notifier.addProject(
            const Project(
              id: 'audit-1',
              name: 'Audit Project',
              secondaryName: '',
              yorksReference: 'YRA-500',
            ),
          ),
          isTrue,
        );
        final created = notifier.byId('audit-1')!;
        expect(created.createdAt, isNotNull);
        expect(created.createdByUserId, 'usr-eng');
        expect(created.createdByRole, 'engineer');
        expect(created.updatedAt, isNotNull);
        expect(created.updatedByUserId, 'usr-eng');

        expect(
          await notifier.updateProject(created.copyWith(name: 'Audit Updated')),
          isTrue,
        );
        final updated = notifier.byId('audit-1')!;
        expect(updated.name, 'Audit Updated');
        expect(updated.createdAt, created.createdAt);
        expect(updated.createdByUserId, created.createdByUserId);
        expect(updated.updatedByUserId, 'usr-eng');
        expect(updated.updatedByRole, 'engineer');
      },
    );

    test(
      'engineer visibility includes V7 multi-engineer assignments',
      () async {
        final notifier = container.read(projectsProvider.notifier);
        await notifier.addProject(
          const Project(
            id: 'multi-engineer',
            name: 'Shared Design Job',
            secondaryName: '',
            assignedEngineerId: 'usr-other-eng',
            designEngineerUserIds: ['usr-eng', 'usr-other-eng'],
          ),
        );
        await notifier.addProject(
          const Project(
            id: 'other-engineer',
            name: 'Other Design Job',
            secondaryName: '',
            designEngineerUserIds: ['usr-other-eng'],
          ),
        );

        await container
            .read(authControllerProvider)
            .signIn(email: 'imrankhan@gmail.com', password: _testLocalPassword);
        final visible = container.read(visibleProjectsProvider);

        expect(
          visible.any((project) => project.id == 'multi-engineer'),
          isTrue,
        );
        expect(
          visible.any((project) => project.id == 'other-engineer'),
          isFalse,
        );
      },
    );
  });
}
