/// The operational roles. Admin is the all-in-one office/owner role (it absorbs
/// the former Accountant — finance/cost/salary/read-all — and signs in for the
/// owner). Procurement runs materials, rentals and (now) the People/HR module.
/// The company owner signs in via Admin (no separate owner role).
///
/// History: `accountant` was merged into `admin` (may be split out later);
/// People/HR was moved to `procurement` (kept on admin for now, later
/// procurement-only). See SRS v1.3 §3 / FR-132/133.
enum UserRole {
  engineer('Engineer', 'انجینئر', 'इंजीनियर'),
  procurement('Procurement', 'پروکیورمنٹ', 'खरीद'),
  admin('Admin', 'ایڈمن', 'एडमिन');

  const UserRole(this.label, this.labelUr, this.labelHi);

  final String label;
  final String labelUr;
  final String labelHi;

  static UserRole fromName(String name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.engineer,
  );

  // ─── Capabilities (mirror Security-Rules matrix, Appendix F/I) ───
  /// Inventory unit cost is visible to Admin/Procurement only.
  bool get canSeeCost => this == admin || this == procurement;

  /// Employee salary & documents are visible to Admin only. (Procurement runs
  /// HR operations but not compensation — widen here if that changes.)
  bool get canSeeSalary => this == admin;

  /// Admin has read-all across every module (and the owner signs in here).
  bool get isAdmin => this == admin;

  // Module access -------------------------------------------------------
  bool get canAccessMaterials => true; // all roles touch Materials
  bool get canAccessRentals => this == procurement || this == admin;
  bool get canAccessPeople => this == procurement || this == admin;

  // Write access --------------------------------------------------------
  bool get canWriteRentals => this == procurement || this == admin;
  bool get canWritePeople => this == procurement || this == admin;

  /// Record goods receipts into the store (procurement & admin).
  bool get canReceiveGoods => this == procurement || this == admin;

  /// View the finance / cost roll-up screens (Admin only — absorbed Accountant).
  bool get canViewFinance => this == admin;

  /// True for the office/web roles that use the multi-module admin panel.
  bool get usesAdminPanel => this != engineer;
}
