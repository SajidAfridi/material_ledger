import 'yorks_v1_project.dart';

/// The exact, recoverable R35 creation sequence. These are workflow positions,
/// not localized labels; presentation owns localized stage copy.
enum YorksV1ProjectCreationStage {
  projectDetails,
  partiesAndAccess,
  buildings,
  attachments,
  reviewAndCreate;

  static YorksV1ProjectCreationStage fromIndex(Object? value) {
    final index = switch (value) {
      int value => value,
      num value => value.toInt(),
      _ => 0,
    };
    if (index < 0) return YorksV1ProjectCreationStage.projectDetails;
    if (index >= YorksV1ProjectCreationStage.values.length) {
      return YorksV1ProjectCreationStage.reviewAndCreate;
    }
    return YorksV1ProjectCreationStage.values[index];
  }

  YorksV1ProjectCreationStage? get next {
    final index = this.index + 1;
    if (index >= YorksV1ProjectCreationStage.values.length) return null;
    return YorksV1ProjectCreationStage.values[index];
  }

  YorksV1ProjectCreationStage? get previous {
    final index = this.index - 1;
    if (index < 0) return null;
    return YorksV1ProjectCreationStage.values[index];
  }
}

/// Per-user, per-device local input for the V1 five-stage project creation
/// workflow. It is recoverable input only: a server command remains the sole
/// authority for creating a project, Common scope, memberships and BOQ groups.
class YorksV1ProjectCreationDraft {
  const YorksV1ProjectCreationDraft({
    required this.ownerAuthUserId,
    required this.currentStage,
    required this.creationIdempotencyKey,
    required this.reference,
    required this.name,
    required this.updatedAt,
    this.clientName,
    this.jobOrContractReference,
    this.siteLocation,
    this.clientContactName,
    this.clientContactPhone,
    this.clientContactEmail,
    this.clientAddress,
    this.startDate,
    this.endDate,
    this.notes,
    this.parties = const [],
    this.initialMembers = const [],
    this.buildings = const [],
    this.attachments = const [],
  });

