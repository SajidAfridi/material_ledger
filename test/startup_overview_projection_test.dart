import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_portfolio.dart';

void main() {
  test('project startup projection keeps exact totals and bounded cards', () {
    final overview = YorksV1ProjectOverview.fromRpcJson({
      'items': [
        {
          'id': 'project-1',
          'project_ref': 'YRA-1',
          'name': 'Project One',
          'state': 'active',
          'record_version': 2,
          'created_at': '2026-09-01T00:00:00Z',
          'updated_at': '2026-09-02T00:00:00Z',
          'client_name': 'Client One',
          'active_building_count': 3,
          'active_project_engineer_count': 2,
          'active_site_engineer_count': 4,
        },
      ],
      'counts': {'total': 81, 'active': 40, 'on_hold': 9, 'completed': 28},
    });

    expect(overview.total, 81);
    expect(overview.active, 40);
    expect(overview.items, hasLength(1));
    expect(overview.items.single.activeBuildingCount, 3);
    expect(overview.items.single.activeTeamCount, 6);
    expect(overview.items.single.activeMembers, isEmpty);
    expect(overview.items.single.buildings, isEmpty);
  });

  test('request startup projection never hydrates lines or comments', () {
    final overview = YorksV1MaterialRequestOverview.fromRpcJson({
      'items': [
        {
          'id': 'request-1',
          'project_id': 'project-1',
          'project_ref': 'YRA-1',
          'project_name': 'Project One',
          'scope_id': 'scope-1',
          'scope_name': 'Building One',
          'state': 'awaiting_approval',
          'record_version': 3,
          'request_number': 'YRA1-MR001',
          'timing': 'normal',
          'item_count': 27,
          'actor_can_act': true,
          'exception_codes': <String>[],
          'created_at': '2026-09-01T00:00:00Z',
          'updated_at': '2026-09-02T00:00:00Z',
          'work_assignment': {
            'request_id': 'request-1',
            'assignment_version': 0,
            'assignee_auth_user_id': null,
            'assignee_display_name': null,
            'assignee_exact_role': null,
            'assigned_at': null,
            'can_manage': false,
          },
        },
      ],
      'counts': {
        'total': 210,
        'open': 43,
        'needs_action': 7,
        'approvals': 4,
        'delivery_exceptions': 3,
        'receipt_pending': 8,
        'drafts_and_changes': 5,
        'received': 120,
        'closed': 47,
        'dispatch_ready': 6,
        'new_to_arrange': 2,
      },
    });

    expect(overview.total, 210);
    expect(overview.needsAction, 7);
    expect(overview.items, hasLength(1));
    expect(overview.items.single.lines, isEmpty);
    expect(overview.items.single.comments, isEmpty);
    expect(overview.items.single.displayItemCount, 27);
  });
}
