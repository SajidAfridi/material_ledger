import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_material_request_history.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/providers/yorks_v1_material_request_history_provider.dart';

/// A request-authorized summary of durable workflow activity. It deliberately
/// does not reuse the organization-wide Admin audit workspace.
class YorksV1MaterialRequestHistorySection extends ConsumerStatefulWidget {
  const YorksV1MaterialRequestHistorySection({
    super.key,
    required this.requestId,
    required this.language,
  });

  final String requestId;
  final AppLanguage language;

  @override
  ConsumerState<YorksV1MaterialRequestHistorySection> createState() =>
      _YorksV1MaterialRequestHistorySectionState();
}

class _YorksV1MaterialRequestHistorySectionState
    extends ConsumerState<YorksV1MaterialRequestHistorySection> {
  bool _showFullHistory = false;
  bool _loadingEarlier = false;
  bool _earlierHistoryFailed = false;
  List<YorksV1MaterialRequestHistoryEvent> _earlier = const [];
  bool? _earlierHasMore;
  DateTime? _nextBeforeOccurredAt;
  String? _nextBeforeId;

  @override
  void didUpdateWidget(
    covariant YorksV1MaterialRequestHistorySection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _showFullHistory = false;
      _loadingEarlier = false;
      _earlierHistoryFailed = false;
      _earlier = const [];
      _earlierHasMore = null;
      _nextBeforeOccurredAt = null;
      _nextBeforeId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = YorksV1MaterialRequestHistoryQuery(
      requestId: widget.requestId,
      limit: _showFullHistory ? 20 : 5,
    );
    final page = ref.watch(yorksV1MaterialRequestHistoryPageProvider(query));
    return _InspectorSurface(
      key: const ValueKey('material-request-history'),
      child: page.when(
        loading: () => SizedBox(
          height: 56,
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.blue),
              const SizedBox(width: AppSpacing.sm),
              Text(
                YorksV1MaterialRequestStrings.loadingRequestHistory.active(
                  widget.language,
                ),
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        error: (_, _) => _HistoryFailure(
          language: widget.language,
          onRetry: () =>
              ref.invalidate(yorksV1MaterialRequestHistoryPageProvider(query)),
        ),
        data: (value) => _HistoryContent(
          language: widget.language,
          items: [...value.items, ..._earlier],
          hasMore: _earlierHasMore ?? value.hasMore,
          loadingEarlier: _loadingEarlier,
          earlierHistoryFailed: _earlierHistoryFailed,
          showFullHistory: _showFullHistory,
          onShowFullHistory: _showFullHistory
              ? null
              : () => setState(() {
                  _showFullHistory = true;
                  _earlierHistoryFailed = false;
                  _earlier = const [];
                  _earlierHasMore = null;
                  _nextBeforeOccurredAt = null;
                  _nextBeforeId = null;
                }),
          onLoadEarlier: () => _loadEarlier(value),
        ),
      ),
    );
  }

  Future<void> _loadEarlier(YorksV1MaterialRequestHistoryPage current) async {
    final beforeOccurredAt =
        _nextBeforeOccurredAt ?? current.nextBeforeOccurredAt;
    final beforeId = _nextBeforeId ?? current.nextBeforeId;
    if (_loadingEarlier || beforeOccurredAt == null || beforeId == null) return;
    setState(() {
      _loadingEarlier = true;
      _earlierHistoryFailed = false;
    });
    try {
      final next = await ref
          .read(yorksV1MaterialRequestHistoryRepositoryProvider)
          .getHistory(
            YorksV1MaterialRequestHistoryQuery(
              requestId: widget.requestId,
              beforeOccurredAt: beforeOccurredAt,
              beforeId: beforeId,
              limit: 20,
            ),
          );
      if (!mounted) return;
      final known = <String>{
        for (final event in _earlier) event.id,
        for (final event in current.items) event.id,
      };
      setState(() {
        _earlier = [
          ..._earlier,
          for (final event in next.items)
            if (known.add(event.id)) event,
        ];
        _earlierHasMore = next.hasMore;
        _nextBeforeOccurredAt = next.nextBeforeOccurredAt;
        _nextBeforeId = next.nextBeforeId;
      });
    } catch (_) {
      if (mounted) setState(() => _earlierHistoryFailed = true);
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.language,
    required this.items,
    required this.hasMore,
    required this.loadingEarlier,
    required this.earlierHistoryFailed,
    required this.showFullHistory,
    required this.onShowFullHistory,
    required this.onLoadEarlier,
  });

  final AppLanguage language;
  final List<YorksV1MaterialRequestHistoryEvent> items;
  final bool hasMore;
  final bool loadingEarlier;
  final bool earlierHistoryFailed;
  final bool showFullHistory;
  final VoidCallback? onShowFullHistory;
  final VoidCallback onLoadEarlier;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.history_rounded, size: 20, color: AppColors.blue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              YorksV1MaterialRequestStrings.requestHistory.active(language),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        YorksV1MaterialRequestStrings.requestHistoryDescription.active(
          language,
        ),
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.md),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            YorksV1MaterialRequestStrings.noRequestHistory.active(language),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        )
      else
        for (var index = 0; index < items.length; index++)
          _HistoryEventTile(
            event: items[index],
            language: language,
            last: index == items.length - 1,
          ),
      if (!showFullHistory && hasMore) ...[
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onShowFullHistory,
          icon: const Icon(Icons.open_in_full_rounded, size: 18),
          label: Text(
            YorksV1MaterialRequestStrings.viewFullAuditTrail.active(language),
          ),
        ),
      ],
      if (showFullHistory && hasMore) ...[
        const SizedBox(height: AppSpacing.sm),
        if (earlierHistoryFailed) ...[
          Text(
            YorksV1MaterialRequestStrings.earlierHistoryUnavailable.active(
              language,
            ),
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        OutlinedButton(
          onPressed: loadingEarlier ? null : onLoadEarlier,
          child: loadingEarlier
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  YorksV1MaterialRequestStrings.loadEarlierHistory.active(
                    language,
                  ),
                ),
        ),
      ],
    ],
  );
}

