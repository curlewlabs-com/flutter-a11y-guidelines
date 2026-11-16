import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_a11y_guidelines/flutter_a11y_guidelines.dart';

// Most of these guidelines pass vacuously on whole categories of trees - a page
// with no heading clears the heading guideline, any localized tree clears the
// locale floor - so a guideline turned into a no-op is easy to miss on real
// pages that all pass. Each group has a known-bad case proving the guideline
// can still fail, and a known-good one proving it does not fail everything.

Future<void> _pump(WidgetTester tester, Widget body) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: body),
      ),
    ),
  );
}

// A tap target large enough for the stock size guidelines, with no text.
Widget _tappable({VoidCallback? onTap}) => GestureDetector(
  onTap: onTap ?? () {},
  child: const SizedBox(width: 56, height: 56),
);

void main() {
  group('explicit semantics label', () {
    // The failure the stock guideline lets through: "Button" is non-empty.
    testWidgets('a tappable node labeled "Button" passes the stock label '
        'guideline and fails this one', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Semantics(button: true, label: 'Button', child: _tappable()),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(
        tester,
        doesNotMeetGuideline(explicitSemanticsLabelGuideline),
      );
      handle.dispose();
    });

    // The tooltip path: an icon control wrapped in `Tooltip(message:
    // 'Switch')` with no label of its own.
    testWidgets('a tappable node whose only descriptor is the tooltip '
        '"Switch" fails', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, Tooltip(message: 'Switch', child: _tappable()));

      await expectLater(
        tester,
        doesNotMeetGuideline(explicitSemanticsLabelGuideline),
      );
      handle.dispose();
    });

    testWidgets('a descriptive label passes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Semantics(button: true, label: 'Save changes', child: _tappable()),
      );

      await expectLater(
        tester,
        meetsGuideline(explicitSemanticsLabelGuideline),
      );
      handle.dispose();
    });

    // Full-string equality, not substring containment: a change to substring
    // matching would flag every label that legitimately contains a widget
    // word.
    testWidgets('a label containing "Switch" as a word passes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Semantics(button: true, label: 'Switch accounts', child: _tappable()),
      );

      await expectLater(
        tester,
        meetsGuideline(explicitSemanticsLabelGuideline),
      );
      handle.dispose();
    });
  });

  group('heading label quality (WCAG 2.4.6)', () {
    for (final label in ['Tab', '']) {
      testWidgets('a heading labeled "$label" fails', (tester) async {
        await _pump(
          tester,
          Semantics(
            header: true,
            label: label,
            child: const SizedBox(width: 56, height: 56),
          ),
        );

        await expectLater(
          tester,
          doesNotMeetGuideline(headingLabelQualityGuideline),
        );
      });
    }

    testWidgets('a descriptive heading passes, including one that contains a '
        'widget word', (tester) async {
      await _pump(
        tester,
        Semantics(
          header: true,
          label: 'Settings tab',
          child: const SizedBox(width: 56, height: 56),
        ),
      );

      await expectLater(tester, meetsGuideline(headingLabelQualityGuideline));
    });
  });

  group('localization scope', () {
    testWidgets('a tree with no Localizations ancestor fails', (tester) async {
      // A bare Directionality keeps the tree renderable without supplying a
      // localization scope.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: Text('no localizations scope here')),
        ),
      );

      await expectLater(
        tester,
        doesNotMeetGuideline(localizationScopeGuideline),
      );
    });

    // A branch outside any scope fails wherever the tree puts it; reading
    // one leaf, the last in depth-first order, missed a branch ordered first.
    // The twin scopes that branch too, and passes.
    for (final scoped in [false, true]) {
      testWidgets('a branch ordered before a scoped one '
          '${scoped ? 'passes when scoped' : 'fails unscoped'}', (
        tester,
      ) async {
        Widget localized(Widget child) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: child,
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                if (scoped)
                  localized(const Text('first branch'))
                else
                  const Text('first branch'),
                localized(const Text('localized')),
              ],
            ),
          ),
        );

        await expectLater(
          tester,
          scoped
              ? meetsGuideline(localizationScopeGuideline)
              : doesNotMeetGuideline(localizationScopeGuideline),
        );
      });
    }

    testWidgets('a MaterialApp tree resolves a locale and passes', (
      tester,
    ) async {
      await _pump(tester, const Text('localized content'));

      await expectLater(tester, meetsGuideline(localizationScopeGuideline));
    });
  });

  group('page titled (WCAG 2.4.2)', () {
    // Readable body text is not a title: nothing here is announced on a route
    // change.
    testWidgets('a page with text but no namesRoute node fails', (
      tester,
    ) async {
      await _pump(tester, const Text('Readable body text'));

      await expectLater(tester, doesNotMeetGuideline(pageTitledGuideline));
    });

    testWidgets('a namesRoute title labeled "Tab" fails', (tester) async {
      await _pump(
        tester,
        Semantics(
          namesRoute: true,
          label: 'Tab',
          child: const SizedBox(width: 56, height: 56),
        ),
      );

      await expectLater(tester, doesNotMeetGuideline(pageTitledGuideline));
    });

    // The fix for a screen with no AppBar title.
    testWidgets('a headline wrapped in Semantics(header, namesRoute) passes', (
      tester,
    ) async {
      await _pump(
        tester,
        Semantics(
          header: true,
          namesRoute: true,
          child: const Text('Choose your check-in time'),
        ),
      );

      await expectLater(tester, meetsGuideline(pageTitledGuideline));
    });

    // A hidden node is not announced, so a title only it carries leaves the
    // page untitled. The twin is the same title, visible, and passes.
    for (final hidden in [true, false]) {
      testWidgets(
        'a namesRoute title ${hidden ? 'fails hidden' : 'passes '
                  'visible'}',
        (tester) async {
          await _pump(
            tester,
            Semantics(
              hidden: hidden,
              namesRoute: true,
              label: 'Choose your check-in time',
              child: const SizedBox(width: 56, height: 56),
            ),
          );

          await expectLater(
            tester,
            hidden
                ? doesNotMeetGuideline(pageTitledGuideline)
                : meetsGuideline(pageTitledGuideline),
          );
        },
      );
    }

    // Pins the framework behavior the guideline relies on: the test platform
    // flags an AppBar title namesRoute. If a Flutter release stopped doing
    // so, every screen with an AppBar title would start failing, and this
    // names the cause.
    testWidgets('an AppBar title passes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const Center(child: Text('body')),
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(pageTitledGuideline));
    });

    // The scope boundary: a modal route passes on the framework's own route
    // announcement, with no bespoke title.
    testWidgets('a dialog with no title passes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(
                      content: Text('A confirmation with no title.'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(pageTitledGuideline));
    });
  });
}
