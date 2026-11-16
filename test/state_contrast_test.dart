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

  // A long-press handler fires at its deadline whether or not the press is
  // later cancelled, so a press held through a full settle would run it.
  testWidgets('drives a press without firing a long-press handler', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    await _pumpFixture(
      tester,
      TextButton(
        onPressed: () => taps++,
        onLongPress: () => longPresses++,
        child: const Text('Edit time'),
      ),
    );

    await stateContrastGuidelineAAA.evaluate(tester);

    expect(taps, 0);
    expect(longPresses, 0);
  });

  // A list with no item count grows as it scrolls; without a bound the walk
  // never returns, and the test hangs instead of failing.
  testWidgets('fails, rather than hangs, on a list that never ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: _surface,
          body: ListView.builder(
            itemBuilder: (context, index) => SizedBox(
              height: 120,
              child: Text(
                'row $index',
                style: const TextStyle(color: _restInk),
              ),
            ),
          ),
        ),
      ),
    );

    final Evaluation evaluation = await stateContrastGuidelineAAA.evaluate(
      tester,
    );
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('Stopped walking'));
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

  // Each layout below is checked with a label that fails only while hovered,
  // which the walk must find, and with the same layout and a label that holds
  // AAA in every state, which it must pass: a walk that failed everything
  // would satisfy the first alone.
  for (final failing in [true, false]) {
    final String label = failing ? 'failing label' : 'compliant label';
    Widget control() =>
        failing ? _inkOnlyFailsIn(WidgetState.hovered) : _steady();

    // The walk starts each scrollable at its beginning, not where the page
    // opened it, so a control above the opening offset is still driven.
    testWidgets('reaches a control above where the list opens ($label)', (
      tester,
    ) async {
      await _expectWalk(
        tester,
        failing,
        ListView(
          controller: ScrollController(initialScrollOffset: 1400),
          children: [
            Center(child: control()),
            const SizedBox(height: 2000),
          ],
        ),
      );
    });

    // A nested list that only comes into view further down is walked where
    // it appears; collected up front, it was never seen.
    testWidgets('reaches a control in a nested list below the fold ($label)', (
      tester,
    ) async {
      await _expectWalk(
        tester,
        failing,
        ListView(
          children: [
            const SizedBox(height: 900),
            SizedBox(
              height: 300,
              child: ListView(
                children: [
                  const SizedBox(height: 700),
                  Center(child: control()),
                ],
              ),
            ),
          ],
        ),
      );
    });

    // A tall control whose centre is on screen while its label is still
    // below the fold takes a pointer, but its label cannot be measured yet.
    // It is driven again once a step brings all of it into view.
    testWidgets('drives again a control first seen partly outside the view '
        '($label)', (tester) async {
      await _expectWalk(
        tester,
        failing,
        ListView(
          children: [
            const SizedBox(height: 400),
            Center(
              child: TextButton(
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(200, 300)),
                  alignment: Alignment.bottomCenter,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => failing && states.contains(WidgetState.hovered)
                        ? _failingInk
                        : _restInk,
                  ),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
                onPressed: () {},
                child: const Text('Edit time'),
              ),
            ),
            const SizedBox(height: 1200),
          ],
        ),
      );
    });

    // A nested list the outer viewport clips cannot show its end at any
    // offset of its own; once the outer walk reveals all of it, it is walked
    // again.
    testWidgets('walks a clipped nested list again once it is in full view '
        '($label)', (tester) async {
      await _expectWalk(
        tester,
        failing,
        ListView(
          children: [
            const SizedBox(height: 400),
            SizedBox(
              height: 300,
              child: ListView(
                children: [
                  const SizedBox(height: 540),
                  Center(child: control()),
                ],
              ),
            ),
            const SizedBox(height: 600),
          ],
        ),
      );
    });

    // The same inside an outer list shorter than the screen: the window shows
    // all of the nested list's box while the outer viewport still cuts it, so
    // what is in view is read through every viewport above it.
    testWidgets('walks a nested list an inset viewport clips ($label)', (
      tester,
    ) async {
      await _expectWalk(
        tester,
        failing,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 400,
            child: ListView(
              children: [
                const SizedBox(height: 250),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: [
                      const SizedBox(height: 540),
                      Center(child: control()),
                    ],
                  ),
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      );
    });
  }

  // Scrolling a lazy outer list disposes the nested lists it scrolls past;
  // driving a disposed one threw instead of measuring.
  testWidgets('walks nested lazy lists without driving a disposed one', (
    tester,
  ) async {
    await _expectWalk(
      tester,
      false,
      ListView.builder(
        itemCount: 40,
        itemBuilder: (context, index) => index == 0
            ? SizedBox(
                height: 200,
                child: ListView(
                  children: [
                    for (var j = 0; j < 6; j++) Center(child: _steady()),
                  ],
                ),
              )
            : SizedBox(
                height: 120,
                child: Text(
                  'row $index',
                  style: const TextStyle(color: _restInk),
                ),
              ),
      ),
    );
  });
}

// A text button that holds AAA in every state on [_surface].
Widget _steady() => TextButton(
  style: ButtonStyle(
    foregroundColor: WidgetStateProperty.all(_restInk),
    overlayColor: WidgetStateProperty.all(Colors.transparent),
  ),
  onPressed: () {},
  child: const Text('Edit time'),
);

// Pumps [body] and expects the state walk to find the hover failure in it,
// or, when [failing] is false, to pass it.
Future<void> _expectWalk(WidgetTester tester, bool failing, Widget body) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(backgroundColor: _surface, body: body),
    ),
  );
  await tester.pumpAndSettle();

  final Evaluation evaluation = await stateContrastGuidelineAAA.evaluate(
    tester,
  );
  if (failing) {
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('While hovering "Edit time"'));
  } else {
    expect(evaluation.passed, isTrue, reason: evaluation.reason);
  }
}

bool _always(Element element) => true;
