import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/analytics_event.dart';
import 'package:material_ledger/shared/services/analytics_route_mapper.dart';

void main() {
  test('record routes map to stable screens without retaining identifiers', () {
    const projectId = '3f784ff0-6bca-4cfe-ac06-105f4f7dcad0';
    final cases = <String, AnalyticsScreen>{
      '/yorks/projects/$projectId': AnalyticsScreen.projectDetail,
      '/yorks/projects/$projectId/boq/group-secret':
          AnalyticsScreen.boqWorksheet,
      '/yorks/projects/$projectId/documents?entity_id=sensitive':
          AnalyticsScreen.projectDocuments,
      '/yorks/material-requests/request-secret/arrangement':
          AnalyticsScreen.procurement,
      '/yorks/material-requests/request-secret/logistics?dispatch_id=private':
          AnalyticsScreen.logistics,
      '/yorks/inventory/suppliers/supplier-secret':
          AnalyticsScreen.inventorySupplierDetail,
      '/yorks/team-chat/conversation-secret':
          AnalyticsScreen.teamChatConversation,
    };

    for (final entry in cases.entries) {
      final destination = AnalyticsRouteMapper.destinationFor(
        Uri.parse(entry.key),
      );
      expect(destination.screen, entry.value);
      expect(destination.screen.wireName, isNot(contains(projectId)));
      expect(destination.screen.wireName, isNot(contains('secret')));
      expect(destination.screen.wireName, isNot(contains('sensitive')));
    }
  });

  test(
    'entry events are attached only to meaningful workflow entry routes',
    () {
      expect(
        AnalyticsRouteMapper.destinationFor(
          Uri.parse('/projects/new'),
        ).entryEvent,
        AnalyticsEvent.projectCreationStarted,
      );
      expect(
        AnalyticsRouteMapper.destinationFor(
          Uri.parse('/yorks/material-requests/draft/private-id'),
        ).entryEvent,
        AnalyticsEvent.materialRequestStarted,
      );
      expect(
        AnalyticsRouteMapper.destinationFor(
          Uri.parse('/yorks/inventory'),
        ).entryEvent,
        AnalyticsEvent.inventoryOpened,
      );
    },
  );

  test(
    'legacy Material Request and Procurement routes retain stable screens',
    () {
      final cases = <String, AnalyticsScreen>{
        '/requests': AnalyticsScreen.materialRequests,
        '/admin/requests': AnalyticsScreen.materialRequests,
        '/request/opaque-request-id': AnalyticsScreen.materialRequestDetail,
        '/admin/procurement': AnalyticsScreen.procurement,
        '/admin/plan-review/opaque-project-id': AnalyticsScreen.procurement,
      };

      for (final entry in cases.entries) {
        final destination = AnalyticsRouteMapper.destinationFor(
          Uri.parse(entry.key),
        );
        expect(destination.screen, entry.value);
        expect(destination.screen.wireName, isNot(contains('opaque')));
      }

      expect(
        AnalyticsRouteMapper.destinationFor(
          Uri.parse('/request/opaque-request-id'),
        ).entryEvent,
        AnalyticsEvent.materialRequestOpened,
      );
      expect(
        AnalyticsRouteMapper.destinationFor(
          Uri.parse('/admin/procurement'),
        ).entryEvent,
        AnalyticsEvent.procurementRequestOpened,
      );
    },
  );
}
