// Text contrast while a control is hovered, pressed, or focused.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sampling.dart';
import 'text_contrast.dart';

/// The default [StateContrastGuidelineAAA], re-running
/// [textContrastGuidelineAAA] in each state.
const AccessibilityGuideline stateContrastGuidelineAAA =
    StateContrastGuidelineAAA();

/// Re-measures text contrast with each enabled control hovered, pressed, and
/// focused.
///
/// A resting-page guideline never sees a control's state colors: Material
/// resolves a button's label, fill, and overlay per `WidgetState`, so a state
/// that darkens the fill or tints the surface under the label is never painted
/// while the page is at rest. `TextButton.styleFrom(foregroundColor: x)` is the
/// common case: it synthesizes an `x`-tinted hover, focus and press overlay
/// that a theme's own overlay does not describe.
///
/// So this drives each state for real and runs [textContrast] on what was
/// painted, rather than resolving style properties, because per-widget
/// overrides and custom ink are exactly what a resolved theme does not
/// describe.
///
/// It reaches every enabled control that takes a tap or focus, on screen where
/// the page first paints and again at each half-viewport step through every
/// vertical scrollable the pointer can reach, from each one's start to its end,
/// nested ones included where they appear. The steps reach a control below the
/// fold, which a lazily built list has not mounted and nothing short of
/// scrolling, Tab traversal included, would find. Half a viewport, so any
/// control up to that height is wholly in view at some step, where its label
/// can be measured.
///
/// The whole tree is measured in each state, not just the driven control: a
/// state can paint text elsewhere - a tooltip on hover or long press - and that
/// text answers to the same floor.
///
/// A press is held and cancelled, never lifted, so no tap completes: the page
/// under test does not navigate, open a dialog, or call its services. A
/// control with a long-press action is released before the long-press
/// deadline, so its pressed state is measured part-way into its press
/// animation. Disabled controls are not driven, since WCAG 1.4.3 exempts
/// inactive components.
///
/// A scrollable that is still growing after a fixed number of viewport steps,
/// such as a list with no item count, fails with a message saying the walk
/// could not finish, rather than walking forever.
///
/// This drives the page - pointers, focus, and scroll position - so run it
/// after any guideline that measures the page at rest.
class StateContrastGuidelineAAA extends AccessibilityGuideline {
  /// Drives every enabled control and runs [textContrast] in each state.
  const StateContrastGuidelineAAA({
    this.textContrast = textContrastGuidelineAAA,
  });

  /// The text guideline run in each state. Pass the same instance the resting
  /// page is measured with, so its exemptions hold in every state too.
  final AccessibilityGuideline textContrast;

  // A cap on each settle rather than `pumpAndSettle`, which never returns on a
  // page with a running progress indicator. Double the slowest state animation
  // measured on Material buttons, a held press's ink spread at about a second,
  // so only a page that animates forever reaches it.
  static const Duration _settleCap = Duration(seconds: 2);
  static const Duration _frame = Duration(milliseconds: 100);

  // A held press on a control with a long-press action ends a frame before
  // the long-press deadline, which also bounds its settle.
  static final Duration _longPressableHold =
      kLongPressTimeout - kPressTimeout - _frame;

  // Far more half-viewports than a finite page holds; a walk that reaches it
  // is following a list that grows as it scrolls.
  static const int _maxStepsPerScrollable = 200;

