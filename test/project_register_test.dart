import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';

void main() {
  group('Project register fields', () {
    test('toJson/fromJson round-trips the job-register fields', () {
      const p = Project(
        id: 'p1',
        name: 'Grid Station',
        nameSecondary: '',
        jobNumber: '305',
        mainContractor: 'ELMEC',
        authorityRef: 'N-17727',
        consultant: 'AECOM',
        contractValueAED: 1410000,
        assignedEngineerId: 'usr-eng',
      );
      final r = Project.fromJson(p.toJson());
      expect(r.jobNumber, '305');
      expect(r.mainContractor, 'ELMEC');
      expect(r.authorityRef, 'N-17727');
      expect(r.consultant, 'AECOM');
      expect(r.contractValueAED, 1410000);
      expect(r.assignedEngineerId, 'usr-eng');
    });

    test('old JSON without register fields still decodes (back-compat)', () {
      final r = Project.fromJson({'id': 'p2', 'name': 'Legacy', 'nameSecondary': ''});
      expect(r.jobNumber, isNull);
      expect(r.contractValueAED, isNull);
      expect(r.assignedEngineerId, isNull);
    });
  });

  group('Procurement acceptance', () {
    test('a freshly-constructed project defaults to not-yet-accepted', () {
      const p = Project(id: 'p3', name: 'Fresh Job', nameSecondary: '');
      expect(p.acceptedByProcurement, false);
      expect(p.acceptedAt, isNull);
      expect(p.acceptedBy, isNull);
    });

    test('a JSON record predating this field grandfathers in as accepted '
        '(no retroactive backlog for already-in-flight jobs)', () {
      final r = Project.fromJson({'id': 'p4', 'name': 'Legacy', 'nameSecondary': ''});
      expect(r.acceptedByProcurement, true);
    });

    test('toJson/fromJson round-trips an explicit acceptance', () {
      final p = Project(
        id: 'p5',
        name: 'Accepted Job',
        nameSecondary: '',
        acceptedByProcurement: true,
        acceptedAt: DateTime(2026, 1, 5),
        acceptedBy: 'Al Asad',
      );
      final r = Project.fromJson(p.toJson());
      expect(r.acceptedByProcurement, true);
      expect(r.acceptedAt, DateTime(2026, 1, 5));
      expect(r.acceptedBy, 'Al Asad');
    });

    test('an explicit false round-trips as false, not the back-compat default',
        () {
      const p = Project(
        id: 'p6',
        name: 'Still Pending',
        nameSecondary: '',
        acceptedByProcurement: false,
      );
      final r = Project.fromJson(p.toJson());
      expect(r.acceptedByProcurement, false);
    });
  });

  group('Soft delete (Project.deleted)', () {
    test('defaults to false and round-trips true', () {
      const fresh = Project(id: 'p7', name: 'Fresh', nameSecondary: '');
      expect(fresh.deleted, false);

      final tombstone = fresh.copyWith(deleted: true);
      final r = Project.fromJson(tombstone.toJson());
      expect(r.deleted, true);
    });

    test('a record predating this field decodes as not-deleted', () {
      final r = Project.fromJson({'id': 'p8', 'name': 'Legacy', 'nameSecondary': ''});
      expect(r.deleted, false);
    });

    test(
        'a soft-deleted row already in local storage (e.g. re-hydrated from '
        'the cloud after another device deleted it) never surfaces in state',
        () async {
      // Simulates the exact scenario the soft-delete exists to prevent: the
      // outbox only ever upserts, so a cloud tombstone (deleted:true) can land
      // back in this device's local blob via bootstrap hydration or realtime —
      // ProjectsNotifier must filter it out at read time regardless.
      SharedPreferences.setMockInitialValues({
        'projects_list_v1': jsonEncode([
          {'id': 'p-live', 'name': 'Still here', 'nameSecondary': '', 'deleted': false},
          {'id': 'p-tombstone', 'name': 'Ghost', 'nameSecondary': '', 'deleted': true},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final projects = container.read(projectsProvider);
      expect(projects.any((p) => p.id == 'p-live'), isTrue);
      expect(projects.any((p) => p.id == 'p-tombstone'), isFalse);
    });
  });

  group('ProjectsNotifier.acceptProject', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('accepts a pending project, stamping who/when', () async {
      final notifier = container.read(projectsProvider.notifier);
      await notifier.addProject(const Project(
        id: 'p-new',
        name: 'New Job',
        nameSecondary: '',
        assignedEngineerId: 'usr-eng',
      ));

      final updated =
          await notifier.acceptProject('p-new', acceptedBy: 'Al Asad');

      expect(updated, isNotNull);
      expect(updated!.acceptedByProcurement, true);
      expect(updated.acceptedBy, 'Al Asad');
      expect(updated.acceptedAt, isNotNull);
      expect(notifier.byId('p-new')!.acceptedByProcurement, true);
    });

    test('returns null (no-op) for an unknown project id', () async {
      final notifier = container.read(projectsProvider.notifier);
      expect(
        await notifier.acceptProject('nope', acceptedBy: 'Al Asad'),
        isNull,
      );
    });

    test('returns null (no-op) on a second accept — no double-acceptance',
        () async {
      final notifier = container.read(projectsProvider.notifier);
      await notifier.addProject(const Project(
        id: 'p-double',
        name: 'Double Accept',
        nameSecondary: '',
      ));
      final first =
          await notifier.acceptProject('p-double', acceptedBy: 'Al Asad');
      expect(first, isNotNull);
      final second =
          await notifier.acceptProject('p-double', acceptedBy: 'Owner');
      expect(second, isNull);
      // The original acceptance is untouched by the no-op second call.
      expect(notifier.byId('p-double')!.acceptedBy, 'Al Asad');
    });

    test('projectsAwaitingAcceptanceProvider lists only unaccepted projects',
        () async {
      final notifier = container.read(projectsProvider.notifier);
      await notifier.addProject(const Project(
        id: 'p-pending-1',
        name: 'Pending One',
        nameSecondary: '',
      ));
      await notifier.addProject(const Project(
        id: 'p-pending-2',
        name: 'Pending Two',
        nameSecondary: '',
      ));
      expect(
        container.read(projectsAwaitingAcceptanceCountProvider),
        2,
      );

      await notifier.acceptProject('p-pending-1', acceptedBy: 'Al Asad');

      final remaining = container.read(projectsAwaitingAcceptanceProvider);
      expect(remaining.length, 1);
      expect(remaining.single.id, 'p-pending-2');
      expect(container.read(projectsAwaitingAcceptanceCountProvider), 1);
    });
  });

  group('visibleProjectsProvider — engineer scoping', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('engineer sees assigned + unassigned; office sees the full register',
        () async {
      final notifier = container.read(projectsProvider.notifier);
      await notifier.addProject(const Project(
        id: 'p-other',
        name: 'Someone else\'s job',
        nameSecondary: '',
        assignedEngineerId: 'usr-other-eng',
      ));
      await notifier.addProject(const Project(
        id: 'p-unassigned',
        name: 'Unassigned job',
        nameSecondary: '',
      ));

      // Signed in as the engineer (Imran → usr-eng).
      await container
          .read(authControllerProvider)
          .signIn(email: 'imrankhan@gmail.com', password: 'test@123');
      final engView = container.read(visibleProjectsProvider);
      expect(engView.any((p) => p.id == 'p-other'), isFalse); // hidden
      expect(engView.any((p) => p.id == 'p-unassigned'), isTrue); // visible

      // Signed in as the owner/admin → sees everything.
      await container
          .read(authControllerProvider)
          .signIn(email: 'owner@gmail.com', password: 'test@123');
      final adminView = container.read(visibleProjectsProvider);
      expect(adminView.any((p) => p.id == 'p-other'), isTrue);
      expect(adminView.any((p) => p.id == 'p-unassigned'), isTrue);
    });
  });
}
