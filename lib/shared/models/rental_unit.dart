import 'dart:convert';

/// What kind of rented space this is.
enum RentalType {
  shop('Shop', 'محل', 'دکان', 'दुकान'),
  workshop('Workshop', 'ورشة', 'ورکشاپ', 'कार्यशाला');

  const RentalType(this.label, this.ar, this.ur, this.hi);
  final String label;
  final String ar;
  final String ur;
  final String hi;

  static RentalType fromName(String n) =>
      RentalType.values.firstWhere((t) => t.name == n, orElse: () => shop);
}

/// Occupancy state of a rental unit.
enum RentalStatus {
  active('Active', 'نشط', 'فعال', 'सक्रिय'),
  vacant('Vacant', 'شاغر', 'خالی', 'खाली');

  const RentalStatus(this.label, this.ar, this.ur, this.hi);
  final String label;
  final String ar;
  final String ur;
  final String hi;

  static RentalStatus fromName(String n) =>
      RentalStatus.values.firstWhere((s) => s.name == n, orElse: () => vacant);
}

/// A shop/workshop the company rents out to a tenant (Rentals module, FR-117).
class RentalUnit {
  const RentalUnit({
    required this.id,
    required this.unitName,
    required this.type,
    required this.location,
    required this.monthlyRentAED,
    this.tenantName,
    this.tenantContact,
    this.leaseStart,
    this.leaseEnd,
    this.status = RentalStatus.vacant,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String unitName;
  final RentalType type;
  final String location;
  final double monthlyRentAED;
  final String? tenantName;
  final String? tenantContact;
  final DateTime? leaseStart;
  final DateTime? leaseEnd;
  final RentalStatus status;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  bool get isOccupied => status == RentalStatus.active;

  RentalUnit copyWith({
    String? unitName,
    RentalType? type,
    String? location,
    double? monthlyRentAED,
    String? tenantName,
    String? tenantContact,
    DateTime? leaseStart,
    DateTime? leaseEnd,
    RentalStatus? status,
    String? notes,
  }) => RentalUnit(
    id: id,
    unitName: unitName ?? this.unitName,
    type: type ?? this.type,
    location: location ?? this.location,
    monthlyRentAED: monthlyRentAED ?? this.monthlyRentAED,
    tenantName: tenantName ?? this.tenantName,
    tenantContact: tenantContact ?? this.tenantContact,
    leaseStart: leaseStart ?? this.leaseStart,
    leaseEnd: leaseEnd ?? this.leaseEnd,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    createdBy: createdBy,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'unitName': unitName,
    'type': type.name,
    'location': location,
    'monthlyRentAED': monthlyRentAED,
    'tenantName': tenantName,
    'tenantContact': tenantContact,
    'leaseStart': leaseStart?.toIso8601String(),
    'leaseEnd': leaseEnd?.toIso8601String(),
    'status': status.name,
    'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RentalUnit.fromJson(Map<String, dynamic> json) => RentalUnit(
    id: json['id'] as String,
    unitName: json['unitName'] as String,
    type: RentalType.fromName(json['type'] as String? ?? 'shop'),
    location: json['location'] as String? ?? '',
    monthlyRentAED: (json['monthlyRentAED'] as num).toDouble(),
    tenantName: json['tenantName'] as String?,
    tenantContact: json['tenantContact'] as String?,
    leaseStart: json['leaseStart'] == null
        ? null
        : DateTime.parse(json['leaseStart'] as String),
    leaseEnd: json['leaseEnd'] == null
        ? null
        : DateTime.parse(json['leaseEnd'] as String),
    status: RentalStatus.fromName(json['status'] as String? ?? 'vacant'),
    notes: json['notes'] as String?,
    createdBy: json['createdBy'] as String? ?? 'system',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String encodeList(List<RentalUnit> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<RentalUnit> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => RentalUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