  @override
  String get description =>
      'Text contrast should follow WCAG AAA guidelines while a control is '
      'hovered, pressed, or focused';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    // Focus highlights paint only in the traditional `FocusHighlightMode`, and
    // the automatic strategy leaves it whenever a touch arrives - which every
    // press below is. Pinned for the walk so a focus measured after a press
    // still shows its highlight.
    final FocusManager focus = FocusManager.instance;
    final FocusHighlightStrategy strategy = focus.highlightStrategy;
    focus.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    try {
      return await _walk(tester);
    } finally {
      focus.highlightStrategy = strategy;
    }
  }

  Future<Evaluation> _walk(WidgetTester tester) async {
    final driven = <String>{};
    final walked = <(ScrollableState, Rect)>{};
    var result = await _measureOnScreen(tester, driven);
    result += await _walkNewScrollables(tester, driven, walked);
    return result;
  }

  // Walks every vertical scrollable the pointer can reach now that has not
  // been walked with its current part in view, each while it exists. Called
  // again at every position a walk reaches, so a scrollable that only appears
  // further down, or inside a lazy list that will dispose it once scrolled
  // past, is walked where it is - and one an ancestor clipped is walked again
  // once more of it is in view, since its end could not be reached before.
  Future<Evaluation> _walkNewScrollables(
    WidgetTester tester,
    Set<String> driven,
    Set<(ScrollableState, Rect)> walked,
  ) async {
    var result = const Evaluation.pass();
    while (true) {
      final (ScrollableState, Rect)? next = tester
          .stateList<ScrollableState>(find.byType(Scrollable).hitTestable())
          .where((s) => s.mounted && s.position.axis == Axis.vertical)
          .map((s) => (s, _visiblePart(tester, s)))
          .where((key) => !walked.contains(key))
          .firstOrNull;
      if (next == null) return result;
      walked.add(next);
      result += await _walkScrollable(tester, next.$1, driven, walked);
    }
  }

  // The part of [scrollable]'s box in view, in its own coordinates rounded to
  // whole logical pixels: its box clipped by the test's view and by every
  // viewport above it.
  Rect _visiblePart(WidgetTester tester, ScrollableState scrollable) {
    final RenderObject? box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Rect.zero;
    Rect global(RenderBox of) => MatrixUtils.transformRect(
      of.getTransformTo(null),
      Offset.zero & of.size,
    );
    final Rect own = global(box);
    var visible = own.intersect(
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio),
    );
    for (RenderObject? up = box.parent; up != null; up = up.parent) {
      if (up case final RenderBox viewport
          when up is RenderAbstractViewport && viewport.hasSize) {
        visible = visible.intersect(global(viewport));
      }
    }
    if (visible.isEmpty) return Rect.zero;
    final Rect local = visible.shift(-own.topLeft);
    return Rect.fromLTRB(
      local.left.roundToDouble(),
      local.top.roundToDouble(),
      local.right.roundToDouble(),
      local.bottom.roundToDouble(),
    );
  }

  // Steps [scrollable] from its start to its end half a viewport at a time,
  // measuring each position, then puts it back where the page had it.
  Future<Evaluation> _walkScrollable(
    WidgetTester tester,
    ScrollableState scrollable,
    Set<String> driven,
    Set<(ScrollableState, Rect)> walked,
  ) async {
    var result = const Evaluation.pass();
    final ScrollPosition position = scrollable.position;
    if (!position.hasContentDimensions) return result;
    final double start = position.pixels;
    // From the start, so controls above where the page opened are reached.
    var offset = position.minScrollExtent;
    if (offset != start) {
      position.jumpTo(offset);
      await _settle(tester);
      result += await _measureOnScreen(tester, driven);
    }
    result += await _walkNewScrollables(tester, driven, walked);
    var steps = 0;
    while (scrollable.mounted && offset < position.maxScrollExtent) {
      if (steps++ == _maxStepsPerScrollable) {
        result += Evaluation.fail(
          'Stopped walking $scrollable after $_maxStepsPerScrollable '
          'steps with more content still below: controls past this '
          'point were not driven. A list that builds without an item count '
          'cannot be walked to its end.',
        );
        break;
      }
      final double previous = offset;
      offset = (offset + position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      // A zero-height viewport never advances.
      if (offset <= previous) break;
      position.jumpTo(offset);
      await _settle(tester);
      result += await _measureOnScreen(tester, driven);
      result += await _walkNewScrollables(tester, driven, walked);
    }
    // A lazily built scrollable can be disposed by its parent's walk.
    if (scrollable.mounted) {
      position.jumpTo(start);
      await _settle(tester);
    }
    return result;
  }

  // [driven] holds each control already measured, by semantics id and by
  // which part of it is in view, so a control still on screen after a scroll
  // step is not driven twice. Semantics clips a node's rect to what is in
  // view and re-bases it, so the part in view is told by the rect's size and
  // by which edges of the view cut it: a control is driven again whenever a
  // step shows another part of it - and its text. A control
  // that scrolled out, was rebuilt under a new id, and comes back on screen is
  // driven again, which costs time and misses nothing.
  Future<Evaluation> _measureOnScreen(
    WidgetTester tester,
    Set<String> driven,
  ) async {
    var result = const Evaluation.pass();
    for (final _Target target in _onScreenTargets(tester)) {
      if (!driven.add(target.key)) continue;
      result += await _measureStates(tester, target);
    }
    return result;
  }

  Future<Evaluation> _measureStates(WidgetTester tester, _Target target) async {
    var result = const Evaluation.pass();

    if (target.tappable) {
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: target.center);
      await _settle(tester);
      result += await _measure(tester, 'hovering ${target.label}');
      await mouse.removePointer();
      await _settle(tester);

      final TestGesture finger = await tester.startGesture(target.center);
      // `onTapDown` waits out `kPressTimeout` unless the tap wins the gesture
      // arena first, which inside a scrollable it does not. `_frame` happens
      // to be the same interval, so this states what the press waits on
      // rather than leaning on that coincidence.
      await tester.pump(kPressTimeout);
      await _settle(
        tester,
        cap: target.longPressable ? _longPressableHold : _settleCap,
      );
      result += await _measure(tester, 'pressing ${target.label}');
      // Cancelled, never lifted: a lift completes the tap, and the page would
      // navigate, open a dialog, or call its service under the guideline.
      await finger.cancel();
      await _settle(tester);
    }

    if (target.focusable) {
      target.owner.performAction(target.id, SemanticsAction.focus);
      await _settle(tester);
      result += await _measure(tester, 'focusing ${target.label}');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
    }

    return result;
  }

  Future<void> _settle(WidgetTester tester, {Duration cap = _settleCap}) async {
    var elapsed = Duration.zero;
    do {
      await tester.pump(_frame);
      elapsed += _frame;
    } while (tester.binding.hasScheduledFrame && elapsed < cap);
  }

  Future<Evaluation> _measure(WidgetTester tester, String state) async {
    final Evaluation evaluation = await textContrast.evaluate(tester);
    if (evaluation.passed) return evaluation;
    return Evaluation.fail('While $state:\n${evaluation.reason}');
  }

  List<_Target> _onScreenTargets(WidgetTester tester) {
    final targets = <_Target>[];
    for (final RenderView renderView in tester.binding.renderViews) {
      final SemanticsOwner? owner = renderView.owner?.semanticsOwner;
      final SemanticsNode? root = owner?.rootSemanticsNode;
      if (owner == null || root == null) continue;
      final double ratio = renderView.flutterView.devicePixelRatio;
      final Rect view = Offset.zero & renderView.size;
      _collectTargets(root, owner, ratio, view, targets);
    }
    return targets;
  }

  void _collectTargets(
    SemanticsNode node,
    SemanticsOwner owner,
    double devicePixelRatio,
    Rect view,
    List<_Target> into,
  ) {
    if (node.isInvisible ||
        node.isMergedIntoParent ||
        node.flagsCollection.isHidden) {
      return;
    }
    final SemanticsData data = node.getSemanticsData();
    final isDisabled = node.flagsCollection.isEnabled == ui.Tristate.isFalse;
    final bool tappable = data.hasAction(SemanticsAction.tap);
    final bool focusable = data.hasAction(SemanticsAction.focus);
    if (!isDisabled && (tappable || focusable)) {
      final Rect physical = semanticsNodeViewRect(node);
      final Rect logical = Rect.fromLTRB(
        physical.left / devicePixelRatio,
        physical.top / devicePixelRatio,
        physical.right / devicePixelRatio,
        physical.bottom / devicePixelRatio,
      );
      final Offset center = logical.center;
      // A control outside the view takes no pointer, so driving it would only
      // re-measure the resting page; a later scroll step reaches it instead.
      if (view.contains(center)) {
        final String label = data.label.isNotEmpty
            ? data.label
            : (data.tooltip.isNotEmpty ? data.tooltip : 'node ${node.id}');
        into.add(
          _Target(
            id: node.id,
            owner: owner,
            center: center,
            label: '"$label"',
            tappable: tappable,
            key:
                '${node.id}:${logical.width.round()}x'
                '${logical.height.round()}:'
                '${logical.top <= view.top + 0.5 ? 'top' : ''}'
                '${logical.bottom >= view.bottom - 0.5 ? 'bottom' : ''}',
            longPressable: data.hasAction(SemanticsAction.longPress),
            focusable: focusable,
          ),
        );
      }
    }
    node.visitChildren((SemanticsNode child) {
      _collectTargets(child, owner, devicePixelRatio, view, into);
      return true;
    });
  }
}

class _Target {
  const _Target({
    required this.id,
    required this.owner,
    required this.center,
    required this.label,
    required this.tappable,
    required this.key,
    required this.longPressable,
    required this.focusable,
  });

  final int id;
  final SemanticsOwner owner;
  final Offset center;
  final String label;
  final bool tappable;
  final String key;
  final bool longPressable;
  final bool focusable;
}
