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
      notifier.addProject(const Project(
        id: 'p-other',
        name: 'Someone else\'s job',
        nameSecondary: '',
        assignedEngineerId: 'usr-other-eng',
      ));
      notifier.addProject(const Project(
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
