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
                  child: CustomPaint(
                    key: ValueKey('yorks-file-icon-${appearance.kind.name}'),
                    size: Size.square(size * .66),
                    painter: _YorksFileGlyphPainter(
                      kind: appearance.kind,
                      color: appearance.foreground,
                    ),
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
    required this.kind,
    required this.foreground,
    required this.background,
  });

  final _YorksFileKind kind;
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
        kind: _YorksFileKind.pdf,
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
        kind: _YorksFileKind.spreadsheet,
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
        kind: _YorksFileKind.document,
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
        kind: _YorksFileKind.image,
        foreground: AppColors.tertiary,
        background: AppColors.tertiaryContainer,
      );
    }
    if (const {'dwg', 'dxf', 'rvt', 'ifc'}.contains(extension)) {
      return const _YorksFileAppearance(
        kind: _YorksFileKind.drawing,
        foreground: AppColors.warning,
        background: AppColors.warningContainer,
      );
    }
    if (normalizedMime.contains('zip') ||
        const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(extension)) {
      return const _YorksFileAppearance(
        kind: _YorksFileKind.archive,
        foreground: AppColors.neutralText,
        background: AppColors.neutralContainer,
      );
    }
    return const _YorksFileAppearance(
      kind: _YorksFileKind.file,
      foreground: AppColors.neutralText,
      background: AppColors.neutralContainer,
    );
  }
}

enum _YorksFileKind {
  pdf,
  spreadsheet,
  document,
  image,
  drawing,
  archive,
  file,
}

/// Draws the primary file glyph without relying on the Material icon font.
///
/// Flutter release builds can remove indirectly referenced icon-font glyphs.
/// Keeping this small vector inside the component makes every supported file
/// marker deterministic in web, Android, PDF-preview and test builds.
class _YorksFileGlyphPainter extends CustomPainter {
  const _YorksFileGlyphPainter({required this.kind, required this.color});

  final _YorksFileKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _YorksFileKind.image:
        _paintImage(canvas, size, stroke, fill);
      case _YorksFileKind.drawing:
        _paintDrawing(canvas, size, stroke);
      case _YorksFileKind.archive:
        _paintArchive(canvas, size, stroke, fill);
      case _YorksFileKind.pdf:
        _paintPage(canvas, size, stroke);
        _paintPdfLabel(canvas, size, fill);
      case _YorksFileKind.spreadsheet:
        _paintPage(canvas, size, stroke);
        _paintGrid(canvas, size, stroke);
      case _YorksFileKind.document:
        _paintPage(canvas, size, stroke);
        _paintLines(canvas, size, stroke, count: 3);
      case _YorksFileKind.file:
        _paintPage(canvas, size, stroke);
        _paintLines(canvas, size, stroke, count: 2);
    }
  }

  void _paintPage(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final fold = w * .28;
    final path = Path()
      ..moveTo(w * .2, h * .08)
      ..lineTo(w - fold, h * .08)
      ..lineTo(w * .88, h * .28)
      ..lineTo(w * .88, h * .92)
      ..lineTo(w * .2, h * .92)
      ..close();
    canvas.drawPath(path, stroke);
    canvas.drawLine(
      Offset(w - fold, h * .08),
      Offset(w - fold, h * .28),
      stroke,
    );
    canvas.drawLine(
      Offset(w - fold, h * .28),
      Offset(w * .88, h * .28),
      stroke,
    );
  }

  void _paintPdfLabel(Canvas canvas, Size size, Paint fill) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .5,
        size.width * .84,
        size.height * .3,
      ),
      Radius.circular(size.width * .08),
    );
    canvas.drawRRect(rect, fill);
    final label = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: AppColors.onPrimary,
          fontSize: size.width * .255,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);
    label.paint(
      canvas,
      Offset(
        rect.left + (rect.width - label.width) / 2,
        rect.top + (rect.height - label.height) / 2,
      ),
    );
  }

  void _paintGrid(Canvas canvas, Size size, Paint stroke) {
    final left = size.width * .3;
    final right = size.width * .78;
    final top = size.height * .39;
    final bottom = size.height * .78;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), stroke);
    canvas.drawLine(
      Offset(size.width * .49, top),
      Offset(size.width * .49, bottom),
      stroke,
    );
    canvas.drawLine(
      Offset(left, size.height * .58),
      Offset(right, size.height * .58),
      stroke,
    );
  }

  void _paintLines(
    Canvas canvas,
    Size size,
    Paint stroke, {
    required int count,
  }) {
    for (var index = 0; index < count; index++) {
      final y = size.height * (.46 + index * .15);
      final end = index == count - 1 ? size.width * .64 : size.width * .76;
      canvas.drawLine(Offset(size.width * .32, y), Offset(end, y), stroke);
    }
  }

  void _paintImage(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .16,
        size.width * .84,
        size.height * .7,
      ),
      Radius.circular(size.width * .08),
    );
    canvas.drawRRect(frame, stroke);
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .36),
      size.width * .075,
      fill,
    );
    final mountains = Path()
      ..moveTo(size.width * .18, size.height * .73)
      ..lineTo(size.width * .39, size.height * .49)
      ..lineTo(size.width * .54, size.height * .64)
      ..lineTo(size.width * .66, size.height * .52)
      ..lineTo(size.width * .83, size.height * .73);
    canvas.drawPath(mountains, stroke);
  }

  void _paintDrawing(Canvas canvas, Size size, Paint stroke) {
    final frame = Rect.fromLTWH(
      size.width * .1,
      size.height * .1,
      size.width * .8,
      size.height * .8,
    );
    canvas.drawRect(frame, stroke);
    canvas.drawCircle(frame.center, size.width * .19, stroke);
    canvas.drawLine(frame.topLeft, frame.bottomRight, stroke);
    canvas.drawLine(frame.topRight, frame.bottomLeft, stroke);
  }

  void _paintArchive(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .16,
        size.height * .3,
        size.width * .68,
        size.height * .58,
      ),
      Radius.circular(size.width * .06),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .09,
          size.height * .16,
          size.width * .82,
          size.height * .2,
        ),
        Radius.circular(size.width * .05),
      ),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .4,
          size.height * .45,
          size.width * .2,
          size.height * .08,
        ),
        Radius.circular(size.width * .03),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _YorksFileGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
