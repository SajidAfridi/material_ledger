import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/material_line_grid_controller.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_line_draft.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/services/catalogue_csv_download.dart';
import '../../../../shared/services/material_line_csv_export.dart';
import '../../../../shared/widgets/material_line_grid.dart';
import '../widgets/custom_item_sheet.dart';
import '../widgets/inventory_picker_sheet.dart';

/// Phase 1 engineer plan editor using the reusable V7 material-line grid.
///
/// Operational lines autosave locally. A submitted version is an explicit
/// server-bound handoff to Procurement and cannot be edited in place.
class PlanBuildScreen extends ConsumerStatefulWidget {
  const PlanBuildScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<PlanBuildScreen> createState() => _PlanBuildScreenState();
}

class _PlanBuildScreenState extends ConsumerState<PlanBuildScreen> {
  static const _uuid = Uuid();
  late final MaterialLineGridController _gridController;
  final Map<String, PlanItem> _metadata = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(materialPlansProvider.notifier)
        .planForProject(widget.projectId);
    for (final item in existing?.items ?? const <PlanItem>[]) {
      _metadata[item.id] = item;
    }
    _gridController = MaterialLineGridController(
      lines: [
        for (final item in existing?.items ?? const <PlanItem>[])
          item.toMaterialLineDraft(),
      ],
      commercialsEnabled: false,
      onAutosave: (lines, _) => _saveDraft(lines),
    );
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  List<PlanItem> _toPlanItems(List<MaterialLineDraft> lines) => [
    for (final line in lines)
      PlanItem.fromMaterialLineDraft(line, previous: _metadata[line.id]),
  ];

  Future<void> _saveDraft(List<MaterialLineDraft> lines) {
    return ref
        .read(materialPlansProvider.notifier)
        .saveDraft(widget.projectId, _toPlanItems(lines));
  }

  Future<void> _addFromInventory() async {
    final picked = await InventoryPickerSheet.show(
      context,
      ref.read(materialsProvider),
    );
    if (picked == null) return;
    final item = PlanItem(
      id: 'pi-${_uuid.v4()}',
      materialId: picked.id,
      categoryId: picked.categoryMasterId,
      description: picked.name,
      descriptionSecondary: picked.urduName,
      brand: picked.brand,
      countryOfOrigin: picked.countryOfOrigin,
      size: picked.size,
      makeOrigin: [
        picked.brand,
        picked.countryOfOrigin,
      ].where((value) => value.isNotEmpty).join(' / '),
      quantity: 1,
      unitSymbol: picked.unit.symbol,
      ralColour: picked.ralColour,
      isCustom: false,
    );
    _metadata[item.id] = item;
    _gridController.addLine(item.toMaterialLineDraft());
  }

  Future<void> _addCustom() async {
    final item = await CustomItemSheet.show(context);
    if (item == null) return;
    _metadata[item.id] = item;
    _gridController.addLine(item.toMaterialLineDraft());
  }

