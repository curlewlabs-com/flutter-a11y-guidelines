// WCAG 1.4.11 non-text contrast for the graphics an app names as carrying
// meaning.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sampling.dart';

/// 3:1 contrast (WCAG 1.4.11) for every widget of type [T], measured from the
/// color [colorOf] reads off it over the background painted around it.
///
/// 1.4.11 covers graphics *required* to understand content, which is a
/// narrower set than everything drawn that is not text: a divider, a grouping
/// border, or a fill behind a label that carries its own contrast conveys
/// nothing the copy does not, and holding them to 3:1 fails surfaces that are
/// quiet on purpose. So this measures only the widget types an app names - a
/// status dot, a severity badge - one guideline per type.
///
/// The model is a solid mark of one declared color: a ring of logical pixels
/// around the widget's box is sampled with it, the declared color is set
/// aside, and the most frequent remaining color is the background. A gradient
/// or multi-color graphic does not fit the model.
///
/// The verdict comes from the declared color, never from a pixel search for
/// it. A graphic mid-animation - scaling or fading in - may have no pixel
/// anywhere in its declared color; a guideline that skipped what it could not
/// find would pass it at every frame of its entrance.
class GraphicContrastGuideline<T extends Widget>
    extends AccessibilityGuideline {
  /// Measures every [T] in the tree.
  const GraphicContrastGuideline({required this.colorOf, this.hint});

  /// The color the widget declares for its mark.
  final Color Function(T widget) colorOf;

  /// Appended to each failure: where the graphic's colors are defined, or what
  /// the graphic conveys.
  final String? hint;

  // Wide enough for the background to outnumber a mark's antialiased edge,
  // which is a pixel or two at any size, so no graphic needs another width.
  static const double _ring = 6.0;

  // WCAG 1.4.11's floor for a non-text graphic that carries meaning.
  static const double _target = 3.0;

  // Kept so a color sitting exactly on the bar is not failed by float error.
  static const double _tolerance = -0.01;

  @override
  String get description => '$T graphics should meet WCAG 1.4.11 (3:1)';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final RenderView renderView in tester.binding.renderViews) {
      final PaintedView? painted = await PaintedView.capture(
        tester,
        renderView,
      );
      if (painted == null) continue;

      for (final Element element in find.byType(T).evaluate()) {
        result += _evaluateGraphic(element, painted);
      }
    }
    return result;
  }

  Evaluation _evaluateGraphic(Element element, PaintedView painted) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject is! RenderBox) return const Evaluation.pass();

    final Color declared = colorOf(element.widget as T);

    final Rect bounds = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      renderObject.paintBounds.inflate(_ring),
    );
    final Map<Color, int> histogram = painted.colorsWithin(bounds);
    if (histogram.isEmpty) return const Evaluation.pass();

    final Color? background = backgroundBehind(histogram, {declared});
    if (background == null) {
      return Evaluation.fail(
        '$T($declared):\n'
        'Every pixel around the graphic is its own color, so there is no '
        'background to measure it against.',
      );
    }

    final Color foreground = composited(declared, background);
    final double ratio = contrastRatio(foreground, background);
    if (ratio - _target >= _tolerance) return const Evaluation.pass();

    return Evaluation.fail(
      '$T($declared):\n'
      'A graphic that carries meaning needs $_target:1 against what it is '
      'drawn on (WCAG 1.4.11). Found ${ratio.toStringAsFixed(2)}.\n'
      'Graphic color: $foreground\n'
      'Sampled background: $background'
      '${hint == null ? '' : '\n$hint'}',
    );
  }
}
