// AAA text contrast measured against the color a widget declares, over the
// background actually painted behind it.

// The stock AAA guideline is marked visible-for-testing, and this library is
// test code: it runs only inside a widget test, where using it is the intent.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sampling.dart';

/// Decides whether a text element is exempt from the contrast floor.
///
/// Called with each element whose text the guideline would measure.
typedef TextContrastExemption = bool Function(Element element);

/// The default [DeclaredColorTextContrastGuidelineAAA], with no exemptions.
const AccessibilityGuideline textContrastGuidelineAAA =
    DeclaredColorTextContrastGuidelineAAA();

/// WCAG AAA text contrast (7:1, or 4.5:1 for large text), measured from the
/// color the text declares over the background painted behind it.
///
/// Flutter's `MinimumTextContrastGuidelineAAA` derives foreground and
/// background from rendered pixels: it histograms the text's box, splits the
/// colors at the box's average lightness, and takes the most frequent color on
/// each side. Those modes equal the declared pair only where glyphs cover their
/// pixels fully. That is true of `flutter_test`'s placeholder box font and
/// false of every real face, whose antialiased strokes leave most glyph pixels
/// partly covered. The dark mode then lands on a blend of the text color into
/// its background, and the ratio comes out well below the declared one. A
/// contrast verdict that depends on which font the test happened to load is not
/// measuring the app, so this measures the specified colors, which is what WCAG
/// defines the ratio over.
///
/// Blending toward the background can only lower a ratio, so the stock
/// guideline fails compliant pairs rather than passing non-compliant ones. It
/// was never unsafe, only wrong in the strict direction.
///
/// The background stays sampled, because sampling is what a rendered-tree
/// check adds over a palette test: it reports what is actually behind the
/// text - an image, a gradient, a container fill nobody paired with this
/// foreground on purpose.
///
/// Which nodes are measured, and which are skipped, follows the stock
/// guideline, so the two stay in step on which text is measured. The size
/// thresholds do not. The stock guideline counts any text at 18 logical pixels
/// or more as large. WCAG's large text is 18pt, or 14pt bold, and at the 96 per
/// inch logical pixel `dart:ui` defines that is 24px, or 18.66px bold; text
/// between the two is normal text, held to 7:1.
///
/// Each styled span of a `Text.rich` is measured in its own style, size and
/// weight, so a sub-AAA span cannot pass under an AAA paragraph default.
///
/// Text whose style resolves no color (a `foreground` paint, or a gap in the
/// `DefaultTextStyle` chain) fails rather than being skipped: the guideline
/// cannot measure it, and passing it silently would drop it from coverage.
class DeclaredColorTextContrastGuidelineAAA extends AccessibilityGuideline {
  /// [isExempt] names text the contrast floor does not apply to. WCAG 1.4.3
  /// exempts text that is part of a logo or brand name; scope the exemption to
  /// the logotype widget, never to a color, so the same color used for
  /// ordinary copy elsewhere still fails.
  const DeclaredColorTextContrastGuidelineAAA({this.isExempt});

  /// Text the contrast floor does not apply to; null exempts nothing.
  final TextContrastExemption? isExempt;

  static const MinimumTextContrastGuidelineAAA _stock =
      MinimumTextContrastGuidelineAAA();

  static const double _largeTextSize = 24.0;
  static const double _largeBoldTextSize = 18.66;

  // CSS's `bold` keyword. WCAG names no weight.
  static const FontWeight _boldWeight = FontWeight.w700;

  // The stock guideline's own slack, kept so a pair sitting exactly on the bar
  // (#595959 on white is 7.00:1) is not failed by float error.
  static const double _tolerance = -0.01;

