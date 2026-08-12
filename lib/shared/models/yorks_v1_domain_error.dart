/// Stable machine-readable failures for Yorks V1 domain operations.
///
/// Presentation maps these codes to localized copy. Keeping copy outside this
/// layer prevents a repository, controller, log or test fixture from becoming
/// an accidental source of user-facing strings.
enum YorksV1DomainErrorCode {
  featureDisabled,
  offline,
  backendUnavailable,
  unauthenticated,
  unauthorized,
  invalidInput,
  invalidTransition,
  insufficientStock,
  quantityCapExceeded,
  immutableRecord,
  incompleteReview,
  conflict,
  serverRejected,
  unexpectedResponse,
}

class YorksV1DomainException implements Exception {
  const YorksV1DomainException(this.code, {this.serverCode, this.cause});

  final YorksV1DomainErrorCode code;
  final String? serverCode;
  final Object? cause;

  @override
  String toString() => 'YorksV1DomainException(${code.name})';
}
