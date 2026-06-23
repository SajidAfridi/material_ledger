// Generates the launcher-icon source images from the Yorks emblem:
//   assets/branding/app_icon.png            (blue tile + white Y — iOS/legacy)
//   assets/branding/app_icon_foreground.png (blue tile + white Y — adaptive fg)
//
// The full emblem's ring text ("YORKS AIR CONDITIONING & REF · SINCE 1984") is
// unreadable at icon sizes, so we lift just the central Y monogram: crop the
// inner blue disc as a CIRCLE (radius kept inside the disc so the surrounding
// white text-ring is excluded) and composite it onto a brand-blue canvas. The
// disc blue is sampled from the artwork so it blends seamlessly with the canvas.
//
// Run:  dart run tool/gen_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(
    File('assets/branding/source_emblem.png').readAsBytesSync(),
  );
  if (src == null) {
    stderr.writeln('Could not read assets/branding/source_emblem.png');
    exit(1);
  }
  final w = src.width, h = src.height;

  // ─── Brand blue = the dominant strongly-blue ink (histogram mode) ────────
  // Averaging a patch blends with the white figures; the ink is one large solid
  // area, so its quantised colour is simply the most common deep-blue pixel.
  final counts = <int, int>{};
  for (var y = 0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      if (b > 110 && b - r > 60 && b - g > 40) {
        final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3); // 5-bit
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }
  final domKey =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final blue = img.ColorRgb8(
    ((domKey >> 10) & 31) << 3,
    ((domKey >> 5) & 31) << 3,
    (domKey & 31) << 3,
  );
  String hex(int v) => v.toRadixString(16).padLeft(2, '0');
  stdout.writeln(
    'Brand blue: #${hex(blue.r.toInt())}${hex(blue.g.toInt())}'
    '${hex(blue.b.toInt())}',
  );

  // ─── Circular crop of the inner disc (white Y on blue) ──────────────────
  // Radius kept well inside the disc so no white text-ring is captured (the Y
  // monogram itself only spans ~0.18w). Convert to RGBA first so the area
  // outside the circle becomes transparent (not opaque white).
  final rgba = src.convert(numChannels: 4);
  final radius = (w * 0.225).round();
  final disc = img.copyCropCircle(
    rgba,
    radius: radius,
    centerX: w ~/ 2,
    centerY: h ~/ 2,
    antialias: false, // hard edge: disc blue meets identical canvas blue = no seam
  );

  img.Image render(int size, double discFrac) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: blue);
    final target = (size * discFrac).round();
    final scaled = img.copyResize(
      disc,
      width: target,
      height: target,
      interpolation: img.Interpolation.cubic,
    );
    final offset = (size - target) ~/ 2;
    img.compositeImage(canvas, scaled, dstX: offset, dstY: offset);
    return canvas;
  }

  // iOS + legacy Android — Y fills most of the tile (small margin for the
  // rounded-corner mask).
  File('assets/branding/app_icon.png')
      .writeAsBytesSync(img.encodePng(render(1024, 0.82)));

  // Android adaptive foreground — full-bleed blue (matches the adaptive
  // background colour, so the launcher's 16% inset shows no two-tone seam); the
  // inset itself lands the Y in the safe zone.
  File('assets/branding/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(render(1024, 0.97)));

  stdout.writeln('Wrote app_icon.png + app_icon_foreground.png');
}
