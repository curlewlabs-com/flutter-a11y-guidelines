import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_a11y_guidelines/flutter_a11y_guidelines.dart';

// Each state gets a fixture that fails in that state alone, so a regression in
// how one state is driven - a mouse pointer that never registers as a hover, a
// press read before the tap-down deadline, a focus that never lands - turns
// one case red instead of passing silently. The fixtures sit in a `ListView`,
// as most pages' controls do, so the press has to wait out the scrollable's
// gesture arena.

// A warm grey surface, and an ink that clears AAA on it at rest.
const Color _surface = Color(0xFFECE4D5);
const Color _restInk = Color(0xFF244A6A);
// Under even AA on [_surface].
const Color _failingInk = Color(0xFF8A8A8A);

Future<void> _pumpFixture(
  WidgetTester tester,
  Widget control, {
  double above = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: _surface,
        body: ListView(
          children: [
            SizedBox(height: above),
            Center(child: control),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// A text button whose label drops to [_failingInk] in [state] only. The
// overlay is pinned transparent, so the label color is the only thing the
// state changes.
Widget _inkOnlyFailsIn(WidgetState state, {VoidCallback? onPressed}) {
  return TextButton(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(state) ? _failingInk : _restInk,
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    onPressed: onPressed ?? () {},
    child: const Text('Edit time'),
  );
}

void main() {
  for (final (state, phrase) in [
    (WidgetState.hovered, 'While hovering "Edit time"'),
    (WidgetState.pressed, 'While pressing "Edit time"'),
    (WidgetState.focused, 'While focusing "Edit time"'),
  ]) {
    testWidgets('rejects a label that fails only while ${state.name}', (
      tester,
    ) async {
      await _pumpFixture(tester, _inkOnlyFailsIn(state));

      await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
      final Evaluation evaluation = await stateContrastGuidelineAAA.evaluate(
        tester,
      );
      expect(evaluation.passed, isFalse);
      expect(evaluation.reason, contains(phrase));
    });
  }

  // A lifted press would run the page's handlers - navigation, dialogs,
  // service calls - in the middle of the measurement.
  testWidgets('drives a press without completing the tap', (tester) async {
    var taps = 0;
    await _pumpFixture(
      tester,
      _inkOnlyFailsIn(WidgetState.pressed, onPressed: () => taps++),
    );

    await stateContrastGuidelineAAA.evaluate(tester);

    expect(taps, 0);
  });

  // `styleFrom` handed a foreground synthesizes an overlay tinted with it,
  // which darkens the fill under the label. The label never changes color, so
  // only a measurement of the painted state sees it.
  testWidgets('rejects the overlay styleFrom derives from a foreground', (
    tester,
  ) async {
    await _pumpFixture(
      tester,
      TextButton(
        style: TextButton.styleFrom(foregroundColor: _restInk),
        onPressed: () {},
        child: const Text('Edit time'),
      ),
    );

    await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
    await expectLater(tester, doesNotMeetGuideline(stateContrastGuidelineAAA));
  });

  // A lazily built list has not mounted a control below the fold, so only the
  // scroll walk reaches it; without the walk this fixture passes with the
  // button never measured.
  testWidgets('reaches a control below the fold', (tester) async {
    await _pumpFixture(
      tester,
      _inkOnlyFailsIn(WidgetState.hovered),
      above: 2000,
    );

    final Evaluation evaluation = await stateContrastGuidelineAAA.evaluate(
      tester,
    );
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('While hovering "Edit time"'));
  });

  // A focus highlight paints only in the traditional highlight mode, and the
  // touch of every press switches the automatic strategy out of it. Here only
  // the focus overlay darkens the fill, so a focus measured in touch mode would
  // see nothing.
  testWidgets('measures the focus overlay, not only the focused label', (
    tester,
  ) async {
    await _pumpFixture(
      tester,
      TextButton(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(_restInk),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? _restInk.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        onPressed: () {},
        child: const Text('Edit time'),
      ),
    );

    final Evaluation evaluation = await stateContrastGuidelineAAA.evaluate(
      tester,
    );
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('While focusing "Edit time"'));
  });

  // The passing control: without it, a guideline that failed everything would
  // satisfy every case above.
  testWidgets('accepts controls that hold AAA in every state', (tester) async {
    final ButtonStyle steady = ButtonStyle(
      foregroundColor: WidgetStateProperty.all(_restInk),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    );
    await _pumpFixture(
      tester,
      Column(
        children: [
          TextButton(
            style: steady,
            onPressed: () {},
            child: const Text('Text'),
          ),
          OutlinedButton(
            style: steady,
            onPressed: () {},
            child: const Text('Outlined'),
          ),
        ],
      ),
    );

    await expectLater(tester, meetsGuideline(stateContrastGuidelineAAA));
  });

  // The text guideline it re-runs is the caller's, so an exemption the resting
  // page is measured with holds in every state as well.
  testWidgets('runs the text guideline it is given', (tester) async {
    await _pumpFixture(tester, _inkOnlyFailsIn(WidgetState.hovered));

    const AccessibilityGuideline exemptAll = StateContrastGuidelineAAA(
      textContrast: DeclaredColorTextContrastGuidelineAAA(isExempt: _always),
    );
    await expectLater(tester, meetsGuideline(exemptAll));
  });
}

bool _always(Element element) => true;
