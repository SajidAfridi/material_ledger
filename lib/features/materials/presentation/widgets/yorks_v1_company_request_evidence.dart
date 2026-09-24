import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_audit_strings.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';

final _evidenceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String, int)>(
      (ref, id) => ref
          .watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          .getEvidence(id.$1),
    );

/// History is fetched only on demand, through the current actor's protected RPC.
/// Issue facts are immutable dispatch snapshots, never current request totals.
class YorksV1CompanyRequestEvidence extends ConsumerStatefulWidget {
  const YorksV1CompanyRequestEvidence({
    required this.requestId,
    required this.recordVersion,
    required this.language,
    super.key,
  });
  final String requestId;
  final int recordVersion;
  final AppLanguage language;
  @override
  ConsumerState<YorksV1CompanyRequestEvidence> createState() =>
      _EvidenceState();
}

class _EvidenceState extends ConsumerState<YorksV1CompanyRequestEvidence> {
  bool _opened = false;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ExpansionTile(
      key: const ValueKey('company-evidence'),
      title: Text(
        YorksV1CompanyMaterialRequestStrings.evidence.active(widget.language),
      ),
      onExpansionChanged: (open) {
        if (open) setState(() => _opened = true);
      },
      childrenPadding: const EdgeInsets.all(16),
      children: [
        if (_opened)
          ref
              .watch(
                _evidenceProvider((widget.requestId, widget.recordVersion)),
              )
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => TextButton.icon(
                  onPressed: () => ref.invalidate(
                    _evidenceProvider((widget.requestId, widget.recordVersion)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    YorksV1CompanyMaterialRequestStrings.retry.active(
                      widget.language,
                    ),
                  ),
                ),
                data: (data) {
                  final events = (data['events'] as List? ?? const [])
                      .whereType<Map>();
                  final notes = (data['issue_notes'] as List? ?? const [])
                      .whereType<Map>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (events.isEmpty)
                        Text(
                          YorksV1CompanyMaterialRequestStrings.noActivity
                              .active(widget.language),
                        ),
                      for (final e in events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                YorksV1AuditStrings.eventLabel(
                                  e['event_type']?.toString() ?? '',
                                  widget.language,
                                ),
                                style: AppTypography.labelLarge,
                              ),
                              SelectableText(
                                '${e['actor_display_name'] ?? ''} · ${YorksV1AuditStrings.roleLabel(e['actor_exact_role']?.toString() ?? '', widget.language)} · ${_date(context, e['occurred_at'])}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                              if (e['reason'] != null)
                                SelectableText(e['reason'].toString()),
                            ],
                          ),
                        ),
                      for (final note in notes)
                        ExpansionTile(
                          title: Text(
                            note['issue_note_number']?.toString() ??
                                YorksV1CompanyMaterialRequestStrings.issueNote
                                    .active(widget.language),
                          ),
                          subtitle: Text(_date(context, note['created_at'])),
                          children: [
                            if (note['snapshot'] is Map)
                              for (final line
                                  in ((note['snapshot'] as Map)['lines']
                                              as List? ??
                                          const [])
                                      .whereType<Map>())
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          line['item_description']
                                                  ?.toString() ??
                                              '',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: SelectableText(
                                          '${line['quantity'] ?? ''} ${line['unit'] ?? ''}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                    ],
                  );
                },
              ),
      ],
    ),
  );
  String _date(BuildContext context, Object? raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }
}
