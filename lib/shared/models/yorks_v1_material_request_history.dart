class YorksV1MaterialRequestHistoryQuery {
  const YorksV1MaterialRequestHistoryQuery({
    required this.requestId,
    this.beforeOccurredAt,
    this.beforeId,
    this.limit = 5,
  });

  final String requestId;
  final DateTime? beforeOccurredAt;
  final String? beforeId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialRequestHistoryQuery &&
      other.requestId == requestId &&
      other.beforeOccurredAt == beforeOccurredAt &&
      other.beforeId == beforeId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(requestId, beforeOccurredAt, beforeId, limit);

  Map<String, Object?> toRpcParameters() => {
    'p_request_id': requestId,
    'p_before_occurred_at': beforeOccurredAt?.toUtc().toIso8601String(),
    'p_before_id': beforeId,
    'p_limit': limit,
  };
}

class YorksV1MaterialRequestHistoryPage {
  const YorksV1MaterialRequestHistoryPage({
    required this.items,
    required this.hasMore,
    this.nextBeforeOccurredAt,
    this.nextBeforeId,
  });

  final List<YorksV1MaterialRequestHistoryEvent> items;
  final bool hasMore;
  final DateTime? nextBeforeOccurredAt;
  final String? nextBeforeId;

  factory YorksV1MaterialRequestHistoryPage.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => YorksV1MaterialRequestHistoryEvent.fromRpcJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <YorksV1MaterialRequestHistoryEvent>[];
    return YorksV1MaterialRequestHistoryPage(
      items: items,
      hasMore: json['has_more'] == true,
      nextBeforeOccurredAt: _dateTimeOrNull(json['next_before_occurred_at']),
      nextBeforeId: _textOrNull(json['next_before_id']),
    );
  }
}

class YorksV1MaterialRequestHistoryEvent {
  const YorksV1MaterialRequestHistoryEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.occurredAt,
    required this.actorDisplayName,
    required this.actorExactRole,
    required this.reference,
    required this.facts,
  });

  final String id;
  final String eventType;
  final String entityType;
  final DateTime occurredAt;
  final String? actorDisplayName;
  final String? actorExactRole;
  final String? reference;
  final Map<String, String> facts;

  factory YorksV1MaterialRequestHistoryEvent.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final rawFacts = json['facts'];
    return YorksV1MaterialRequestHistoryEvent(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      occurredAt:
          _dateTimeOrNull(json['occurred_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      actorDisplayName: _textOrNull(json['actor_display_name']),
      actorExactRole: _textOrNull(json['actor_exact_role']),
      reference: _textOrNull(json['reference']),
      facts: rawFacts is Map
          ? {
              for (final entry in rawFacts.entries)
                if (entry.value != null &&
                    entry.value.toString().trim().isNotEmpty)
                  entry.key.toString(): entry.value.toString(),
            }
          : const {},
    );
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  final text = _textOrNull(value);
  return text == null ? null : DateTime.tryParse(text)?.toUtc();
}

String? _textOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
