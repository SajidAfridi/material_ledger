import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// A compact, recognizable file marker shared by Yorks document surfaces.
///
/// The filename remains the accessible source of truth. Colour and shape are
/// supporting cues only, so unfamiliar and unsupported formats stay honest.
class YorksFileTypeIcon extends StatelessWidget {
  const YorksFileTypeIcon({
    super.key,
    required this.fileName,
    this.mimeType,
    this.size = 28,
    this.badgeIcon,
    this.enabled = true,
  });

  final String fileName;
  final String? mimeType;
  final double size;
  final IconData? badgeIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final appearance = _YorksFileAppearance.resolve(fileName, mimeType);
    return ExcludeSemantics(
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: appearance.background,
                    borderRadius: BorderRadius.circular(size * .24),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    appearance.icon,
                    size: size * .62,
                    color: appearance.foreground,
                  ),
                ),
              ),
              if (badgeIcon != null)
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: Container(
                    width: size * .46,
                    height: size * .46,
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceContainerLowest,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      badgeIcon,
                      size: size * .28,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YorksFileAppearance {
  const _YorksFileAppearance({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  static _YorksFileAppearance resolve(String fileName, String? mimeType) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    final normalizedName = fileName.trim().toLowerCase();
    final extension = normalizedName.contains('.')
        ? normalizedName.split('.').last
        : '';

    if (normalizedMime == 'application/pdf' || extension == 'pdf') {
      return const _YorksFileAppearance(
        icon: Icons.picture_as_pdf_rounded,
        foreground: AppColors.error,
        background: AppColors.errorContainer,
      );
    }
    if (normalizedMime.contains('spreadsheet') ||
        normalizedMime.contains('excel') ||
        extension == 'xlsx' ||
        extension == 'xls' ||
        extension == 'csv') {
      return const _YorksFileAppearance(
        icon: Icons.table_view_rounded,
        foreground: AppColors.success,
        background: AppColors.successContainer,
      );
    }
    if (normalizedMime.contains('word') ||
        extension == 'doc' ||
        extension == 'docx' ||
        extension == 'odt' ||
        extension == 'txt') {
      return const _YorksFileAppearance(
        icon: Icons.article_rounded,
        foreground: AppColors.blue,
        background: AppColors.blueContainer,
      );
    }
    if (normalizedMime.startsWith('image/') ||
        const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'heic',
        }.contains(extension)) {
      return const _YorksFileAppearance(
        icon: Icons.image_rounded,
        foreground: AppColors.tertiary,
        background: AppColors.tertiaryContainer,
      );
    }
    if (const {'dwg', 'dxf', 'rvt', 'ifc'}.contains(extension)) {
      return const _YorksFileAppearance(
        icon: Icons.architecture_rounded,
        foreground: AppColors.warning,
        background: AppColors.warningContainer,
      );
    }
    if (normalizedMime.contains('zip') ||
        const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(extension)) {
      return const _YorksFileAppearance(
        icon: Icons.folder_zip_rounded,
        foreground: AppColors.neutralText,
        background: AppColors.neutralContainer,
      );
    }
    return const _YorksFileAppearance(
      icon: Icons.insert_drive_file_rounded,
      foreground: AppColors.neutralText,
      background: AppColors.neutralContainer,
    );
  }
}
