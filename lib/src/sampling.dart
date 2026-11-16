// The measurement the contrast guidelines share: capture what a render view
// painted, histogram the pixels in a box, and find the fill behind a mark of a
// declared color. A graphic and a glyph are the same measurement problem: a
// declared color, the fill it lands on, and the ratio between them.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// What one render view painted, at one pixel per logical pixel.
class PaintedView {
  /// Wraps captured pixels.
  const PaintedView(this.pixels, this.width, this.height);

  /// RGBA, four bytes per pixel, rows first.
  final ByteData pixels;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Captures [renderView]'s layer tree.
  static Future<PaintedView?> capture(
    WidgetTester tester,
    RenderView renderView,
  ) async {
    final layer = renderView.debugLayer! as OffsetLayer;
    return tester.binding.runAsync<PaintedView?>(() async {
      // Must be the inverse of the device pixel ratio, or the sampled
      // coordinates do not line up with the logical rects the guidelines
      // compute from render objects.
      final ui.Image image = await layer.toImage(
        renderView.paintBounds,
        pixelRatio: 1 / renderView.flutterView.devicePixelRatio,
      );
      final ByteData? data = await image.toByteData();
      final int width = image.width;
      final int height = image.height;
      image.dispose();
      return data == null ? null : PaintedView(data, width, height);
    });
  }

  /// Color histogram of the pixels inside [bounds].
  Map<Color, int> colorsWithin(Rect bounds) {
    final Rect clipped = bounds.intersect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    final counts = <int, int>{};
    for (var x = clipped.left.floor(); x < clipped.right.ceil(); x++) {
      for (var y = clipped.top.floor(); y < clipped.bottom.ceil(); y++) {
        final int rgba = pixels.getUint32((y * width + x) * 4);
        counts.update(rgba, (int count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts.map<Color, int>((int rgba, int count) {
      final int argb = (rgba << 24) | (rgba >> 8) & 0xFFFFFFFF;
      return MapEntry<Color, int>(Color(argb), count);
    });
  }
}

/// The most frequent color in [histogram] that is not [declared] itself.
///
/// Excluding the declared color removes the fully covered core of the mark - a
/// glyph's, or a dot's. Every remaining edge pixel is a partial-coverage blend
/// spread thin across many values, so what is left with a real count is the
/// fill behind the mark. Returns null when the box holds nothing but the
/// declared color.
Color? backgroundBehind(Map<Color, int> histogram, Color declared) {
  Color? best;
  var bestCount = 0;
  for (final MapEntry<Color, int> entry in histogram.entries) {
    if (entry.key == declared) continue;
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

/// [declared] as it reaches the eye over [background]: a translucent color is
/// seen composited over what is behind it, and WCAG measures what reaches the
/// eye.
Color composited(Color declared, Color background) =>
    declared.a < 1.0 ? Color.alphaBlend(declared, background) : declared;

/// The WCAG contrast ratio between two colors.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [node]'s box in the coordinate space of the render view it belongs to.
///
/// That space is physical pixels, not logical: the root semantics node's
/// transform carries the device pixel ratio, the same scale
/// `RenderView.applyPaintTransform` applies, which is what lets the text
/// guideline intersect this with an element's painted bounds. A caller that
/// needs a pointer location divides by the view's device pixel ratio.
Rect semanticsNodeViewRect(SemanticsNode node) {
  Rect bounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      bounds = MatrixUtils.transformRect(transform, bounds);
    }
    current = current.parent;
  }
  return bounds;
}
