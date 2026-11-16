// Semantics-tree guidelines for labels, headings, localization, and route
// titles.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rejects a tappable node whose only label or tooltip is a generic
/// widget-type token such as "Button" or "Switch".
///
/// `labeledTapTargetGuideline` only checks that a tappable node has some
/// non-empty label or tooltip, so a literal "Button" clears it. A screen-reader
/// user hearing "Button, button" has no idea what the button does. A node
/// passes when it carries at least one descriptor that is not generic. The
/// match is case-insensitive full-string equality, so "Switch accounts" is a
/// real label and passes.
const AccessibilityGuideline explicitSemanticsLabelGuideline =
    _ExplicitSemanticsLabelGuideline();

/// WCAG 2.4.6 (Headings and Labels) for headings: a node flagged as a header
/// must have a label that is neither empty nor a bare widget-type token like
/// "Tab".
///
/// A heading announced as an empty string, or as "Tab", tells a screen-reader
/// user navigating by heading nothing about the section they landed on.
const AccessibilityGuideline headingLabelQualityGuideline =
    _HeadingLabelQualityGuideline();

/// The pumped tree resolves a non-empty content locale through a
/// `Localizations` ancestor.
///
/// This is a supporting invariant for WCAG 3.1.1 (Language of Page), not a
/// 3.1.1 conformance check: 3.1.1 requires the platform accessibility layer to
/// expose the content language to assistive technology, and that happens in
/// the engine, below what a widget test can assert. What a widget test can
/// assert is the floor under it: a screen pumped with no localization scope at
/// all fails.
const AccessibilityGuideline localizationScopeGuideline =
    _LocalizationScopeGuideline();

/// WCAG 2.4.2 (Page Titled): the pumped tree exposes a node flagged
/// `namesRoute` - the title assistive technology announces on a route change -
/// whose label is not a bare control-type token.
///
/// What supplies that node depends on the target platform. On Android,
/// Fuchsia, Linux and Windows (`flutter_test` defaults to Android), an `AppBar`
/// title is flagged `namesRoute`, and `AlertDialog` and `SimpleDialog` carry a
/// built-in announcement ("Alert", "Dialog") that this guideline accepts, so a
/// dialog need not invent a title of its own. On iOS and macOS Flutter flags
/// neither, so a test run under an Apple platform override fails unless the
/// screen or dialog wraps its title in `Semantics(namesRoute: true)` itself.
///
/// A screen with neither fails until it supplies one: an `AppBar` title where
/// the platform flags it, or an explicit `Semantics(header: true, namesRoute:
/// true)` around its headline.
const AccessibilityGuideline pageTitledGuideline = _PageTitledGuideline();

// Generic widget-type tokens that read as useless when a screen reader
// announces them. Compared case-insensitively. The set is deliberately
// small: literal Flutter widget class names that occasionally end up
// pasted into `Semantics(label: ...)` instead of a real description.
// Adding more tokens here is cheap, but each addition risks a false
// positive on a real-world label (e.g. "Switch accounts" would be a
// false positive if "Switch" were matched as a substring) - so the
// match is full-string equality, not substring containment.
const Set<String> _genericLabelTokens = <String>{
  'button',
  'iconbutton',
  'switch',
  'toggle',
  'checkbox',
  'radio',
  'tab',
};

class _ExplicitSemanticsLabelGuideline extends AccessibilityGuideline {
  const _ExplicitSemanticsLabelGuideline();

  @override
  String get description =>
      'Tappable widgets must have a meaningful semantic label '
      '(not a bare widget-type token like "Button" or "Switch")';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final RenderView view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;
      result += _traverse(root);
    }
    return result;
  }

  Evaluation _traverse(SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((SemanticsNode child) {
      result += _traverse(child);
      return true;
    });
    // Mirror LabeledTapTargetGuideline's skip set so this matcher only
    // evaluates the same population of nodes - no double-counting of
    // merged-up children, no false positives on hidden / text-field
    // nodes that already have framework-supplied semantics.
    if (node.isMergedIntoParent ||
        node.isInvisible ||
        node.flagsCollection.isHidden ||
        node.flagsCollection.isTextField) {
      return result;
    }
    final SemanticsData data = node.getSemanticsData();
    if (!data.hasAction(ui.SemanticsAction.tap) &&
        !data.hasAction(ui.SemanticsAction.longPress)) {
      return result;
    }
    final String label = data.label.trim();
    final String tooltip = data.tooltip.trim();
    final bool labelIsGeneric =
        label.isNotEmpty && _genericLabelTokens.contains(label.toLowerCase());
    final bool tooltipIsGeneric =
        tooltip.isNotEmpty &&
        _genericLabelTokens.contains(tooltip.toLowerCase());
    // A node passes when it has at least one non-generic descriptor -
    // either a meaningful label OR a meaningful tooltip. It only fails
    // when every descriptor it carries is in the generic set, which is
    // the screen-reader user's actual experience: "Button, button" with
    // no other context.
    final bool labelOk = label.isNotEmpty && !labelIsGeneric;
    final bool tooltipOk = tooltip.isNotEmpty && !tooltipIsGeneric;
    if (!labelOk && !tooltipOk && (labelIsGeneric || tooltipIsGeneric)) {
      result += Evaluation.fail(
        '$node: tappable node has only generic label/tooltip '
        '(label="$label", tooltip="$tooltip"). Use a description that '
        'tells the screen-reader user what the action does.',
      );
    }
    return result;
  }
}