  factory YorksV1ProjectCreationDraft.empty({
    required String ownerAuthUserId,
    required String creationIdempotencyKey,
  }) {
    return YorksV1ProjectCreationDraft(
      ownerAuthUserId: ownerAuthUserId,
      currentStage: YorksV1ProjectCreationStage.projectDetails,
      creationIdempotencyKey: creationIdempotencyKey,
      reference: '',
      name: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static const Object _keep = Object();

  /// Local isolation key. This is the authenticated Supabase user UUID, never
  /// an editable profile field or a legacy application-user identifier.
  final String ownerAuthUserId;
  final YorksV1ProjectCreationStage currentStage;

  /// Reused until the create RPC confirms a result, so a retry is safe.
  final String creationIdempotencyKey;
  final String reference;
  final String name;
  final String? clientName;
  final String? jobOrContractReference;
  final String? siteLocation;
  final String? clientContactName;
  final String? clientContactPhone;
  final String? clientContactEmail;
  final String? clientAddress;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final List<YorksV1ProjectPartyInput> parties;
  final List<YorksV1InitialProjectMemberInput> initialMembers;
  final List<YorksV1ProjectBuildingInput> buildings;
  final List<YorksV1ProjectAttachmentInput> attachments;
  final DateTime updatedAt;

  bool get hasRecoverableContent {
    return reference.trim().isNotEmpty ||
        name.trim().isNotEmpty ||
        (_trimToNull(clientName) != null) ||
        (_trimToNull(jobOrContractReference) != null) ||
        (_trimToNull(siteLocation) != null) ||
        (_trimToNull(clientContactName) != null) ||
        (_trimToNull(clientContactPhone) != null) ||
        (_trimToNull(clientContactEmail) != null) ||
        (_trimToNull(clientAddress) != null) ||
        (_trimToNull(notes) != null) ||
        startDate != null ||
        endDate != null ||
        parties.isNotEmpty ||
        initialMembers.isNotEmpty ||
        buildings.isNotEmpty ||
        attachments.isNotEmpty;
  }

  YorksV1ProjectCreationInput toCreationInput() {
    return YorksV1ProjectCreationInput(
      idempotencyKey: creationIdempotencyKey,
      reference: reference,
      name: name,
      clientName: clientName,
      jobOrContractReference: jobOrContractReference,
      siteLocation: siteLocation,
      clientContactName: clientContactName,
      clientContactPhone: clientContactPhone,
      clientContactEmail: clientContactEmail,
      clientAddress: clientAddress,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      parties: List.unmodifiable(parties),
      initialMembers: List.unmodifiable(initialMembers),
      buildings: List.unmodifiable(buildings),
      attachments: List.unmodifiable(attachments),
    );
  }

  YorksV1ProjectCreationDraft copyWith({
    YorksV1ProjectCreationStage? currentStage,
    String? creationIdempotencyKey,
    String? reference,
    String? name,
    Object? clientName = _keep,
    Object? jobOrContractReference = _keep,
    Object? siteLocation = _keep,
    Object? clientContactName = _keep,
    Object? clientContactPhone = _keep,
    Object? clientContactEmail = _keep,
    Object? clientAddress = _keep,
    Object? startDate = _keep,
    Object? endDate = _keep,
    Object? notes = _keep,
    List<YorksV1ProjectPartyInput>? parties,
    List<YorksV1InitialProjectMemberInput>? initialMembers,
    List<YorksV1ProjectBuildingInput>? buildings,
    List<YorksV1ProjectAttachmentInput>? attachments,
    DateTime? updatedAt,
  }) {
    return YorksV1ProjectCreationDraft(
      ownerAuthUserId: ownerAuthUserId,
      currentStage: currentStage ?? this.currentStage,
      creationIdempotencyKey:
          creationIdempotencyKey ?? this.creationIdempotencyKey,
      reference: reference ?? this.reference,
      name: name ?? this.name,
      clientName: identical(clientName, _keep)
          ? this.clientName
          : clientName as String?,
      jobOrContractReference: identical(jobOrContractReference, _keep)
          ? this.jobOrContractReference
          : jobOrContractReference as String?,
      siteLocation: identical(siteLocation, _keep)
          ? this.siteLocation
          : siteLocation as String?,
      clientContactName: identical(clientContactName, _keep)
          ? this.clientContactName
          : clientContactName as String?,
      clientContactPhone: identical(clientContactPhone, _keep)
          ? this.clientContactPhone
          : clientContactPhone as String?,
      clientContactEmail: identical(clientContactEmail, _keep)
          ? this.clientContactEmail
          : clientContactEmail as String?,
      clientAddress: identical(clientAddress, _keep)
          ? this.clientAddress
          : clientAddress as String?,
      startDate: identical(startDate, _keep)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, _keep) ? this.endDate : endDate as DateTime?,
      notes: identical(notes, _keep) ? this.notes : notes as String?,
      parties: List.unmodifiable(parties ?? this.parties),
      initialMembers: List.unmodifiable(initialMembers ?? this.initialMembers),
      buildings: List.unmodifiable(buildings ?? this.buildings),
      attachments: List.unmodifiable(attachments ?? this.attachments),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerAuthUserId': ownerAuthUserId,
    'currentStage': currentStage.index,
    'creationIdempotencyKey': creationIdempotencyKey,
    'reference': reference,
    'name': name,
    'clientName': clientName,
    'jobOrContractReference': jobOrContractReference,
    'siteLocation': siteLocation,
    'clientContactName': clientContactName,
    'clientContactPhone': clientContactPhone,
    'clientContactEmail': clientContactEmail,
    'clientAddress': clientAddress,
    // Project dates are calendar values, not instants. Persisting just the
    // date avoids a device timezone moving a selected date on recovery.
    'startDate': _calendarDateText(startDate),
    'endDate': _calendarDateText(endDate),
    'notes': notes,
    'parties': [for (final party in parties) party.toDraftJson()],
    'initialMembers': [
      for (final member in initialMembers) member.toDraftJson(),
    ],
    'buildings': [for (final building in buildings) building.toDraftJson()],
    'attachments': [
      for (final attachment in attachments) attachment.toDraftJson(),
    ],
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory YorksV1ProjectCreationDraft.fromJson(Map<String, dynamic> json) {
    return YorksV1ProjectCreationDraft(
      ownerAuthUserId: json['ownerAuthUserId'] as String? ?? '',
      currentStage: YorksV1ProjectCreationStage.fromIndex(json['currentStage']),
      creationIdempotencyKey: json['creationIdempotencyKey'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      name: json['name'] as String? ?? '',
      clientName: _trimToNull(json['clientName'] as String?),
      jobOrContractReference: _trimToNull(
        json['jobOrContractReference'] as String?,
      ),
      siteLocation: _trimToNull(json['siteLocation'] as String?),
      clientContactName: _trimToNull(json['clientContactName'] as String?),
      clientContactPhone: _trimToNull(json['clientContactPhone'] as String?),
      clientContactEmail: _trimToNull(json['clientContactEmail'] as String?),
      clientAddress: _trimToNull(json['clientAddress'] as String?),
      startDate: _calendarDate(json['startDate']),
      endDate: _calendarDate(json['endDate']),
      notes: _trimToNull(json['notes'] as String?),
      parties: _maps(
        json['parties'],
      ).map(YorksV1ProjectPartyInput.fromDraftJson).toList(growable: false),
      initialMembers: _maps(json['initialMembers'])
          .map(YorksV1InitialProjectMemberInput.fromDraftJson)
          .toList(growable: false),
      buildings: _maps(
        json['buildings'],
      ).map(YorksV1ProjectBuildingInput.fromDraftJson).toList(growable: false),
      attachments: _maps(json['attachments'])
          .map(YorksV1ProjectAttachmentInput.fromDraftJson)
          .toList(growable: false),
      updatedAt:
          _timestamp(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _timestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

/// Parses a date-only field without converting it to an instant. Older draft
/// values may include an ISO timestamp, so their written calendar component is
/// intentionally retained rather than converted through the device timezone.
DateTime? _calendarDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String? _calendarDateText(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (value is Map) Map<String, dynamic>.from(value),
  ];
}