  @override
  String get description => 'Text contrast should follow WCAG AAA guidelines';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final RenderView renderView in tester.binding.renderViews) {
      final root = renderView.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;
      final PaintedView? painted = await PaintedView.capture(
        tester,
        renderView,
      );
      if (painted == null) {
        throw StateError('Could not read the pixels of $renderView');
      }
      result += _evaluateNode(root, painted, renderView);
    }
    return result;
  }

  Evaluation _evaluateNode(
    SemanticsNode node,
    PaintedView painted,
    RenderView renderView,
  ) {
    var result = const Evaluation.pass();

    // The stock guideline's skip set: a node that is not painted, or that
    // folds into its parent, is measured through whichever node does carry it.
    final isDisabled = node.flagsCollection.isEnabled == ui.Tristate.isFalse;
    if (node.isInvisible ||
        node.isMergedIntoParent ||
        node.flagsCollection.isHidden ||
        isDisabled) {
      return result;
    }

    final children = <SemanticsNode>[];
    node.visitChildren((SemanticsNode child) {
      children.add(child);
      return true;
    });
    for (final child in children) {
      result += _evaluateNode(child, painted, renderView);
    }

    final SemanticsData data = node.getSemanticsData();
    if (_stock.shouldSkipNode(data)) return result;

    final String text = data.label.isEmpty ? data.value : data.label;
    for (final element in find.text(text).hitTestable().evaluate()) {
      // The element, not the node: the node can carry a whole lockup, and real
      // copy in the same node as a logotype must not ride out on its
      // exemption.
      if (isExempt?.call(element) ?? false) continue;
      result += _evaluateElement(node, element, painted, renderView);
    }
    return result;
  }

  Evaluation _evaluateElement(
    SemanticsNode node,
    Element element,
    PaintedView painted,
    RenderView renderView,
  ) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject is! RenderBox) {
      throw StateError('Unexpected renderObject type: $renderObject');
    }

    final Matrix4 globalTransform = renderObject.getTransformTo(null);
    final Rect sampleBounds = MatrixUtils.transformRect(
      globalTransform,
      renderObject.paintBounds.inflate(4.0),
    );

    // `find.text` matches by string, so the same copy rendered twice returns
    // the duplicate elements for either node. The stock guideline pairs node
    // to element by intersecting their boxes; keeping that pairing keeps the
    // two guidelines over the same (node, element) population.
    final rootTransform = Matrix4.identity();
    renderView.applyPaintTransform(renderView.child!, rootTransform);
    rootTransform.multiply(globalTransform);
    final Rect elementBounds = MatrixUtils.transformRect(
      rootTransform,
      renderObject.paintBounds,
    );
    final Rect nodeBounds = semanticsNodeViewRect(node);
    final Rect intersection = nodeBounds.intersect(elementBounds);
    if (intersection.width <= 0 || intersection.height <= 0) {
      return const Evaluation.pass();
    }

    if (_stock.isNodeOffScreen(sampleBounds, renderView.flutterView)) {
      return const Evaluation.pass();
    }

    final List<TextStyle> segments = _paintedSegments(element);
    // Every span's own color is a glyph color, never the background, so a
    // short span among a longer one's glyphs is not measured against them.
    final Set<Color> marks = {
      for (final TextStyle style in segments)
        if (style.color case final Color color) color,
    };

    final Map<Color, int> histogram = painted.colorsWithin(sampleBounds);
    if (histogram.isEmpty) return const Evaluation.pass();

    final TextScaler scaler = _paintedScaler(element, renderObject);
    var result = const Evaluation.pass();
    for (final TextStyle style in segments) {
      result += _evaluateSegment(node, style, histogram, marks, scaler);
    }
    return result;
  }

  Evaluation _evaluateSegment(
    SemanticsNode node,
    TextStyle style,
    Map<Color, int> histogram,
    Set<Color> marks,
    TextScaler scaler,
  ) {
    final Color? declared = style.color;
    if (declared == null) {
      return Evaluation.fail(
        '$node:\n'
        'Text declares no color, so its contrast against the background '
        'cannot be measured. Give the style an explicit color, or a '
        'DefaultTextStyle ancestor that resolves one.',
      );
    }

    final Color? background = backgroundBehind(histogram, marks);
    if (background == null) {
      return Evaluation.fail(
        '$node:\n'
        'Every pixel in the text box is the text color $declared, so there is '
        'no background to measure the text against.',
      );
    }

    final Color foreground = composited(declared, background);
    final double ratio = contrastRatio(foreground, background);
    final double target = _isLargeText(style, scaler)
        ? MinimumTextContrastGuidelineAAA.kAAAMinimumRatioLargeText
        : MinimumTextContrastGuidelineAAA.kAAAMinimumRatioNormalText;
    if (ratio - target >= _tolerance) return const Evaluation.pass();

    return Evaluation.fail(
      '$node:\n'
      'Expected contrast ratio of at least $target but found '
      '${ratio.toStringAsFixed(2)} for a font size of ${style.fontSize}.\n'
      'Declared text color: $foreground\n'
      'Sampled background: $background\n'
      'See also: '
      'https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html',
    );
  }

  // A style with no resolved size is measured as normal text, the stricter bar.
  // The size is the smaller of the declared and the painted one: text the app
  // scales down below the large sizes is not large, and a larger text setting
  // - which WCAG's definition of large text excludes - cannot make it so.
  bool _isLargeText(TextStyle style, TextScaler scaler) {
    final double? declared = style.fontSize;
    if (declared == null) return false;
    final double size = math.min(declared, scaler.scale(declared));
    final bool bold = (style.fontWeight?.value ?? 0) >= _boldWeight.value;
    return size >= _largeTextSize || (bold && size >= _largeBoldTextSize);
  }

  // Every run of text the element paints, with the style it is painted in.
  //
  // One style per element is wrong, and quietly: `find.text` matches a
  // `Text.rich` by the plain text of its spans, so a paragraph whose colors
  // live on child `TextSpan`s would be measured against the ancestor or
  // DefaultTextStyle color instead, and a sub-AAA span under an AAA default
  // would pass. The stock guideline does not have that hole, because it reads
  // the pixels the spans actually painted; reading declared colors is what
  // makes the span tree something this has to walk.
  //
  // Per segment rather than per paragraph also fixes the size half of the same
  // problem, which the stock guideline does have: it takes `fontSize` and
  // weight off the outer widget style, so a 15px span inside a large-text
  // paragraph is held to the large-text bar instead of 7:1.
  List<TextStyle> _paintedSegments(Element element) {
    final Widget widget = element.widget;
    if (widget is EditableText) {
      // What a field paints is its RenderEditable's span tree, as the tree
      // resolves it: a controller's buildTextSpan returns it, and nothing of
      // the widget's style reaches a span that does not carry it. An
      // unresolved color fails, and an unresolved size is normal text.
      final InlineSpan? painted = _descendant<RenderEditable>(
        element.renderObject,
      )?.text;
      if (painted == null) return <TextStyle>[widget.style];
      final segments = <TextStyle>{};
      _collectSpanStyles(painted, const TextStyle(), segments);
      return segments.toList();
    }
    if (widget is! Text) {
      throw StateError('Unexpected widget type: ${widget.runtimeType}');
    }

    final TextStyle? declared = widget.style;
    final TextStyle base = declared == null || declared.inherit
        ? DefaultTextStyle.of(element).style.merge(declared)
        : declared;
    if (widget.data != null) return <TextStyle>[base];

    // Deduped: a paragraph alternating between styles poses one contrast
    // question per style, however many runs it splits into, and one failure
    // per style reads better than one per run.
    final segments = <TextStyle>{};
    _collectSpanStyles(widget.textSpan!, base, segments);
    return segments.toList();
  }

  void _collectSpanStyles(
    InlineSpan span,
    TextStyle inherited,
    Set<TextStyle> into,
  ) {
    // Inside a span tree a child always takes its parent's unspecified
    // fields, whatever its `inherit` says (`TextStyle.inherit`); the flag only
    // governs merging with DefaultTextStyle, which the root handled above.
    final TextStyle? own = span.style;
    final TextStyle resolved = own == null
        ? inherited
        : inherited.merge(own.copyWith(inherit: true));

    if (span is TextSpan) {
      if (span.text?.isNotEmpty ?? false) into.add(resolved);
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        _collectSpanStyles(child, resolved, into);
      }
    }
    // A PlaceholderSpan contributes no text of its own - the widget it hosts is
    // its own element, found and measured by its own `find.text` match.
  }

  // The scaler the text was laid out with, as the renderer that paints this
  // widget's own text holds it - a field's RenderEditable, never a paragraph
  // inside one of its inline widgets.
  TextScaler _paintedScaler(Element element, RenderObject renderObject) =>
      switch (element.widget) {
        EditableText() => _descendant<RenderEditable>(renderObject)?.textScaler,
        _ => _descendant<RenderParagraph>(renderObject)?.textScaler,
      } ??
      TextScaler.noScaling;

  T? _descendant<T extends RenderObject>(RenderObject? root) {
    if (root == null || root is T) return root as T?;
    T? found;
    root.visitChildren((RenderObject child) {
      found ??= _descendant<T>(child);
    });
    return found;
  }
}
