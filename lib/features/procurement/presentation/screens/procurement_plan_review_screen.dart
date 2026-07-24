import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/material_line_grid_controller.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/services/catalogue_csv_download.dart';
import '../../../../shared/services/material_line_csv_export.dart';
import '../../../../shared/widgets/material_line_grid.dart';

/// Procurement's Phase 1 advisory review.
///
/// Stock figures are a current snapshot only. Selecting Warehouse, External or
/// Mixed does not allocate, reserve, issue or order any quantity.
class ProcurementPlanReviewScreen extends ConsumerStatefulWidget {
  const ProcurementPlanReviewScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProcurementPlanReviewScreen> createState() =>
      _ProcurementPlanReviewScreenState();
}

class _ProcurementPlanReviewScreenState
    extends ConsumerState<ProcurementPlanReviewScreen> {
  final _commentController = TextEditingController();
  String? _commentLineId;
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _setSource(
    MaterialPlan plan,
    PlanItem item,
    PlanProposedSource source,
    MaterialItem? stock,
  ) {
    return ref
        .read(materialPlansProvider.notifier)
        .setProposedSource(
          planId: plan.id,
          itemId: item.id,
          source: source,
          onHandQty: stock?.quantity,
          availableQty: stock?.availableQty,
        );
  }

  Future<void> _addComment(MaterialPlan plan) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final actor = ref.read(currentUserProvider);
    await ref
        .read(materialPlansProvider.notifier)
        .addComment(
          planId: plan.id,
          text: text,
          authorName: actor?.fullName ?? ref.read(actorNameProvider),
          authorRole: ref.read(currentRoleProvider).label,
          lineItemId: _commentLineId,
        );
    final lang = ref.read(languageProvider);
    final projectName =
        ref.read(projectsProvider.notifier).byId(widget.projectId)?.name ??
        widget.projectId;
    await ref
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.plan,
          title: AppStrings.notifPlanCommentTitle.primary,
          titleSecondary: AppStrings.notifPlanCommentTitle.secondary(lang),
          body: '$projectName · "$text"',
          refId: widget.projectId,
          route: RoutePaths.planReviewPath(widget.projectId),
          audience: UserRole.engineer.name,
        );
    _commentController.clear();
    if (!mounted) return;
    setState(() => _commentLineId = null);
    FocusScope.of(context).unfocus();
  }

  Future<void> _sendReady(MaterialPlan plan, String projectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_ProcurementPlanCopy.readyTitle.primary),
        content: Text(_ProcurementPlanCopy.readyBody.primary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_ProcurementPlanCopy.sendForApproval.primary),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await ref
        .read(materialPlansProvider.notifier)
        .sendReadyForApproval(plan.id);
    final lang = ref.read(languageProvider);
    await ref
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.plan,
          title: AppStrings.notifPlanMarkedDoneTitle.primary,
          titleSecondary: AppStrings.notifPlanMarkedDoneTitle.secondary(lang),
          body: '$projectName · ${_ProcurementPlanCopy.readyNotice.primary}',
          refId: widget.projectId,
          route: RoutePaths.planReviewPath(widget.projectId),
          audience: UserRole.engineer.name,
        );
    await ref.logAudit(
      action: 'Material plan ready for approval',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: 'Version ${plan.version} · ${plan.items.length} lines',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppFeedback.confirm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_ProcurementPlanCopy.sent.primary)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(nexusFeatureFlagsProvider).procurementReview) {
      return const NexusFeatureUnavailableScreen(
        title: 'Procurement plan review',
      );
    }
    final lang = ref.watch(languageProvider);
    final plan = ref.watch(planForProjectProvider(widget.projectId));
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);
    final materials = ref.watch(materialsProvider);
    final stockById = {for (final material in materials) material.id: material};
    final projectName = project?.name ?? widget.projectId;
    final units = [
      for (final unit in ref.watch(materialUnitsProvider))
        if (unit.isSelectable) unit.symbol,
    ];

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }
    final reviewable = {
      MaterialPlanStatus.submitted,
      MaterialPlanStatus.procurementReview,
    }.contains(plan.status);
    final reviewed = plan.items
        .where((item) => item.proposedSource != PlanProposedSource.notReviewed)
        .length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.reviewPlan.primary,
          secondary: AppStrings.reviewPlan.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            120,
          ),
          children: [
            CurrentActionCard(
              title: projectName,
              message: _ProcurementPlanCopy.advisory.primary,
              ownerLabel: _ProcurementPlanCopy.reviewProgress.primary,
              ownerName: '$reviewed / ${plan.items.length}',
              tone: plan.allSourcesReviewed
                  ? NexusStatusTone.success
                  : NexusStatusTone.info,
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReadOnlyPlanGrid(
              plan: plan,
              units: units.isEmpty ? const ['Nos', 'm', 'set'] : units,
            ),
            const SizedBox(height: AppSpacing.lg),
            NexusSectionCard(
              title: _ProcurementPlanCopy.sourceReview.primary,
              description: _ProcurementPlanCopy.sourceDescription.primary,
              trailing: StatusChip.info('$reviewed / ${plan.items.length}'),
              child: Column(
                children: [
                  for (var index = 0; index < plan.items.length; index++)
                    _SourceReviewRow(
                      item: plan.items[index],
                      stock: stockById[plan.items[index].materialId],
                      editable: reviewable,
                      showDivider: index != plan.items.length - 1,
                      onChanged: (source) => _setSource(
                        plan,
                        plan.items[index],
                        source,
                        stockById[plan.items[index].materialId],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlanCommentsCard(
              plan: plan,
              controller: _commentController,
              selectedLineId: _commentLineId,
              onLineChanged: (value) => setState(() => _commentLineId = value),
              onSend: reviewable ? () => _addComment(plan) : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _VersionActivityCard(plan: plan),
          ],
        ),
      ),
      bottomNavigationBar: reviewable
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PrimaryButton(
                      label: _ProcurementPlanCopy.sendForApproval.primary,
                      icon: Icons.send_rounded,
                      isLoading: _busy,
                      onPressed: plan.allSourcesReviewed && !_busy
                          ? () => _sendReady(plan, projectName)
                          : null,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ReadOnlyPlanGrid extends StatefulWidget {
  const _ReadOnlyPlanGrid({required this.plan, required this.units});

  final MaterialPlan plan;
  final List<String> units;

  @override
  State<_ReadOnlyPlanGrid> createState() => _ReadOnlyPlanGridState();
}

class _ReadOnlyPlanGridState extends State<_ReadOnlyPlanGrid> {
  late MaterialLineGridController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyPlanGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.updatedAt != widget.plan.updatedAt ||
        oldWidget.plan.version != widget.plan.version) {
      _controller.dispose();
      _controller = _buildController();
    }
  }

  MaterialLineGridController _buildController() => MaterialLineGridController(
    lines: [for (final item in widget.plan.items) item.toMaterialLineDraft()],
    commercialsEnabled: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final csv = MaterialLineCsvExport.build(
      lines: _controller.lines,
      includeCommercials: false,
    );
    final downloaded = await downloadCatalogueCsv(
      csv,
      filename: 'yorks-phase-1-plan-v${widget.plan.version}.csv',
    );
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialLineGrid(
      key: const ValueKey('procurement-phase-one-grid'),
      controller: _controller,
      units: widget.units,
      editable: false,
      onExport: _export,
      desktopHeight: 500,
    );
  }
}

class _SourceReviewRow extends StatelessWidget {
  const _SourceReviewRow({
    required this.item,
    required this.stock,
    required this.editable,
    required this.showDivider,
    required this.onChanged,
  });

  final PlanItem item;
  final MaterialItem? stock;
  final bool editable;
  final bool showDivider;
  final ValueChanged<PlanProposedSource> onChanged;

  @override
  Widget build(BuildContext context) {
    final onHand = stock?.quantity ?? item.onHandQtySnapshot;
    final available = stock?.availableQty ?? item.availableQtySnapshot;
    final stockCopy = stock == null
        ? _ProcurementPlanCopy.notCatalogue.primary
        : '${_ProcurementPlanCopy.onHand.primary}: ${_number(onHand)} ${item.unitSymbol} · '
              '${_ProcurementPlanCopy.available.primary}: ${_number(available)} ${item.unitSymbol}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.line))
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.description, style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                stockCopy,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          );
          final source = DropdownButtonFormField<PlanProposedSource>(
            key: ValueKey('plan-source-${item.id}'),
            initialValue: item.proposedSource,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _ProcurementPlanCopy.proposedSource.primary,
            ),
            items: [
              for (final option in PlanProposedSource.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: editable
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: AppSpacing.sm),
                source,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(width: 240, child: source),
            ],
          );
        },
      ),
    );
  }

  String _number(double? value) {
    if (value == null) return '—';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

class _PlanCommentsCard extends StatelessWidget {
  const _PlanCommentsCard({
    required this.plan,
    required this.controller,
    required this.selectedLineId,
    required this.onLineChanged,
    required this.onSend,
  });

  final MaterialPlan plan;
  final TextEditingController controller;
  final String? selectedLineId;
  final ValueChanged<String?> onLineChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    String scope(PlanComment comment) {
      if (comment.lineItemId == null) {
        return _ProcurementPlanCopy.wholePlan.primary;
      }
      return plan.items
              .where((item) => item.id == comment.lineItemId)
              .firstOrNull
              ?.description ??
          _ProcurementPlanCopy.lineComment.primary;
    }

    return NexusSectionCard(
      title: AppStrings.comments.primary,
      description: _ProcurementPlanCopy.commentsDescription.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final comment in plan.comments) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${comment.authorName} · ${comment.authorRole}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    scope(comment),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(comment.text),
                ],
              ),
            ),
          ],
          if (onSend != null) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: selectedLineId,
              decoration: InputDecoration(
                labelText: _ProcurementPlanCopy.commentScope.primary,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(_ProcurementPlanCopy.wholePlan.primary),
                ),
                for (final item in plan.items)
                  DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(
                      item.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onLineChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppStrings.addComment.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VersionActivityCard extends StatelessWidget {
  const _VersionActivityCard({required this.plan});

  final MaterialPlan plan;

  @override
  Widget build(BuildContext context) {
    return NexusSectionCard(
      title: _ProcurementPlanCopy.history.primary,
      description: _ProcurementPlanCopy.historyDescription.primary,
      child: Column(
        children: [
          for (final event in plan.activity.reversed.take(8))
            AuditTrailItem(
              action: event.action,
              detail: event.detail,
              actor: event.actorName,
              role: event.actorRole,
              timestamp: DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(event.timestamp.toLocal()),
            ),
        ],
      ),
    );
  }
}

abstract final class _ProcurementPlanCopy {
  static const advisory = TranslatableString(
    en: 'Review current availability and propose a source. This is advisory only and does not reserve stock.',
    ar: 'راجع التوفر الحالي واقترح مصدراً. هذه مراجعة استشارية فقط ولا تحجز المخزون.',
    ur: 'موجودہ دستیابی دیکھیں اور سورس تجویز کریں۔ یہ صرف مشاورتی ہے اور اسٹاک محفوظ نہیں کرتا۔',
    hi: 'वर्तमान उपलब्धता देखें और स्रोत प्रस्तावित करें। यह केवल सलाहकारी है और स्टॉक आरक्षित नहीं करता।',
  );
  static const reviewProgress = TranslatableString(
    en: 'Lines reviewed',
    ar: 'البنود المراجعة',
    ur: 'جائزہ شدہ لائنیں',
    hi: 'समीक्षित पंक्तियाँ',
  );
  static const sourceReview = TranslatableString(
    en: 'Availability & proposed source',
    ar: 'التوفر والمصدر المقترح',
    ur: 'دستیابی اور تجویز کردہ سورس',
    hi: 'उपलब्धता और प्रस्तावित स्रोत',
  );
  static const sourceDescription = TranslatableString(
    en: 'Warehouse, external supplier or mixed. Allocation starts only in Phase 2.',
    ar: 'المستودع أو مورد خارجي أو مزيج. يبدأ التخصيص في المرحلة الثانية فقط.',
    ur: 'گودام، بیرونی سپلائر یا مخلوط۔ الاٹمنٹ صرف فیز 2 میں شروع ہوتی ہے۔',
    hi: 'वेयरहाउस, बाहरी आपूर्तिकर्ता या मिश्रित। आवंटन केवल चरण 2 में शुरू होता है।',
  );
  static const proposedSource = TranslatableString(
    en: 'Proposed source',
    ar: 'المصدر المقترح',
    ur: 'تجویز کردہ سورس',
    hi: 'प्रस्तावित स्रोत',
  );
  static const onHand = TranslatableString(
    en: 'On hand',
    ar: 'المتوفر فعلياً',
    ur: 'موجود اسٹاک',
    hi: 'उपलब्ध स्टॉक',
  );
  static const available = TranslatableString(
    en: 'Available',
    ar: 'المتاح',
    ur: 'دستیاب',
    hi: 'उपलब्ध',
  );
  static const notCatalogue = TranslatableString(
    en: 'Custom / not in catalogue',
    ar: 'مخصص / غير موجود في الكتالوج',
    ur: 'کسٹم / کیٹلاگ میں نہیں',
    hi: 'कस्टम / कैटलॉग में नहीं',
  );
  static const commentsDescription = TranslatableString(
    en: 'Attach a comment to the whole plan or one exact line.',
    ar: 'أرفق تعليقاً بالخطة كاملة أو ببند محدد.',
    ur: 'تبصرہ پورے پلان یا کسی خاص لائن سے منسلک کریں۔',
    hi: 'टिप्पणी पूरी योजना या किसी एक पंक्ति से जोड़ें।',
  );
  static const commentScope = TranslatableString(
    en: 'Comment relates to',
    ar: 'التعليق متعلق بـ',
    ur: 'تبصرہ متعلق ہے',
    hi: 'टिप्पणी संबंधित है',
  );
  static const wholePlan = TranslatableString(
    en: 'Whole plan',
    ar: 'الخطة كاملة',
    ur: 'پورا پلان',
    hi: 'पूरी योजना',
  );
  static const lineComment = TranslatableString(
    en: 'Material line',
    ar: 'بند المواد',
    ur: 'میٹریل لائن',
    hi: 'सामग्री पंक्ति',
  );
  static const readyTitle = TranslatableString(
    en: 'Send this version for approval?',
    ar: 'إرسال هذا الإصدار للموافقة؟',
    ur: 'یہ ورژن منظوری کے لیے بھیجیں؟',
    hi: 'यह संस्करण अनुमोदन के लिए भेजें?',
  );
  static const readyBody = TranslatableString(
    en: 'Every line has a proposed source. The reviewed result becomes the comparison baseline for the Engineer.',
    ar: 'لكل بند مصدر مقترح. تصبح نتيجة المراجعة أساس المقارنة للمهندس.',
    ur: 'ہر لائن کا سورس تجویز ہو چکا ہے۔ جائزہ شدہ نتیجہ انجینئر کے موازنے کی بنیاد بنے گا۔',
    hi: 'हर पंक्ति का स्रोत प्रस्तावित है। समीक्षित परिणाम इंजीनियर की तुलना का आधार बनेगा।',
  );
  static const sendForApproval = TranslatableString(
    en: 'Send Ready for Approval',
    ar: 'إرسال جاهز للموافقة',
    ur: 'منظوری کے لیے تیار بھیجیں',
    hi: 'अनुमोदन हेतु तैयार भेजें',
  );
  static const readyNotice = TranslatableString(
    en: 'ready for your final review',
    ar: 'جاهز لمراجعتك النهائية',
    ur: 'آپ کے حتمی جائزے کے لیے تیار',
    hi: 'आपकी अंतिम समीक्षा के लिए तैयार',
  );
  static const sent = TranslatableString(
    en: 'Plan sent for Engineer approval.',
    ar: 'تم إرسال الخطة لموافقة المهندس.',
    ur: 'پلان انجینئر کی منظوری کے لیے بھیج دیا گیا۔',
    hi: 'योजना इंजीनियर अनुमोदन के लिए भेजी गई।',
  );
  static const history = TranslatableString(
    en: 'Version activity',
    ar: 'نشاط الإصدارات',
    ur: 'ورژن سرگرمی',
    hi: 'संस्करण गतिविधि',
  );
  static const historyDescription = TranslatableString(
    en: 'Who changed the plan, when, and what action moved it forward.',
    ar: 'من غيّر الخطة ومتى وما الإجراء الذي نقلها إلى الأمام.',
    ur: 'کس نے پلان بدلا، کب، اور کس کارروائی نے اسے آگے بڑھایا۔',
    hi: 'किसने योजना बदली, कब और किस कार्रवाई ने इसे आगे बढ़ाया।',
  );
}
