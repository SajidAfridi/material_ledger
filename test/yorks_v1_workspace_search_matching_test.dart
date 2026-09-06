import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_search.dart';

void main() {
  test('workspace search normalizes punctuation, spacing and Arabic marks', () {
    expect(
      normalizeYorksWorkspaceSearchText('  YRA-313 / A.C. Units  '),
      'yra 313 a c units',
    );
    expect(
      normalizeYorksWorkspaceSearchText('إِدارةُ المشاريع'),
      'اداره المشاريع',
    );
  });

  test('workspace search tolerates compact references and one typo', () {
    const haystack = 'yra 313 material request project';
    expect(yorksWorkspaceSearchTermMatches(haystack, 'yra313'), isTrue);
    expect(yorksWorkspaceSearchTermMatches(haystack, 'projct'), isTrue);
    expect(yorksWorkspaceSearchTermMatches(haystack, 'supplier'), isFalse);
  });
}
