import 'yorks_v1_domain_error.dart';
import 'yorks_v1_role.dart';

/// The deliberately small, non-commercial identity projection used only for
/// selecting a project team member during V1 project creation.
///
/// [authUserId] is an opaque command input: presentation must use
/// [displayName] and must never render the identifier. The safe directory RPC
/// does not include email, capabilities, legacy application IDs, or raw Auth
/// metadata, and this model intentionally has no fields for them.
class YorksV1ProjectTeamDirectoryMember {
  const YorksV1ProjectTeamDirectoryMember({
    required this.authUserId,
    required this.displayName,
    required this.eligibleRole,
  });

  final String authUserId;
  final String displayName;

  /// The active base role returned by the safe directory. Project assignment
  /// role remains an explicit, server-validated creation-time choice.
  final YorksV1Role eligibleRole;

  factory YorksV1ProjectTeamDirectoryMember.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final authUserId = _requiredDirectoryString(json['auth_user_id']);
    final returnedDisplayName = _requiredDirectoryString(json['display_name']);
    final parsedRole = YorksV1Role.fromServerClaim(json['eligible_role']);
    if (parsedRole != YorksV1Role.projectEngineer &&
        parsedRole != YorksV1Role.siteEngineer) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1ProjectTeamDirectoryMember(
      authUserId: authUserId,
      // The server supplies the opaque UUID as its fallback. Retaining that
      // sentinel lets presentation show generic localized copy instead of a
      // malformed or privacy-sensitive directory label.
      displayName: isEmailLikeDisplayName(returnedDisplayName)
          ? authUserId
          : returnedDisplayName,
      eligibleRole: parsedRole!,
    );
  }

  /// Treat any `@`-containing label as privacy-sensitive. This deliberately
  /// errs on the side of suppressing a rare display name so an email address,
  /// including one embedded in a longer label, can never reach the picker.
  static bool isEmailLikeDisplayName(String value) => value.contains('@');
}

String _requiredDirectoryString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const YorksV1DomainException(YorksV1DomainErrorCode.unexpectedResponse);
}
