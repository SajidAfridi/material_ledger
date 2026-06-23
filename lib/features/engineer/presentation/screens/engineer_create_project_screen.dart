import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Lightweight project creation flow for engineers.
class EngineerCreateProjectScreen extends ConsumerStatefulWidget {
  const EngineerCreateProjectScreen({super.key});

  @override
  ConsumerState<EngineerCreateProjectScreen> createState() =>
      _EngineerCreateProjectScreenState();
}

class _EngineerCreateProjectScreenState
    extends ConsumerState<EngineerCreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _secondaryNameController = TextEditingController();
  final _clientController = TextEditingController();
  final _locationController = TextEditingController();
  final _buildingNameController = TextEditingController();
  final _floorNumbersController = TextEditingController();
  final _siteNotesController = TextEditingController();

  DateTime? _startDate = DateTime.now();
  DateTime? _expectedEndDate;

  @override
  void dispose() {
    _nameController.dispose();
    _secondaryNameController.dispose();
    _clientController.dispose();
    _locationController.dispose();
    _buildingNameController.dispose();
    _floorNumbersController.dispose();
    _siteNotesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If expected end date is before start date, clear it
        if (_expectedEndDate != null && _expectedEndDate!.isBefore(picked)) {
          _expectedEndDate = null;
        }
      });
    }
  }

  Future<void> _selectExpectedEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expectedEndDate ??
          (_startDate ?? DateTime.now()).add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expectedEndDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.startDateRequired.primary)),
      );
      return;
    }

    final now = DateTime.now();
    final project = Project(
      id: 'proj-${now.microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      nameSecondary: _secondaryNameController.text.trim(),
      clientName: _clientController.text.trim(),
      siteLocation: _locationController.text.trim(),
      buildingName: _buildingNameController.text.trim(),
      floorNumbers: _floorNumbersController.text.trim(),
      startDate: _startDate,
      expectedEndDate: _expectedEndDate,
      siteNotes: _emptyToNull(_siteNotesController.text),
      phase: const ProjectPhase(
        number: 1,
        name: 'Planning',
        nameSecondary: 'پلاننگ',
        state: ProjectState.planning,
      ),
      lastUpdated: now,
    );

    ref.read(projectsProvider.notifier).addProject(project);
    ref.logAudit(
      action: 'Project created',
      module: AuditModule.materials,
      refId: project.id,
      detail: project.name,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.projectCreated.primary)));
    context.go(RoutePaths.engineerProjects);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;
          final horizontalPadding = isWide
              ? AppSpacing.xxl
              : AppSpacing.screenHorizontal;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.lg,
                      horizontalPadding,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _Header(onBack: context.pop),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: LedgerCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LedgerTextField(
                                controller: _nameController,
                                label: AppStrings.projectName.primary,
                                urduHint: AppStrings.projectName.ur,
                                autofocus: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppStrings.fieldRequired.primary;
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Enter at least 3 characters';
                                  }
                                  return null;
                                },
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _secondaryNameController,
                                label: AppStrings.projectNameSecondary.primary,
                                urduHint: AppStrings.projectNameSecondary.ur,
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _clientController,
                                label: AppStrings.clientName.primary,
                                urduHint: AppStrings.clientName.ur,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppStrings
                                        .clientNameRequired
                                        .primary;
                                  }
                                  return null;
                                },
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _locationController,
                                label: AppStrings.siteLocation.primary,
                                urduHint: AppStrings.siteLocation.ur,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppStrings.locationRequired.primary;
                                  }
                                  return null;
                                },
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _buildingNameController,
                                label: AppStrings.buildingName.primary,
                                urduHint: AppStrings.buildingName.ur,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppStrings
                                        .buildingNameRequired
                                        .primary;
                                  }
                                  return null;
                                },
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _floorNumbersController,
                                label: AppStrings.floorNumbers.primary,
                                urduHint: AppStrings.floorNumbers.ur,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppStrings
                                        .floorNumbersRequired
                                        .primary;
                                  }
                                  return null;
                                },
                              ),
                              const Gap(AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: LedgerTextField(
                                      controller: TextEditingController(
                                        text: _formatDate(_startDate),
                                      ),
                                      label: AppStrings.startDate.primary,
                                      urduHint: AppStrings.startDate.ur,
                                      readOnly: true,
                                      onTap: _selectStartDate,
                                      suffixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                      ),
                                      validator: (value) {
                                        if (_startDate == null) {
                                          return AppStrings
                                              .startDateRequired
                                              .primary;
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const Gap(AppSpacing.md),
                                  Expanded(
                                    child: LedgerTextField(
                                      controller: TextEditingController(
                                        text: _formatDate(_expectedEndDate),
                                      ),
                                      label: AppStrings.expectedEndDate.primary,
                                      urduHint: AppStrings.expectedEndDate.ur,
                                      readOnly: true,
                                      onTap: _selectExpectedEndDate,
                                      suffixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _siteNotesController,
                                label: AppStrings.siteNotes.primary,
                                urduHint: AppStrings.siteNotes.ur,
                                maxLines: 3,
                              ),
                              const Gap(AppSpacing.xxl),
                              PrimaryButton(
                                label: AppStrings.createProject.primary,
                                icon: Icons.check_rounded,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverGap(AppSpacing.colossal),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(foregroundColor: AppColors.onSurface),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: Text(
            AppStrings.createProject.primary,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
