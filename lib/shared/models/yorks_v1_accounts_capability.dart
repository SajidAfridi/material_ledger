import 'yorks_v1_permission_management.dart';

/// The exact R39 Accounts capabilities recognized by this client.
///
/// Wire values are the canonical snake_case keys from the R39 contract. The
/// existing dotted `accounts.*` catalogue entries are legacy compatibility
/// facts and never authorize these commands. The server remains authoritative
/// for grants, project scope and command preconditions; this enum only gives
/// Flutter a closed, testable vocabulary for role-safe response modelling.
enum YorksV1AccountsCapability {
  viewProjectAccounts(YorksV1CapabilityKeys.viewProjectAccounts),
  viewProjectCommercialValues(
    YorksV1CapabilityKeys.viewProjectCommercialValues,
  ),
  suggestBillingProgress(YorksV1CapabilityKeys.suggestBillingProgress),
  confirmBillingProgress(YorksV1CapabilityKeys.confirmBillingProgress),
  prepareClientClaim(YorksV1CapabilityKeys.prepareClientClaim),
  manageClientInvoices(YorksV1CapabilityKeys.manageClientInvoices),
  recordClientCertification(YorksV1CapabilityKeys.recordClientCertification),
  recordClientPayment(YorksV1CapabilityKeys.recordClientPayment),
  managePdc(YorksV1CapabilityKeys.managePdc),
  manageSupplierBills(YorksV1CapabilityKeys.manageSupplierBills),
  approveSupplierBillPayment(YorksV1CapabilityKeys.approveSupplierBillPayment),
  configureProjectCommercials(
    YorksV1CapabilityKeys.configureProjectCommercials,
  ),
  viewSupplierCosts(YorksV1CapabilityKeys.viewSupplierCosts),
  exportAccountsRegisters(YorksV1CapabilityKeys.exportAccountsRegisters),
  reviewCommercialProgress(YorksV1CapabilityKeys.reviewCommercialProgress);

  const YorksV1AccountsCapability(this.capabilityKey);

  final String capabilityKey;

  static YorksV1AccountsCapability? fromCapabilityKey(Object? value) {
    if (value is! String) return null;
    for (final capability in values) {
      if (capability.capabilityKey == value) return capability;
    }
    return null;
  }

  static final Set<String> allCapabilityKeys = Set.unmodifiable({
    for (final capability in values) capability.capabilityKey,
  });
}