class _HistoryEventTile extends StatelessWidget {
  const _HistoryEventTile({
    required this.event,
    required this.language,
    required this.last,
  });

  final YorksV1MaterialRequestHistoryEvent event;
  final AppLanguage language;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final actor = event.actorDisplayName?.trim().isNotEmpty == true
        ? event.actorDisplayName!
        : YorksV1MaterialRequestStrings.notRecorded.active(language);
    final role = event.actorExactRole?.trim().isNotEmpty == true
        ? YorksV1ProjectStrings.roleLabel(
            event.actorExactRole!,
          ).active(language)
        : YorksV1MaterialRequestStrings.notRecorded.active(language);
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(event.occurredAt.toLocal());
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(event.occurredAt.toLocal()));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.blueContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(event.eventType),
                    size: 15,
                    color: AppColors.blue,
                  ),
                ),
                if (!last)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelFor(event).active(language),
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$actor · $role',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date, $time',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String eventType) => switch (eventType) {
    'material_request_submitted' => Icons.outbox_outlined,
    'material_request_updated_for_approval' => Icons.edit_note_outlined,
    'material_request_decided' ||
    'material_request_approved' => Icons.verified_outlined,
    'material_request_returned_for_changes' => Icons.reply_outlined,
    'arrangement_saved' ||
    'preapproved_arrangement_finalized' => Icons.inventory_2_outlined,
    'procurement_item_clarified' => Icons.fact_check_outlined,
    'material_dispatch_created' ||
    'material_dispatched' ||
    'materials_dispatched' => Icons.local_shipping_outlined,
    'receipt_review_confirmed' ||
    'receipt_confirmed' => Icons.task_alt_outlined,
    'delivery_order_generated' => Icons.description_outlined,
    'material_return_submitted' ||
    'material_return_confirmed' => Icons.assignment_return_outlined,
    _ => Icons.history_rounded,
  };

  TranslatableString _labelFor(YorksV1MaterialRequestHistoryEvent event) {
    final eventType = event.eventType;
    if (eventType == 'material_request_decided') {
      final decision = event.facts['decision']?.toString().toLowerCase();
      if (decision == 'returned' ||
          decision == 'return' ||
          decision == 'returned_for_changes') {
        return YorksV1MaterialRequestStrings.returnedForChanges;
      }
    }
    return switch (eventType) {
      'material_request_created' =>
        YorksV1MaterialRequestStrings.historyRequestCreated,
      'material_request_updated_for_approval' =>
        YorksV1MaterialRequestStrings.requestUpdated,
      'material_request_submitted' =>
        YorksV1MaterialRequestStrings.submittedForApproval,
      'material_request_decided' ||
      'material_request_approved' ||
      'procurement_clarification_approved' =>
        YorksV1MaterialRequestStrings.requestApproved,
      'material_request_returned_for_changes' ||
      'procurement_clarification_returned' =>
        YorksV1MaterialRequestStrings.returnedForChanges,
      'arrangement_begun' ||
      'arrangement_saved' ||
      'preapproved_arrangement_finalized' ||
      'arrangement_approved' ||
      'arrangement_returned' =>
        YorksV1MaterialRequestStrings.procurementArrangementSaved,
      'procurement_item_clarified' =>
        YorksV1MaterialRequestStrings.itemClarified,
      'material_dispatch_created' ||
      'material_dispatched' ||
      'materials_dispatched' =>
        YorksV1MaterialRequestStrings.materialDispatched,
      'receipt_review_confirmed' ||
      'receipt_confirmed' => YorksV1MaterialRequestStrings.receiptConfirmed,
      'delivery_order_generated' =>
        YorksV1MaterialRequestStrings.deliveryOrderGenerated,
      'material_return_draft_saved' ||
      'material_return_submitted' ||
      'material_return_confirmed' =>
        YorksV1MaterialRequestStrings.materialReturnRecorded,
      _ => YorksV1MaterialRequestStrings.recordedActivity,
    };
  }
}

class _HistoryFailure extends StatelessWidget {
  const _HistoryFailure({required this.language, required this.onRetry});

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.history_rounded, size: 20, color: AppColors.blue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              YorksV1MaterialRequestStrings.requestHistory.active(language),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        YorksV1MaterialRequestStrings.requestHistoryUnavailable.active(
          language,
        ),
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton(
          onPressed: onRetry,
          child: Text(YorksV1MaterialRequestStrings.tryAgain.active(language)),
        ),
      ),
    ],
  );
}

class _InspectorSurface extends StatelessWidget {
  const _InspectorSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: child,
  );
}
