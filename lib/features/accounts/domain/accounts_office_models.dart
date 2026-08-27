import 'accounts_decimal.dart';

enum YorksAccountsOfficeSection {
  claims('claims'),
  clientPayments('client_payments'),
  supplierBills('supplier_bills'),
  dueSchedule('due_schedule'),
  documents('documents'),
  activity('activity');

  const YorksAccountsOfficeSection(this.wireValue);

  final String wireValue;
}

final class YorksAccountsOfficeFilters {
  const YorksAccountsOfficeFilters({
    this.search,
    this.status,
    this.limit = 25,
    this.offset = 0,
  });

  final String? search;
  final String? status;
  final int limit;
  final int offset;

  bool get isValid => limit >= 1 && limit <= 100 && offset >= 0;

  Map<String, Object?> toRpcParameters(YorksAccountsOfficeSection section) => {
    'p_section': section.wireValue,
    'p_search': _nullable(search),
    'p_status': _nullable(status),
    'p_limit': limit,
    'p_offset': offset,
  };

  YorksAccountsOfficeFilters nextPage(int nextOffset) =>
      YorksAccountsOfficeFilters(
        search: search,
        status: status,
        limit: limit,
        offset: nextOffset,
      );
}

final class YorksAccountsOfficeSummary {
  const YorksAccountsOfficeSummary({
    required this.amount,
    required this.secondaryAmount,
    required this.balanceAmount,
    required this.actionCount,
  });

  final YorksAccountsDecimal amount;
  final YorksAccountsDecimal secondaryAmount;
  final YorksAccountsDecimal balanceAmount;
  final int actionCount;

  factory YorksAccountsOfficeSummary.fromRpcJson(Map<String, dynamic> json) =>
      YorksAccountsOfficeSummary(
        amount: _decimal(json, 'amount'),
        secondaryAmount: _decimal(json, 'secondary_amount'),
        balanceAmount: _decimal(json, 'balance_amount'),
        actionCount: _nonNegativeInt(json['action_count'], 'action_count'),
      );
}

final class YorksAccountsOfficeItem {
  const YorksAccountsOfficeItem({
    required this.recordId,
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.reference,
    required this.status,
    required this.occurredAt,
    required this.actionRequired,
    required this.recordKind,
    required this.currencyCode,
    required this.metadata,
    this.party,
    this.secondaryReference,
    this.amount,
    this.secondaryAmount,
    this.balanceAmount,
    this.eventDate,
    this.dueDate,
  });

  final String recordId;
  final String projectId;
  final String projectReference;
  final String projectName;
  final String? party;
  final String reference;
  final String? secondaryReference;
  final String status;
  final YorksAccountsDecimal? amount;
  final YorksAccountsDecimal? secondaryAmount;
  final YorksAccountsDecimal? balanceAmount;
  final DateTime? eventDate;
  final DateTime? dueDate;
  final DateTime occurredAt;
  final bool actionRequired;
  final String recordKind;
  final String currencyCode;
  final Map<String, dynamic> metadata;

  factory YorksAccountsOfficeItem.fromRpcJson(Map<String, dynamic> json) =>
      YorksAccountsOfficeItem(
        recordId: _string(json, 'record_id'),
        projectId: _string(json, 'project_id'),
        projectReference: _string(json, 'project_reference'),
        projectName: _string(json, 'project_name'),
        party: _optionalString(json['party']),
        reference: _string(json, 'reference'),
        secondaryReference: _optionalString(json['secondary_reference']),
        status: _string(json, 'status'),
        amount: _optionalDecimal(json, 'amount'),
        secondaryAmount: _optionalDecimal(json, 'secondary_amount'),
        balanceAmount: _optionalDecimal(json, 'balance_amount'),
        eventDate: _optionalDate(json['event_date'], 'event_date'),
        dueDate: _optionalDate(json['due_date'], 'due_date'),
        occurredAt: _date(json, 'occurred_at'),
        actionRequired: _bool(json, 'action_required'),
        recordKind: _string(json, 'record_kind'),
        currencyCode: _string(json, 'currency_code'),
        metadata: _map(json, 'metadata'),
      );
}

final class YorksAccountsOfficeProjection {
  const YorksAccountsOfficeProjection({
    required this.section,
    required this.total,
    required this.limit,
    required this.offset,
    required this.summary,
    required this.items,
  });

  final YorksAccountsOfficeSection section;
  final int total;
  final int limit;
  final int offset;
  final YorksAccountsOfficeSummary summary;
  final List<YorksAccountsOfficeItem> items;

  bool get hasMore => offset + items.length < total;

  factory YorksAccountsOfficeProjection.fromRpcJson(Map<String, dynamic> json) {
    final section = YorksAccountsOfficeSection.values
        .where((value) => value.wireValue == json['section'])
        .firstOrNull;
    if (section == null) {
      throw const FormatException('Invalid Account Office section.');
    }
    return YorksAccountsOfficeProjection(
      section: section,
      total: _nonNegativeInt(json['total'], 'total'),
      limit: _positiveInt(json['limit'], 'limit'),
      offset: _nonNegativeInt(json['offset'], 'offset'),
      summary: YorksAccountsOfficeSummary.fromRpcJson(_map(json, 'summary')),
      items: _mapList(
        json['items'],
      ).map(YorksAccountsOfficeItem.fromRpcJson).toList(growable: false),
    );
  }

  YorksAccountsOfficeProjection append(YorksAccountsOfficeProjection next) {
    if (section != next.section || total != next.total) {
      throw const FormatException('Account Office page identity mismatch.');
    }
    return YorksAccountsOfficeProjection(
      section: section,
      total: total,
      limit: limit,
      offset: offset,
      summary: summary,
      items: [...items, ...next.items],
    );
  }
}

String? _nullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.', value);
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.', value);
  return value;
}

int _positiveInt(Object? value, String key) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    throw FormatException('$key must be a positive integer.', value);
  }
  return parsed;
}

int _nonNegativeInt(Object? value, String key) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw FormatException('$key must be a non-negative integer.', value);
  }
  return parsed;
}

YorksAccountsDecimal _decimal(Map<String, dynamic> json, String key) =>
    YorksAccountsDecimal.fromRpcValue(json[key], key: key);

YorksAccountsDecimal? _optionalDecimal(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return YorksAccountsDecimal.fromRpcValue(value, key: key);
}

DateTime _date(Map<String, dynamic> json, String key) {
  final raw = _string(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('$key must be a date.', raw);
  return parsed;
}

DateTime? _optionalDate(Object? value, String key) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) throw FormatException('$key must be a date.', value);
  return parsed;
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be an object.', value);
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) throw FormatException('Expected a JSON list.', value);
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('Expected a JSON object.', item);
        }
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}
