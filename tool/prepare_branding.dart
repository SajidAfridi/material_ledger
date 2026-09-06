// Builds the app, launcher and web icon sources from the approved black Yorks
// seal. Keep the complete seal: it is the recognizable company identity shown
// in the office shell, browser tab and installed mobile application.
//
// Run:
//   dart run tool/prepare_branding.dart
//   dart run tool/prepare_branding.dart <replacement-black-seal.png>
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _outputSize = 1024;
final _iconCanvas = img.ColorRgba8(255, 255, 255, 255);

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/prepare_branding.dart [black-seal.png]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = args.isEmpty
      ? 'assets/branding/yorks_emblem_black.png'
      : args.single;
  final decoded = img.decodeImage(File(inputPath).readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode $inputPath');
    exitCode = 1;
    return;
  }
  final source = _removeSquareCanvas(decoded.convert(numChannels: 4));

  final transparentSeal = _render(source, fraction: .96);
  final appIcon = _render(source, fraction: .86, background: _iconCanvas);
  final adaptiveForeground = _render(source, fraction: .92);

  _write('assets/branding/yorks_app_logo.png', transparentSeal);
  _write('assets/logo.png', transparentSeal);
  _write('assets/branding/app_icon.png', appIcon);
  _write('assets/branding/app_icon_foreground.png', adaptiveForeground);
  _write(
    'assets/branding/yorks_emblem_web.png',
    img.copyResize(transparentSeal, width: 256, height: 256),
  );
  _write(
    'assets/branding/yorks_emblem_mobile.png',
    img.copyResize(transparentSeal, width: 84, height: 84),
  );
}

/// Keeps the complete circular seal while removing the source image's pale
/// square canvas. A short anti-aliased edge avoids a visible rectangle in PDF
/// renderers and print drivers that expose nearly-white source pixels.
img.Image _removeSquareCanvas(img.Image source) {
  final result = img.Image.from(source);
  final centerX = (result.width - 1) / 2;
  final centerY = (result.height - 1) / 2;
  final outerRadius =
      (result.width < result.height ? result.width : result.height) * .49;
  final innerRadius = outerRadius - 1.5;

  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final dx = x - centerX;
      final dy = y - centerY;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= innerRadius) continue;
      final pixel = result.getPixel(x, y);
      final coverage = distance >= outerRadius
          ? 0.0
          : (outerRadius - distance) / (outerRadius - innerRadius);
      result.setPixelRgba(
        x,
        y,
        pixel.r,
        pixel.g,
        pixel.b,
        (pixel.a * coverage).round(),
      );
    }
  }
  return result;
}

img.Image _render(
  img.Image source, {
  required double fraction,
  img.Color? background,
}) {
  final canvas = img.Image(
    width: _outputSize,
    height: _outputSize,
    numChannels: 4,
  );
  if (background != null) img.fill(canvas, color: background);

  final target = (_outputSize * fraction).round();
  final sourceRatio = source.width / source.height;
  final targetWidth = sourceRatio >= 1
      ? target
      : (target * sourceRatio).round();
  final targetHeight = sourceRatio >= 1
      ? (target / sourceRatio).round()
      : target;
  final seal = img.copyResize(
    source,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    seal,
    dstX: (_outputSize - targetWidth) ~/ 2,
    dstY: (_outputSize - targetHeight) ~/ 2,
  );
  return canvas;
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $path');
}