class _HeadingLabelQualityGuideline extends AccessibilityGuideline {
  const _HeadingLabelQualityGuideline();

  @override
  String get description =>
      'Heading nodes must carry a meaningful semantic label '
      '(not empty, and not a bare widget-type token like "Tab")';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final RenderView view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;
      result += _traverse(root);
    }
    return result;
  }

  Evaluation _traverse(SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((SemanticsNode child) {
      result += _traverse(child);
      return true;
    });
    // Same skip set as the label matcher: a heading whose semantics merged
    // into a parent (e.g. an AppBar title folded into the toolbar node) is
    // evaluated on the parent, so skipping it here avoids double-counting
    // and false positives on hidden / framework-owned text-field nodes.
    if (node.isMergedIntoParent ||
        node.isInvisible ||
        node.flagsCollection.isHidden ||
        node.flagsCollection.isTextField) {
      return result;
    }
    final SemanticsData data = node.getSemanticsData();
    if (!data.flagsCollection.isHeader) {
      return result;
    }
    final String label = data.label.trim();
    // A header reuses the same generic-token reject set as tappable labels:
    // "Tab"/"Button" announced as a section heading is as uninformative to a
    // heading-navigating screen-reader user as it is on a control.
    final bool labelIsGeneric =
        label.isNotEmpty && _genericLabelTokens.contains(label.toLowerCase());
    if (label.isEmpty || labelIsGeneric) {
      result += Evaluation.fail(
        '$node: heading node has an empty or generic label '
        '(label="$label"). Headings must describe the section they '
        'introduce so screen-reader users navigating by heading know '
        'where they are.',
      );
    }
    return result;
  }
}

class _LocalizationScopeGuideline extends AccessibilityGuideline {
  const _LocalizationScopeGuideline();

  @override
  String get description =>
      'The pumped tree must resolve a non-empty content locale through a '
      'Localizations ancestor';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    // maybeLocaleOf walks *ancestors* of the context it is given, so it has
    // to be called from below a Localizations scope - the Localizations
    // element itself sits at the scope and resolves null. Every leaf element
    // is below every scope that covers it, so each leaf is asked: one branch
    // pumped outside any scope fails here however the tree orders it.
    var leaves = 0;
    Element? unscoped;
    void visit(Element element) {
      var children = 0;
      element.visitChildElements((Element child) {
        children++;
        visit(child);
      });
      if (children > 0) return;
      leaves++;
      final Locale? locale = Localizations.maybeLocaleOf(element);
      if (locale == null || locale.languageCode.trim().isEmpty) {
        unscoped ??= element;
      }
    }

    for (final Element root in tester.allElements.take(1)) {
      visit(root);
    }
    if (leaves == 0) {
      return Evaluation.fail(
        'Pumped tree is empty: no element from which to resolve a '
        'localization scope.',
      );
    }
    if (unscoped case final Element leaf) {
      return Evaluation.fail(
        'No Localizations ancestor resolves a content locale for '
        '${leaf.widget.runtimeType}: part of the surface was pumped without '
        'a localization scope.',
      );
    }
    return const Evaluation.pass();
  }
}

class _PageTitledGuideline extends AccessibilityGuideline {
  const _PageTitledGuideline();

  @override
  String get description =>
      'The pumped tree must expose a namesRoute title node announced on '
      'navigation: a descriptive, non-control-token title for screens (WCAG '
      '2.4.2 Page Titled); modal routes may use the platform-standard dialog '
      'announcement';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    for (final RenderView view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;
      if (_hasDescriptiveRouteTitle(root)) {
        return const Evaluation.pass();
      }
    }
    return Evaluation.fail(
      'No semantics node in the pumped tree is flagged namesRoute with a '
      'descriptive label: the surface exposes no page title for assistive '
      'technology to announce on navigation. Give the screen an AppBar '
      'title (flagged namesRoute on Android, Fuchsia, Linux and Windows), '
      'or wrap its headline in Semantics(header: true, namesRoute: true).',
    );
  }

  bool _hasDescriptiveRouteTitle(SemanticsNode node) {
    // Reads getSemanticsData() on every node - including merged-up children,
    // like the localization-scope floor - so a title that folded into a
    // parent (an AppBar title merged into the toolbar node) is still found:
    // it is announced wherever the namesRoute flag and label land.
    // A hidden or invisible node is not announced, and neither is anything
    // below it, so it cannot title the page.
    if (node.isInvisible || node.flagsCollection.isHidden) return false;
    final SemanticsData data = node.getSemanticsData();
    final String label = data.label.trim();
    if (data.flagsCollection.namesRoute &&
        label.isNotEmpty &&
        !_genericLabelTokens.contains(label.toLowerCase())) {
      return true;
    }
    var found = false;
    node.visitChildren((SemanticsNode child) {
      if (_hasDescriptiveRouteTitle(child)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }
}
