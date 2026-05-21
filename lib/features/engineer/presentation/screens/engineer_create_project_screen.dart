import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/project.dart';
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
  final _phaseNameController = TextEditingController(text: 'Planning');

  ProjectState _state = ProjectState.planning;

  @override
  void dispose() {
    _nameController.dispose();
    _secondaryNameController.dispose();
    _clientController.dispose();
    _locationController.dispose();
    _phaseNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final project = Project(
      id: 'proj-${now.microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      nameSecondary: _secondaryNameController.text.trim(),
      clientName: _emptyToNull(_clientController.text),
      siteLocation: _emptyToNull(_locationController.text),
      phase: ProjectPhase(
        number: 1,
        name: _phaseNameController.text.trim().isEmpty
            ? _state.label
            : _phaseNameController.text.trim(),
        nameSecondary: '',
        state: _state,
      ),
      lastUpdated: now,
    );

    ref.read(projectsProvider.notifier).addProject(project);
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
    return SafeArea(
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
                                label: 'Project name',
                                hintText: 'e.g. Sector 7-G Tower C — HVAC',
                                autofocus: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Project name is required';
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
                                label: 'Secondary name',
                                hintText: 'Optional Urdu / Arabic name',
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _clientController,
                                label: 'Client',
                                hintText: 'Client or company name',
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _locationController,
                                label: 'Site location',
                                hintText: 'City, area, or plot location',
                              ),
                              const Gap(AppSpacing.lg),
                              LedgerTextField(
                                controller: _phaseNameController,
                                label: 'Phase name',
                                hintText: 'Planning, Active, Procurement...',
                              ),
                              const Gap(AppSpacing.lg),
                              _StateDropdown(
                                value: _state,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _state = value;
                                    if (_phaseNameController.text
                                            .trim()
                                            .isEmpty ||
                                        ProjectState.values.any(
                                          (state) =>
                                              state.label ==
                                              _phaseNameController.text.trim(),
                                        )) {
                                      _phaseNameController.text = value.label;
                                    }
                                  });
                                },
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

class _StateDropdown extends StatelessWidget {
  const _StateDropdown({required this.value, required this.onChanged});

  final ProjectState value;
  final ValueChanged<ProjectState?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project status', style: AppTypography.titleSmall),
        const Gap(AppSpacing.sm),
        DropdownButtonFormField<ProjectState>(
          initialValue: value,
          items: ProjectState.values
              .map(
                (state) =>
                    DropdownMenuItem(value: state, child: Text(state.label)),
              )
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
      ],
    );
  }
}
