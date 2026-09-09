import '../models/analytics_event.dart';
import 'analytics_service.dart';

class AnalyticsRouteDestination {
  const AnalyticsRouteDestination(this.screen, {this.entryEvent});

  final AnalyticsScreen screen;
  final AnalyticsEvent? entryEvent;
}

/// Converts navigation to stable, identifier-free screen names. Query values,
/// UUIDs, project references and user-visible titles never cross this seam.
abstract final class AnalyticsRouteMapper {
  static AnalyticsRouteDestination destinationFor(Uri uri) {
    final s = uri.pathSegments;
    final path = uri.path;

    if (path == '/' || path == '/home') {
      return const AnalyticsRouteDestination(AnalyticsScreen.dashboard);
    }
    if (path == '/splash') {
      return const AnalyticsRouteDestination(AnalyticsScreen.splash);
    }
    if (path == '/language-selection') {
      return const AnalyticsRouteDestination(AnalyticsScreen.languageSelection);
    }
    if (path == '/login') {
      return const AnalyticsRouteDestination(AnalyticsScreen.login);
    }
    if (path == '/change-password') {
      return const AnalyticsRouteDestination(AnalyticsScreen.changePassword);
    }
    if (path == '/materials') {
      return const AnalyticsRouteDestination(AnalyticsScreen.materials);
    }
    if (path == '/browse') {
      return const AnalyticsRouteDestination(AnalyticsScreen.browse);
    }
    if (path == '/projects' || path == '/my-projects') {
      return const AnalyticsRouteDestination(AnalyticsScreen.projects);
    }
    if (path == '/projects/new') {
      return const AnalyticsRouteDestination(
        AnalyticsScreen.projectCreate,
        entryEvent: AnalyticsEvent.projectCreationStarted,
      );
    }
    if (path == '/profile' || path == '/me') {
      return const AnalyticsRouteDestination(AnalyticsScreen.profile);
    }
    if (path == '/rentals') {
      return const AnalyticsRouteDestination(AnalyticsScreen.rentals);
    }
    if (path == '/people') {
      return const AnalyticsRouteDestination(AnalyticsScreen.people);
    }
    if (path == '/notifications') {
      return const AnalyticsRouteDestination(AnalyticsScreen.notifications);
    }
    if (path == '/notification-preferences') {
      return const AnalyticsRouteDestination(
        AnalyticsScreen.notificationPreferences,
      );
    }

    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'projects') {
      if (s.length == 2) {
        return const AnalyticsRouteDestination(AnalyticsScreen.projects);
      }
      if (s.length == 3) {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.projectDetail,
          entryEvent: AnalyticsEvent.projectOpened,
        );
      }
      if (s.length >= 4 && s[3] == 'edit') {
        return const AnalyticsRouteDestination(AnalyticsScreen.projectEdit);
      }
      if (s.length >= 4 && s[3] == 'documents') {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.projectDocuments,
        );
      }
      if (s.length >= 4 && s[3] == 'boq') {
        return AnalyticsRouteDestination(
          s.length == 4
              ? AnalyticsScreen.boqGroups
              : AnalyticsScreen.boqWorksheet,
        );
      }
      if (s.length >= 4 && s[3] == 'accounts') {
        return AnalyticsRouteDestination(_projectAccountsScreen(s));
      }
    }

    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'material-requests') {
      if (s.length == 2) {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.materialRequests,
        );
      }
      if (s.length >= 3 && s[2] == 'draft') {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.materialRequestDraft,
          entryEvent: AnalyticsEvent.materialRequestStarted,
        );
      }
      if (s.length >= 4 && s[3] == 'arrangement') {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.procurementArrangement,
          entryEvent: AnalyticsEvent.procurementRequestOpened,
        );
      }
      if (s.length >= 4 && s[3] == 'logistics') {
        return const AnalyticsRouteDestination(AnalyticsScreen.logistics);
      }
      if (s.length >= 4 && s[3] == 'returns') {
        return const AnalyticsRouteDestination(
          AnalyticsScreen.returnsDocuments,
        );
      }
      return const AnalyticsRouteDestination(
        AnalyticsScreen.materialRequestDetail,
        entryEvent: AnalyticsEvent.materialRequestOpened,
      );
    }

    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'inventory') {
      if (s.length >= 3 && s[2] == 'import') {
        return const AnalyticsRouteDestination(AnalyticsScreen.inventoryImport);
      }
      if (s.length >= 3 && s[2] == 'suppliers') {
        return AnalyticsRouteDestination(
          s.length == 3
              ? AnalyticsScreen.inventorySuppliers
              : AnalyticsScreen.inventorySupplierDetail,
        );
      }
      return const AnalyticsRouteDestination(
        AnalyticsScreen.inventory,
        entryEvent: AnalyticsEvent.inventoryOpened,
      );
    }

    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'accounts') {
      return AnalyticsRouteDestination(_accountsScreen(s));
    }
    if (path == '/yorks/analytics') {
      return const AnalyticsRouteDestination(
        AnalyticsScreen.operationalAnalytics,
      );
    }
    if (path == '/yorks/dispatches') {
      return const AnalyticsRouteDestination(AnalyticsScreen.dispatches);
    }
    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'returns') {
      if (s.length == 2) {
        return const AnalyticsRouteDestination(AnalyticsScreen.returns);
      }
      return AnalyticsRouteDestination(
        s[2] == 'new'
            ? AnalyticsScreen.returnCreate
            : AnalyticsScreen.returnDetail,
      );
    }
    if (path == '/yorks/configuration') {
      return const AnalyticsRouteDestination(AnalyticsScreen.configuration);
    }
    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'workforce') {
      return AnalyticsRouteDestination(switch (s.length < 3 ? '' : s[2]) {
        'administration' => AnalyticsScreen.workforceAdministration,
        'attendance' => AnalyticsScreen.workforceAttendance,
        'timesheets' => AnalyticsScreen.workforceTimesheets,
        _ => AnalyticsScreen.workforce,
      });
    }
    if (s.length >= 2 && s[0] == 'yorks' && s[1] == 'team-chat') {
      return AnalyticsRouteDestination(
        s.length == 2
            ? AnalyticsScreen.teamChat
            : AnalyticsScreen.teamChatConversation,
      );
    }
    if (path.startsWith('/tools/')) {
      return const AnalyticsRouteDestination(AnalyticsScreen.engineeringTool);
    }
    if (path == '/admin/users' || path.startsWith('/admin/users/')) {
      return const AnalyticsRouteDestination(AnalyticsScreen.userManagement);
    }
    if (path == '/more' || path == '/yorks/more') {
      return const AnalyticsRouteDestination(AnalyticsScreen.settings);
    }
    return const AnalyticsRouteDestination(AnalyticsScreen.unknown);
  }

  static AnalyticsScreen _accountsScreen(List<String> segments) =>
      switch (segments.length < 3 ? '' : segments[2]) {
        'projects' => AnalyticsScreen.accountsProjects,
        'billing-progress' => AnalyticsScreen.accountsBilling,
        'claims' => AnalyticsScreen.accountsClaims,
        'client-payments' || 'due-schedule' => AnalyticsScreen.accountsReceipts,
        'supplier-bills' => AnalyticsScreen.accountsSupplierBills,
        'documents' => AnalyticsScreen.accountsDocuments,
        'reports' => AnalyticsScreen.accountsReports,
        'activity' => AnalyticsScreen.accountsActivity,
        _ => AnalyticsScreen.accounts,
      };

  static AnalyticsScreen _projectAccountsScreen(List<String> segments) =>
      switch (segments.length < 5 ? '' : segments[4]) {
        'billing' => AnalyticsScreen.accountsBilling,
        'client-invoices' => AnalyticsScreen.accountsClaims,
        'receipts-pdc' => AnalyticsScreen.accountsReceipts,
        'supplier-bills' => AnalyticsScreen.accountsSupplierBills,
        'documents' => AnalyticsScreen.accountsDocuments,
        'activity' => AnalyticsScreen.accountsActivity,
        _ => AnalyticsScreen.accounts,
      };
}

class AnalyticsRouteTracker {
  AnalyticsRouteTracker(this._analytics);

  final AnalyticsService _analytics;
  Uri? _lastUri;

  void track(Uri uri) {
    final privacySafeUri = Uri(path: uri.path);
    if (_lastUri == privacySafeUri) return;
    _lastUri = privacySafeUri;
    final destination = AnalyticsRouteMapper.destinationFor(privacySafeUri);
    _analytics.screenViewed(destination.screen);
    final entryEvent = destination.entryEvent;
    if (entryEvent != null) {
      _analytics.capture(
        entryEvent,
        properties: const {AnalyticsProperty.source: 'navigation'},
      );
    }
  }
}
