import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_project.dart';
import '../models/yorks_v1_project_portfolio.dart';

/// Read seam for the R35 project portfolio.  Widgets only depend on the typed
/// repository below and therefore cannot construct a broader Supabase query.
abstract interface class YorksV1ProjectPortfolioDataClient {
  Future<List<Map<String, dynamic>>> listProjects();

  Future<List<Map<String, dynamic>>> listProjectParties(
    List<String> projectIds,
  );

  Future<List<Map<String, dynamic>>> listProjectScopes(List<String> projectIds);

  Future<List<Map<String, dynamic>>> listProjectMembers(
    List<String> projectIds,
  );
}

class SupabaseYorksV1ProjectPortfolioDataClient
    implements YorksV1ProjectPortfolioDataClient {
  const SupabaseYorksV1ProjectPortfolioDataClient(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> listProjects() async {
    final rows = await _client
        .from('v1_projects')
        .select(
          'id, project_ref, name, job_contract_reference, project_site, '
          'start_date, target_completion_date, notes, state, '
          'current_action_owner_role, record_version, created_at, updated_at',
        )
        .order('updated_at', ascending: false);
    return _rows(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> listProjectParties(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return const [];
    final rows = await _client
        .from('v1_project_parties')
        .select('project_id, party_kind, party_order, party_name')
        .inFilter('project_id', projectIds)
        .eq('party_kind', YorksV1ProjectPartyKind.client.wireValue)
        .order('party_order');
    return _rows(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> listProjectScopes(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return const [];
    final rows = await _client
        .from('v1_project_scopes')
        .select('project_id, scope_kind, is_active')
        .inFilter('project_id', projectIds)
        .eq('scope_kind', YorksV1ProjectScopeKind.building.wireValue)
        .eq('is_active', true);
    return _rows(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> listProjectMembers(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return const [];
    final rows = await _client
        .from('v1_project_members')
        .select(
          'id, project_id, member_auth_user_id, project_role, '
          'effective_from, effective_to, created_at',
        )
        .inFilter('project_id', projectIds);
    return _rows(rows);
  }

  List<Map<String, dynamic>> _rows(Object? response) {
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return [
      for (final row in response)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
}

abstract interface class YorksV1ProjectPortfolioRepository {
  Future<List<YorksV1ProjectPortfolioItem>> listPortfolio();
}

/// Non-commercial R35 project portfolio backed by existing V1 RLS policies.
///
/// Each source table already has a select policy which calls
/// `v1_project_readable`. That database predicate is the access authority for
/// this view: project engineers only receive active memberships, Procurement
/// receives active/on-hold projects, and Admin receives its authorized view.
class YorksV1SupabaseProjectPortfolioRepository
    implements YorksV1ProjectPortfolioRepository {
  const YorksV1SupabaseProjectPortfolioRepository({
    required YorksV1FeatureFlags featureFlags,
    YorksV1ProjectPortfolioDataClient? dataClient,
  }) : _featureFlags = featureFlags,
       _dataClient = dataClient;

  final YorksV1FeatureFlags _featureFlags;
  final YorksV1ProjectPortfolioDataClient? _dataClient;

  @override
  Future<List<YorksV1ProjectPortfolioItem>> listPortfolio() async {
    if (!_featureFlags.projects) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    final client = _dataClient;
    if (client == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }

    try {
      final projectRows = await client.listProjects();
      final projects = [
        for (final row in projectRows) YorksV1Project.fromRpcJson(row),
      ];
      if (projects.isEmpty) return const [];

      final ids = projects.map((project) => project.id).toList(growable: false);
      final results = await Future.wait([
        client.listProjectParties(ids),
        client.listProjectScopes(ids),
        client.listProjectMembers(ids),
      ]);
      final clients = _clientNames(results[0]);
      final buildingCounts = _buildingCounts(results[1]);
      final memberCounts = _memberCounts(results[2]);
      final activeMembers = _activeMembers(results[2]);

      return [
        for (final project in projects)
          YorksV1ProjectPortfolioItem(
            project: project,
            clientName: clients[project.id],
            activeBuildingCount: buildingCounts[project.id] ?? 0,
            activeProjectEngineerCount:
                memberCounts[project.id]?.projectEngineers ?? 0,
            activeSiteEngineerCount:
                memberCounts[project.id]?.siteEngineers ?? 0,
            activeMembers: activeMembers[project.id] ?? const [],
          ),
      ];
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  Map<String, String> _clientNames(List<Map<String, dynamic>> rows) {
    final names = <String, String>{};
    for (final row in rows) {
      final projectId = _string(row['project_id']);
      final name = _string(row['party_name']);
      if (projectId == null || name == null || names.containsKey(projectId)) {
        continue;
      }
      names[projectId] = name;
    }
    return names;
  }

  Map<String, int> _buildingCounts(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final projectId = _string(row['project_id']);
      if (projectId == null) continue;
      counts.update(projectId, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, _TeamCounts> _memberCounts(List<Map<String, dynamic>> rows) {
    final counts = <String, _TeamCounts>{};
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      final projectId = _string(row['project_id']);
      final role = YorksV1ProjectMembershipRole.fromWireValue(
        row['project_role'],
      );
      if (projectId == null ||
          role == null ||
          !_isCurrentMembership(row, now)) {
        continue;
      }
      final current = counts[projectId] ?? const _TeamCounts();
      counts[projectId] = switch (role) {
        YorksV1ProjectMembershipRole.projectEngineer => current.copyWith(
          projectEngineers: current.projectEngineers + 1,
        ),
        YorksV1ProjectMembershipRole.siteEngineer => current.copyWith(
          siteEngineers: current.siteEngineers + 1,
        ),
      };
    }
    return counts;
  }

  Map<String, List<YorksV1ProjectMember>> _activeMembers(
    List<Map<String, dynamic>> rows,
  ) {
    final members = <String, List<YorksV1ProjectMember>>{};
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      final projectId = _string(row['project_id']);
      if (projectId == null || !_isCurrentMembership(row, now)) continue;
      try {
        final member = YorksV1ProjectMember.fromRpcJson(row);
        members.putIfAbsent(projectId, () => []).add(member);
      } on YorksV1DomainException {
        // This is a typed non-commercial display projection. Ignore one
        // malformed historical row rather than preventing the project list
        // from rendering; commands still re-read and validate server state.
      }
    }
    return {
      for (final entry in members.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  bool _isCurrentMembership(Map<String, dynamic> row, DateTime now) {
    final effectiveFrom = _date(row['effective_from']);
    final effectiveTo = _date(row['effective_to']);
    return (effectiveFrom == null || !effectiveFrom.isAfter(now)) &&
        (effectiveTo == null || effectiveTo.isAfter(now));
  }

  String? _string(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  YorksV1DomainException _mapPostgrestException(PostgrestException error) {
    final code = error.code;
    final domainCode = switch (code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(domainCode, serverCode: code, cause: error);
  }
}

class _TeamCounts {
  const _TeamCounts({this.projectEngineers = 0, this.siteEngineers = 0});

  final int projectEngineers;
  final int siteEngineers;

  _TeamCounts copyWith({int? projectEngineers, int? siteEngineers}) {
    return _TeamCounts(
      projectEngineers: projectEngineers ?? this.projectEngineers,
      siteEngineers: siteEngineers ?? this.siteEngineers,
    );
  }
}
