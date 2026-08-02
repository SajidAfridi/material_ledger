import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_document_file_service_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';

/// Controlled documents are created as immutable Storage versions. The screen
/// never receives a signed path: every read and write remains server-authorized.
class YorksV1DocumentsScreen extends ConsumerStatefulWidget {
  const YorksV1DocumentsScreen({
    super.key,
    required this.projectId,
    this.focusEntityType,
    this.focusEntityId,
  });

  final String projectId;
  final String? focusEntityType;
  final String? focusEntityId;

  @override
  ConsumerState<YorksV1DocumentsScreen> createState() =>
      _YorksV1DocumentsScreenState();
}

class _YorksV1DocumentsScreenState
    extends ConsumerState<YorksV1DocumentsScreen> {
  bool _working = false;

  YorksV1DocumentEntityType get _targetEntityType =>
      YorksV1DocumentEntityType.fromWireValue(widget.focusEntityType) ??
      YorksV1DocumentEntityType.project;

  String get _targetEntityId => widget.focusEntityId ?? widget.projectId;

  bool get _hasFocusedRecord =>
      widget.focusEntityId != null &&
      YorksV1DocumentEntityType.fromWireValue(widget.focusEntityType) != null;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(
      yorksV1DocumentWorkspaceProvider(widget.projectId),
    );
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _CopyText(
                copy: YorksV1DocumentStrings.documents,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: YorksV1DocumentStrings.retry.primary,
                  onPressed: _working ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      floatingActionButton: compactRoute
          ? FloatingActionButton.extended(
              onPressed: _working ? null : () => _uploadNewVersion(),
              icon: _working
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(YorksV1DocumentStrings.addDocument.primary),
            )
          : null,
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(onRetry: _refresh),
        data: (value) => _WorkspaceBody(
          workspace: value,
          language: language,
          targetEntityType: _targetEntityType,
          targetEntityId: _targetEntityId,
          focusedRecord: _hasFocusedRecord,
          busy: _working,
          onUploadVersion: (document) => _uploadNewVersion(document: document),
          onDownload: _download,
          onLink: _link,
          onRemove: _remove,
          showPageHeader: !compactRoute,
          onCreateDocument: () => _uploadNewVersion(),
        ),
      ),
    );
  }

  Future<void> _uploadNewVersion({YorksV1Document? document}) async {
    final role = ref.read(yorksV1CurrentRoleProvider);
    final classification =
        document?.classification ?? await _classification(role);
    if (classification == null) return;
    final selected = await ref
        .read(yorksV1DocumentFileServiceProvider)
        .selectDocument();
    if (selected == null || !mounted) return;
    setState(() => _working = true);
    try {
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .upload(
            YorksV1DocumentUploadInput(
              projectId: widget.projectId,
              entityType: _targetEntityType,
              entityId: _targetEntityId,
              classification: classification,
              fileName: selected.fileName,
              mimeType: selected.mimeType,
              bytes: selected.bytes,
              documentId: document?.id,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      _refresh();
      _snack(context, YorksV1DocumentStrings.uploadSucceeded.primary);
    } catch (_) {
      if (mounted) _snack(context, YorksV1DocumentStrings.uploadFailed.primary);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<YorksV1DocumentClassification?> _classification(
    YorksV1Role? role,
  ) async {
    final available = [
      YorksV1DocumentClassification.operational,
      if (role == YorksV1Role.procurement || role == YorksV1Role.admin)
        YorksV1DocumentClassification.commercial,
      if (role == YorksV1Role.admin)
        YorksV1DocumentClassification.adminRestricted,
    ];
    var selected = available.first;
    return showDialog<YorksV1DocumentClassification>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(YorksV1DocumentStrings.selectClassification.primary),
          content: DropdownButtonFormField<YorksV1DocumentClassification>(
            initialValue: selected,
            decoration: InputDecoration(
              labelText: YorksV1DocumentStrings.classification.primary,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final value in available)
                DropdownMenuItem(
                  value: value,
                  child: Text(yorksV1DocumentClassificationCopy(value).primary),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(YorksV1DocumentStrings.cancel.primary),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(YorksV1DocumentStrings.confirm.primary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(YorksV1Document document) async {
    setState(() => _working = true);
    try {
      final version = document.currentVersion;
      final bytes = await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .downloadDocument(
            bucketId: version.bucketId,
            objectPath: version.objectPath,
          );
      final saved = await ref
          .read(yorksV1DocumentFileServiceProvider)
          .saveDocument(
            bytes: bytes,
            fileName: version.fileName,
            mimeType: version.mimeType,
          );
      if (mounted && saved) {
        _snack(context, YorksV1DocumentStrings.download.primary);
      }
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1DocumentStrings.downloadFailed.primary);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _link(YorksV1Document document) async {
    setState(() => _working = true);
    try {
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .linkDocument(
            YorksV1DocumentLinkInput(
              documentId: document.id,
              entityType: _targetEntityType,
              entityId: _targetEntityId,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      _refresh();
      _snack(context, YorksV1DocumentStrings.documentLinked.primary);
    } catch (_) {
      if (mounted) _snack(context, YorksV1DocumentStrings.linkFailed.primary);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(YorksV1Document document) async {
    final link = document.links.where(
      (value) =>
          value.entityType == _targetEntityType &&
          value.entityId == _targetEntityId,
    );
    if (link.isEmpty) return;
    final reason = await _removalReason();
    if (reason == null || !mounted) return;
    setState(() => _working = true);
    try {
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .removeDocumentLink(
            YorksV1DocumentLinkRemovalInput(
              documentLinkId: link.first.id,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      _refresh();
      _snack(context, YorksV1DocumentStrings.linkRemoved.primary);
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1DocumentStrings.removeFailed.primary);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _removalReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(YorksV1DocumentStrings.removeLink.primary),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: YorksV1DocumentStrings.removalReason.primary,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(YorksV1DocumentStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(YorksV1DocumentStrings.removeLink.primary),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  void _refresh() =>
      ref.invalidate(yorksV1DocumentWorkspaceProvider(widget.projectId));
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.workspace,
    required this.language,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.focusedRecord,
    required this.busy,
    required this.onUploadVersion,
    required this.onDownload,
    required this.onLink,
    required this.onRemove,
    required this.showPageHeader,
    required this.onCreateDocument,
  });

  final YorksV1DocumentWorkspace workspace;
  final AppLanguage language;
  final YorksV1DocumentEntityType targetEntityType;
  final String targetEntityId;
  final bool focusedRecord;
  final bool busy;
  final ValueChanged<YorksV1Document> onUploadVersion;
  final ValueChanged<YorksV1Document> onDownload;
  final ValueChanged<YorksV1Document> onLink;
  final ValueChanged<YorksV1Document> onRemove;
  final bool showPageHeader;
  final VoidCallback onCreateDocument;

  @override
  Widget build(BuildContext context) {
    final documents = focusedRecord
        ? workspace.documents
              .where(
                (document) =>
                    document.isLinkedTo(targetEntityType, targetEntityId),
              )
              .toList(growable: false)
        : workspace.documents;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.pageMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showPageHeader) ...[
                    YorksR35PageHeader(
                      eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                      title: YorksV1DocumentStrings.documents.primary,
                      description:
                          YorksV1DocumentStrings.documentsDescription.primary,
                      actions: [
                        SizedBox(
                          height: AppSpacing.minTapTarget,
                          child: FilledButton.icon(
                            onPressed: busy ? null : onCreateDocument,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              YorksV1DocumentStrings.addDocument.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  NexusSectionCard(
                    child: _CopyText(
                      copy: YorksV1DocumentStrings.documentsDescription,
                      language: language,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1DocumentStrings.documents.primary,
                    child: documents.isEmpty
                        ? _CopyText(
                            copy: YorksV1DocumentStrings.noDocuments,
                            language: language,
                            center: true,
                          )
                        : Column(
                            children: [
                              for (final document in documents)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: _DocumentCard(
                                    document: document,
                                    language: language,
                                    focusedRecord: focusedRecord,
                                    targetEntityType: targetEntityType,
                                    targetEntityId: targetEntityId,
                                    busy: busy,
                                    onUploadVersion: onUploadVersion,
                                    onDownload: onDownload,
                                    onLink: onLink,
                                    onRemove: onRemove,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1DocumentStrings.activity.primary,
                    child: _AuditList(
                      entries: workspace.auditEntries,
                      language: language,
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
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.language,
    required this.focusedRecord,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.busy,
    required this.onUploadVersion,
    required this.onDownload,
    required this.onLink,
    required this.onRemove,
  });

  final YorksV1Document document;
  final AppLanguage language;
  final bool focusedRecord;
  final YorksV1DocumentEntityType targetEntityType;
  final String targetEntityId;
  final bool busy;
  final ValueChanged<YorksV1Document> onUploadVersion;
  final ValueChanged<YorksV1Document> onDownload;
  final ValueChanged<YorksV1Document> onLink;
  final ValueChanged<YorksV1Document> onRemove;

  @override
  Widget build(BuildContext context) {
    final version = document.currentVersion;
    final linkedHere = document.isLinkedTo(targetEntityType, targetEntityId);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(_iconForMime(version.mimeType), color: AppColors.primary),
                Text(
                  version.fileName,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _ClassificationChip(classification: document.classification),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${YorksV1DocumentStrings.currentVersion.primary} · '
              '${YorksV1DocumentStrings.revision.primary} ${version.revisionNumber}',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${version.uploadedByDisplayName} · ${version.uploadedByRole} · '
              '${DateFormat('d MMM yyyy, HH:mm').format(version.uploadedAt)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${YorksV1DocumentStrings.linkedTo.primary}: '
              '${document.links.map((link) => yorksV1DocumentEntityLabel(link.entityType)).join(', ')}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SecondaryButton(
                  label: YorksV1DocumentStrings.download.primary,
                  isExpanded: false,
                  icon: Icons.download_outlined,
                  onPressed: busy ? null : () => onDownload(document),
                ),
                if (!focusedRecord || linkedHere)
                  SecondaryButton(
                    label: YorksV1DocumentStrings.uploadVersion.primary,
                    isExpanded: false,
                    icon: Icons.upload_file_outlined,
                    onPressed: busy ? null : () => onUploadVersion(document),
                  ),
                if (focusedRecord && !linkedHere)
                  SecondaryButton(
                    label: YorksV1DocumentStrings.linkDocument.primary,
                    isExpanded: false,
                    icon: Icons.link_rounded,
                    onPressed: busy ? null : () => onLink(document),
                  ),
                if (focusedRecord && linkedHere && document.links.length > 1)
                  SecondaryButton(
                    label: YorksV1DocumentStrings.removeLink.primary,
                    isExpanded: false,
                    icon: Icons.link_off_rounded,
                    onPressed: busy ? null : () => onRemove(document),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassificationChip extends StatelessWidget {
  const _ClassificationChip({required this.classification});
  final YorksV1DocumentClassification classification;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(yorksV1DocumentClassificationCopy(classification).primary),
    visualDensity: VisualDensity.compact,
  );
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.entries, required this.language});
  final List<YorksV1AuditEvent> entries;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _CopyText(
        copy: YorksV1DocumentStrings.auditSafeNotice,
        language: language,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CopyText(
          copy: YorksV1DocumentStrings.auditSafeNotice,
          language: language,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in entries.take(20))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              '${entry.eventType.replaceAll('_', ' ')} · '
              '${entry.actorDisplayName} (${entry.actorRole}) · '
              '${DateFormat('d MMM yyyy, HH:mm').format(entry.occurredAt)}',
              style: AppTypography.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SecondaryButton(
      label: YorksV1DocumentStrings.retry.primary,
      icon: Icons.refresh_rounded,
      onPressed: onRetry,
    ),
  );
}

class _CopyText extends StatelessWidget {
  const _CopyText({
    required this.copy,
    required this.language,
    this.style,
    this.center = false,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle? style;
  final bool center;

  @override
  Widget build(BuildContext context) => BilingualText(
    english: copy.primary,
    secondary: copy.secondary(language),
    englishStyle: style ?? AppTypography.bodyMedium,
    secondaryStyle: (style ?? AppTypography.bodyMedium).copyWith(
      color: AppColors.muted,
    ),
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
  );
}

IconData _iconForMime(String mimeType) => switch (mimeType) {
  'application/pdf' => Icons.picture_as_pdf_outlined,
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
    Icons.table_chart_outlined,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
    Icons.description_outlined,
  _ => Icons.image_outlined,
};

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
