// Builds the app, launcher and web icon sources from the approved golden Yorks
// seal. Keep the complete seal: it is the recognizable company identity shown
// in the office shell, browser tab and installed mobile application.
//
// Run:
//   dart run tool/prepare_branding.dart
//   dart run tool/prepare_branding.dart <replacement-golden-seal.png>
import 'dart:io';

import 'package:image/image.dart' as img;

const _outputSize = 1024;
final _warmCanvas = img.ColorRgba8(247, 243, 232, 255);

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/prepare_branding.dart [golden-seal.png]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = args.isEmpty
      ? 'assets/branding/source_emblem.png'
      : args.single;
  final decoded = img.decodeImage(File(inputPath).readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode $inputPath');
    exitCode = 1;
    return;
  }
  final source = decoded.convert(numChannels: 4);

  final transparentSeal = _render(source, fraction: .96);
  final appIcon = _render(source, fraction: .86, background: _warmCanvas);
  final adaptiveForeground = _render(source, fraction: .92);

  _write('assets/branding/yorks_app_logo.png', transparentSeal);
  _write('assets/logo.png', transparentSeal);
  _write('assets/branding/app_icon.png', appIcon);
  _write('assets/branding/app_icon_foreground.png', adaptiveForeground);
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
