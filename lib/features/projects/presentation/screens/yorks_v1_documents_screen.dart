import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_document_file_service_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/services/yorks_v1_document_file_service.dart';

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
          onDropDocuments: _uploadDroppedDocuments,
          onDropError: () =>
              _snack(context, YorksV1DocumentStrings.uploadFailed.primary),
          onLinkExisting: () => _linkExistingDocument(value),
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
    await _uploadSelectedDocument(
      selected,
      classification: classification,
      document: document,
    );
  }

  Future<void> _uploadSelectedDocument(
    YorksV1SelectedDocument selected, {
    required YorksV1DocumentClassification classification,
    YorksV1Document? document,
  }) async {
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

  Future<void> _uploadDroppedDocuments(
    List<YorksV1SelectedDocument> selectedDocuments,
  ) async {
    if (selectedDocuments.isEmpty || _working) return;
    final classification = await _classification(
      ref.read(yorksV1CurrentRoleProvider),
    );
    if (classification == null || !mounted) return;
    setState(() => _working = true);
    var uploaded = 0;
    try {
      for (final selected in selectedDocuments) {
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
                idempotencyKey: const Uuid().v4(),
              ),
            );
        uploaded++;
      }
      if (!mounted) return;
      _refresh();
      _snack(context, YorksV1DocumentStrings.uploadSucceeded.primary);
    } catch (_) {
      if (mounted) {
        _refresh();
        _snack(context, YorksV1DocumentStrings.uploadFailed.primary);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
    // A partial browser drop is intentionally visible after refresh. Each
    // accepted file is its own idempotent controlled-document command.
    if (uploaded < selectedDocuments.length && mounted) _refresh();
  }

  Future<void> _linkExistingDocument(YorksV1DocumentWorkspace workspace) async {
    final available = workspace.documents
        .where(
          (document) =>
              !document.isLinkedTo(_targetEntityType, _targetEntityId),
        )
        .toList(growable: false);
    if (available.isEmpty) return;
    final selected = await showDialog<YorksV1Document>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialogContext) => AlertDialog(
        title: Text(YorksV1DocumentStrings.linkExistingDocument.primary),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: available.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final document = available[index];
              return ListTile(
                leading: Icon(
                  _iconForMime(document.currentVersion.mimeType),
                  color: AppColors.primary,
                ),
                title: Text(document.currentVersion.fileName),
                subtitle: Text(
                  '${YorksV1DocumentStrings.revision.primary} '
                  '${document.currentVersion.revisionNumber}',
                ),
                onTap: () => Navigator.of(dialogContext).pop(document),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(YorksV1DocumentStrings.cancel.primary),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _link(selected);
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
    required this.onDropDocuments,
    required this.onDropError,
    required this.onLinkExisting,
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
  final Future<void> Function(List<YorksV1SelectedDocument>) onDropDocuments;
  final VoidCallback onDropError;
  final VoidCallback onLinkExisting;

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
    final hasLinkableDocument =
        focusedRecord &&
        workspace.documents.any(
          (document) => !document.isLinkedTo(targetEntityType, targetEntityId),
        );
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
                        if (hasLinkableDocument)
                          SizedBox(
                            height: AppSpacing.minTapTarget,
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : onLinkExisting,
                              icon: const Icon(Icons.link_rounded),
                              label: Text(
                                YorksV1DocumentStrings
                                    .linkExistingDocument
                                    .primary,
                              ),
                            ),
                          ),
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
                  _DocumentDropzone(
                    language: language,
                    busy: busy,
                    onPick: onCreateDocument,
                    onDropped: onDropDocuments,
                    onDropError: onDropError,
                  ),
                  const SizedBox(height: AppSpacing.lg),
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

class _DocumentDropzone extends StatefulWidget {
  const _DocumentDropzone({
    required this.language,
    required this.busy,
    required this.onPick,
    required this.onDropped,
    required this.onDropError,
  });

  final AppLanguage language;
  final bool busy;
  final VoidCallback onPick;
  final Future<void> Function(List<YorksV1SelectedDocument>) onDropped;
  final VoidCallback onDropError;

  @override
  State<_DocumentDropzone> createState() => _DocumentDropzoneState();
}

class _DocumentDropzoneState extends State<_DocumentDropzone> {
  DropzoneViewController? _controller;
  bool _dragging = false;

  static const _acceptedMimeTypes = <String>[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
  ];

  Future<void> _handleDrop(List<DropzoneFileInterface>? files) async {
    final controller = _controller;
    if (controller == null || files == null || files.isEmpty || widget.busy) {
      return;
    }
    if (mounted) setState(() => _dragging = false);
    final selected = <YorksV1SelectedDocument>[];
    var invalid = false;
    for (final file in files) {
      try {
        selected.add(
          YorksV1SelectedDocument.checked(
            fileName: await controller.getFilename(file),
            bytes: await controller.getFileData(file),
          ),
        );
      } on YorksV1DomainException {
        invalid = true;
      } catch (_) {
        invalid = true;
      }
    }
    if (selected.isNotEmpty) await widget.onDropped(selected);
    if (invalid) widget.onDropError();
  }

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      button: true,
      label: YorksV1DocumentStrings.dropDocuments.primary,
      child: InkWell(
        key: const ValueKey('yorks-v1-document-dropzone'),
        onTap: widget.busy ? null : widget.onPick,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: CustomPaint(
          painter: _DocumentDropBorderPainter(
            color: _dragging
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: .48),
            radius: AppSpacing.radiusMd,
          ),
          child: AnimatedContainer(
            duration: Duration.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: _dragging
                  ? AppColors.blueContainer.withValues(alpha: .72)
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dragging
                            ? YorksV1DocumentStrings.dropDocumentsActive.primary
                            : YorksV1DocumentStrings.dropDocuments.primary,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      _CopyText(
                        copy: YorksV1DocumentStrings.dropDocumentsPrompt,
                        language: widget.language,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 600) ...[
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onPick,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(YorksV1DocumentStrings.addDocument.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!kIsWeb) return content;
    return Stack(
      children: [
        Positioned.fill(
          child: DropzoneView(
            mime: _acceptedMimeTypes,
            operation: DragOperation.copy,
            cursor: CursorType.grab,
            onCreated: (controller) => _controller = controller,
            onHover: () {
              if (mounted && !widget.busy) setState(() => _dragging = true);
            },
            onLeave: () {
              if (mounted) setState(() => _dragging = false);
            },
            onDropInvalid: (_) => widget.onDropError(),
            onDropFiles: (files) => unawaited(_handleDrop(files)),
          ),
        ),
        content,
      ],
    );
  }
}

class _DocumentDropBorderPainter extends CustomPainter {
  const _DocumentDropBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dash).clamp(0, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DocumentDropBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
  Widget build(BuildContext context) => YorksV1ActiveText(
    copy: copy,
    language: language,
    style: style ?? AppTypography.bodyMedium,
    textAlign: center ? TextAlign.center : null,
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