  Future<void> _submit() async {
    await _gridController.flushAutosave();
    if (!mounted) return;
    final lines = _gridController.lines;
    final errors = _gridController.validateAll();
    if (lines.isEmpty || errors.isNotEmpty) {
      AppFeedback.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lines.isEmpty
                ? AppStrings.emptyPlan.primary
                : _PlanBuildCopy.fixRows.primary,
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_PlanBuildCopy.submitTitle.primary),
        content: Text(_PlanBuildCopy.submitBody.primary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.submitToProcurement.primary),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final items = _toPlanItems(lines);
    await ref
        .read(materialPlansProvider.notifier)
        .submitPlan(widget.projectId, items);

    final lang = ref.read(languageProvider);
    final projectName =
        ref.read(projectsProvider.notifier).byId(widget.projectId)?.name ??
        widget.projectId;
    await ref
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.plan,
          title: AppStrings.notifNewPlanTitle.primary,
          titleSecondary: AppStrings.notifNewPlanTitle.secondary(lang),
          body: '$projectName · ${items.length} ${AppStrings.items.primary}',
          refId: widget.projectId,
          route: RoutePaths.planReviewProcurementPath(widget.projectId),
          audience: UserRole.procurement.name,
        );
    await ref.logAudit(
      action: 'Material plan submitted',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: '${items.length} line items',
    );
    if (!mounted) return;
    AppFeedback.confirm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.planSubmitted.primary)));
    context.pop();
  }

  Future<void> _export() async {
    final csv = MaterialLineCsvExport.build(
      lines: _gridController.lines,
      includeCommercials: false,
    );
    final downloaded = await downloadCatalogueCsv(
      csv,
      filename: 'yorks-phase-1-plan-${widget.projectId}.csv',
    );
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? _PlanBuildCopy.exported.primary
              : _PlanBuildCopy.copied.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(nexusFeatureFlagsProvider).phase1Planning) {
      return const NexusFeatureUnavailableScreen(title: 'Material plan');
    }
    final lang = ref.watch(languageProvider);
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);
    final plan = ref.watch(planForProjectProvider(widget.projectId));
    final editable =
        plan == null ||
        {
          MaterialPlanStatus.draft,
          MaterialPlanStatus.rejected,
        }.contains(plan.status);
    final units = [
      for (final unit in ref.watch(materialUnitsProvider))
        if (unit.isSelectable) unit.symbol,
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.materialPlan.primary,
          secondary: AppStrings.materialPlan.secondary(lang),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project?.name ?? widget.projectId,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _PlanBuildCopy.subtitle.primary,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan != null)
                  StatusChip(
                    label: plan.status.label,
                    tone: editable
                        ? NexusStatusTone.neutral
                        : NexusStatusTone.info,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!editable) ...[
              CurrentActionCard(
                title: _PlanBuildCopy.lockedTitle.primary,
                message: _PlanBuildCopy.lockedBody.primary,
                ownerLabel: _PlanBuildCopy.currentOwner.primary,
                ownerName: plan.currentOwnerRole ?? UserRole.procurement.label,
                tone: NexusStatusTone.info,
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (editable)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('plan-add-catalogue'),
                    onPressed: _addFromInventory,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(AppStrings.addFromInventory.primary),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('plan-add-custom'),
                    onPressed: _addCustom,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(AppStrings.addCustomItem.primary),
                  ),
                ],
              ),
            if (editable) const SizedBox(height: AppSpacing.md),
            MaterialLineGrid(
              key: const ValueKey('phase-one-material-line-grid'),
              controller: _gridController,
              units: units.isEmpty ? const ['Nos', 'm', 'set'] : units,
              editable: editable,
              onExport: _export,
              desktopHeight: 580,
            ),
            const SizedBox(height: AppSpacing.lg),
            _LineScopeCard(
              project: project,
              controller: _gridController,
              metadata: _metadata,
              editable: editable,
              onChanged: () {
                setState(() {});
                _saveDraft(_gridController.lines);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: editable
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
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: PrimaryButton(
                      label: AppStrings.submitToProcurement.primary,
                      icon: Icons.send_rounded,
                      isLoading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _LineScopeCard extends StatelessWidget {
  const _LineScopeCard({
    required this.project,
    required this.controller,
    required this.metadata,
    required this.editable,
    required this.onChanged,
  });

  final Project? project;
  final MaterialLineGridController controller;
  final Map<String, PlanItem> metadata;
  final bool editable;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lines = controller.lines;
    return NexusSectionCard(
      title: _PlanBuildCopy.scopeTitle.primary,
      description: _PlanBuildCopy.scopeBody.primary,
      child: lines.isEmpty
          ? Text(
              AppStrings.emptyPlan.primary,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < lines.length; index++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      border: index == lines.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppColors.line),
                            ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final lineLabel = Text(
                          lines[index].description.isEmpty
                              ? '${AppStrings.items.primary} ${index + 1}'
                              : lines[index].description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium,
                        );
                        final scopeField = DropdownButtonFormField<String>(
                          key: ValueKey('plan-scope-${lines[index].id}'),
                          initialValue:
                              metadata[lines[index].id]?.buildingId ??
                              'project-wide',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _PlanBuildCopy.buildingScope.primary,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'project-wide',
                              child: Text(_PlanBuildCopy.projectWide.primary),
                            ),
                            for (final building
                                in project?.buildings ?? const [])
                              DropdownMenuItem(
                                value: building.id,
                                child: Text(building.name),
                              ),
                          ],
                          onChanged: editable
                              ? (value) {
                                  final current =
                                      metadata[lines[index].id] ??
                                      PlanItem.fromMaterialLineDraft(
                                        lines[index],
                                      );
                                  metadata[lines[index].id] = current.copyWith(
                                    buildingId: value ?? 'project-wide',
                                  );
                                  onChanged();
                                }
                              : null,
                        );
                        if (constraints.maxWidth < 560) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              lineLabel,
                              const SizedBox(height: AppSpacing.sm),
                              scopeField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: lineLabel),
                            const SizedBox(width: AppSpacing.md),
                            SizedBox(width: 230, child: scopeField),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

abstract final class _PlanBuildCopy {
  static const subtitle = TranslatableString(
    en: 'Build the expected project requirement, assign each line to a building scope, then submit one traceable version.',
    ar: 'أنشئ احتياج المشروع المتوقع وحدد نطاق المبنى لكل بند ثم أرسل إصداراً واحداً قابلاً للتتبع.',
    ur: 'متوقع پروجیکٹ ضرورت بنائیں، ہر لائن کو عمارت کے دائرے سے جوڑیں، پھر ایک قابلِ سراغ ورژن جمع کریں۔',
    hi: 'अपेक्षित परियोजना आवश्यकता बनाएँ, हर पंक्ति को भवन दायरे से जोड़ें, फिर एक ट्रेस करने योग्य संस्करण जमा करें।',
  );
  static const fixRows = TranslatableString(
    en: 'Complete the highlighted material rows before submitting.',
    ar: 'أكمل بنود المواد المحددة قبل الإرسال.',
    ur: 'جمع کرنے سے پہلے نمایاں میٹریل لائنیں مکمل کریں۔',
    hi: 'जमा करने से पहले चिह्नित सामग्री पंक्तियाँ पूरी करें।',
  );
  static const submitTitle = TranslatableString(
    en: 'Submit this plan version?',
    ar: 'إرسال إصدار خطة المواد؟',
    ur: 'یہ پلان ورژن جمع کریں؟',
    hi: 'यह योजना संस्करण जमा करें?',
  );
  static const submitBody = TranslatableString(
    en: 'Procurement will receive an immutable version for advisory availability and source review.',
    ar: 'ستستلم المشتريات إصداراً ثابتاً لمراجعة التوفر والمصدر بشكل استشاري.',
    ur: 'پروکیورمنٹ کو مشاورتی دستیابی اور سورس جائزے کے لیے ناقابلِ تبدیلی ورژن ملے گا۔',
    hi: 'खरीद टीम को सलाहकारी उपलब्धता और स्रोत समीक्षा के लिए अपरिवर्तनीय संस्करण मिलेगा।',
  );
  static const lockedTitle = TranslatableString(
    en: 'This submitted version is locked',
    ar: 'هذا الإصدار المرسل مقفل',
    ur: 'یہ جمع شدہ ورژن مقفل ہے',
    hi: 'यह जमा संस्करण लॉक है',
  );
  static const lockedBody = TranslatableString(
    en: 'Wait for the current owner. If changes are requested, edit a new version instead of overwriting this one.',
    ar: 'انتظر المسؤول الحالي. عند طلب تغييرات، عدّل إصداراً جديداً بدلاً من الكتابة فوق هذا الإصدار.',
    ur: 'موجودہ ذمہ دار کا انتظار کریں۔ تبدیلی مانگی جائے تو اس ورژن کو بدلنے کے بجائے نیا ورژن ترمیم کریں۔',
    hi: 'वर्तमान स्वामी की प्रतीक्षा करें। बदलाव माँगे जाने पर इस संस्करण को बदलने के बजाय नया संस्करण संपादित करें।',
  );
  static const currentOwner = TranslatableString(
    en: 'Current owner',
    ar: 'المسؤول الحالي',
    ur: 'موجودہ ذمہ دار',
    hi: 'वर्तमान स्वामी',
  );
  static const scopeTitle = TranslatableString(
    en: 'Line building scope',
    ar: 'نطاق المبنى للبنود',
    ur: 'لائن کی عمارت کا دائرہ',
    hi: 'पंक्ति भवन दायरा',
  );
  static const scopeBody = TranslatableString(
    en: 'Scope is kept in the line inspector so the approved material grid stays unchanged.',
    ar: 'يُحفظ النطاق في تفاصيل البند حتى يبقى جدول المواد المعتمد دون تغيير.',
    ur: 'دائرہ لائن انسپکٹر میں رکھا جاتا ہے تاکہ منظور شدہ میٹریل گرڈ تبدیل نہ ہو۔',
    hi: 'दायरा पंक्ति निरीक्षक में रखा जाता है ताकि स्वीकृत सामग्री ग्रिड अपरिवर्तित रहे।',
  );
  static const buildingScope = TranslatableString(
    en: 'Building scope',
    ar: 'نطاق المبنى',
    ur: 'عمارت کا دائرہ',
    hi: 'भवन दायरा',
  );
  static const projectWide = TranslatableString(
    en: 'Project-wide / Common',
    ar: 'على مستوى المشروع / مشترك',
    ur: 'پورا پروجیکٹ / مشترکہ',
    hi: 'परियोजना-व्यापी / सामान्य',
  );
  static const exported = TranslatableString(
    en: 'Material plan CSV downloaded.',
    ar: 'تم تنزيل ملف CSV لخطة المواد.',
    ur: 'میٹریل پلان CSV ڈاؤن لوڈ ہو گیا۔',
    hi: 'सामग्री योजना CSV डाउनलोड हुई।',
  );
  static const copied = TranslatableString(
    en: 'Material plan CSV copied to the clipboard.',
    ar: 'تم نسخ ملف CSV لخطة المواد إلى الحافظة.',
    ur: 'میٹریل پلان CSV کلپ بورڈ پر کاپی ہو گیا۔',
    hi: 'सामग्री योजना CSV क्लिपबोर्ड पर कॉपी हुई।',
  );
}
