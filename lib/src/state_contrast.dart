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
/// the page first paints and again at each viewport-sized step through every
/// vertical scrollable the pointer can reach. The steps reach a control below
/// the fold, which a lazily built list has not mounted and nothing short of
/// scrolling, Tab traversal included, would find.
///
/// The whole tree is measured in each state, not just the driven control: a
/// state can paint text elsewhere - a tooltip on hover or long press - and that
/// text answers to the same floor.
///
/// A press is held and cancelled, never lifted, so no tap completes: the page
/// under test does not navigate, open a dialog, or call its services. Disabled
/// controls are not driven, since WCAG 1.4.3 exempts inactive components.
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
    var result = const Evaluation.pass();
    final driven = <int>{};
    result += await _measureOnScreen(tester, driven);

    final List<ScrollableState> scrollables = tester
        .stateList<ScrollableState>(find.byType(Scrollable).hitTestable())
        .where((s) => s.position.axis == Axis.vertical)
        .toList();
    for (final ScrollableState scrollable in scrollables) {
      final ScrollPosition position = scrollable.position;
      if (!position.hasContentDimensions) continue;
      final double start = position.pixels;
      var offset = start;
      while (offset < position.maxScrollExtent) {
        offset = (offset + position.viewportDimension).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        position.jumpTo(offset);
        await _settle(tester);
        result += await _measureOnScreen(tester, driven);
      }
      position.jumpTo(start);
      await _settle(tester);
    }
    return result;
  }

  // [driven] holds the semantics ids already measured, so a control still on
  // screen after a scroll step is not driven twice. A control that scrolled
  // out, was rebuilt under a new id, and comes back on screen is driven again,
  // which costs time and misses nothing.
  Future<Evaluation> _measureOnScreen(
    WidgetTester tester,
    Set<int> driven,
  ) async {
    var result = const Evaluation.pass();
    for (final _Target target in _onScreenTargets(tester)) {
      if (!driven.add(target.id)) continue;
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
      await _settle(tester);
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

  Future<void> _settle(WidgetTester tester) async {
    var elapsed = Duration.zero;
    do {
      await tester.pump(_frame);
      elapsed += _frame;
    } while (tester.binding.hasScheduledFrame && elapsed < _settleCap);
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
      final Offset center = physical.center / devicePixelRatio;
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
    required this.focusable,
  });

  final int id;
  final SemanticsOwner owner;
  final Offset center;
  final String label;
  final bool tappable;
  final bool focusable;
}
