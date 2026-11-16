import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_a11y_guidelines/flutter_a11y_guidelines.dart';

import 'flutter_test_config.dart';

// A navy that clears AAA on a cream as declared, and the cream itself.
const Color _navy = Color(0xFF244A6A);
const Color _cream = Color(0xFFFBF6ED);

// #6E6E6E on white is about 5.1:1: over AA (4.5:1), under AAA (7:1).
const Color _aaOnlyGrey = Color(0xFF6E6E6E);

// #595959 on white is exactly 7.00:1, on the AAA bar.
const Color _aaaFloorGrey = Color(0xFF595959);

// A gold that measures about 2:1 on cream, under every bar.
const Color _gold = Color(0xFFE9A330);

Future<void> _pumpText(
  WidgetTester tester,
  Widget text, {
  Color background = Colors.white,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: background,
        body: Center(child: text),
      ),
    ),
  );
}

// A logotype, the shape WCAG 1.4.3 exempts. Its text is ordinary `Text`, so
// only the exemption predicate can tell it from copy.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Text('Acme', style: TextStyle(color: _gold, fontSize: 20));
  }
}

bool _isLogo(Element element) =>
    element.findAncestorWidgetOfExactType<_Logo>() != null;

const AccessibilityGuideline _withLogoExempt =
    DeclaredColorTextContrastGuidelineAAA(isExempt: _isLogo);

void main() {
  group('AAA bar', () {
    // The band between AA and AAA is what separates this guideline from
    // flutter_test's stock AA one; a fixture in it passes one and fails the
    // other.
    testWidgets('an AA-only pair passes the stock AA guideline and fails AAA', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpText(
        tester,
        const Text(
          'aa-passes-aaa-fails',
          style: TextStyle(color: _aaOnlyGrey, fontSize: 14),
        ),
      );

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, doesNotMeetGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });

    // The float slack: a pair exactly on the bar must not fail on rounding.
    testWidgets('a pair exactly on the AAA bar passes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpText(
        tester,
        const Text(
          'aaa-passes',
          style: TextStyle(color: _aaaFloorGrey, fontSize: 14),
        ),
      );

      await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });
  });

  // The verdict must come from the declared colors, not from how much of each
  // pixel the glyphs happen to cover. The fixtures above name no family, so
  // they render in flutter_test's box font, where sampled and declared colors
  // agree. These name a real face, where they diverge.
  group('the verdict does not depend on the loaded font', () {
    testWidgets('a declared-AAA pair passes where pixel sampling fails it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpText(
        tester,
        const Text(
          'terms of service',
          style: TextStyle(
            fontFamily: testFontFamily,
            color: _navy,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            decoration: TextDecoration.underline,
            decorationColor: _navy,
          ),
        ),
        background: _cream,
      );

      await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
      // Pins the divergence rather than assuming it: if a Flutter release
      // makes the stock guideline read declared colors too, this fails, and
      // the reason for this guideline is gone.
      await expectLater(
        tester,
        doesNotMeetGuideline(const MinimumTextContrastGuidelineAAA()),
      );
      handle.dispose();
    });

    // The other direction: reading declared colors must not pass everything.
    testWidgets('a declared sub-AAA pair still fails in a real face', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpText(
        tester,
        const Text(
          'aa-passes-aaa-fails',
          style: TextStyle(
            fontFamily: testFontFamily,
            color: _aaOnlyGrey,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      );

      await expectLater(tester, doesNotMeetGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });
  });

  // `find.text` matches a `Text.rich` by the plain text of its spans, so the
  // guideline is handed a widget whose colors are not on the widget at all.
  // Reading one widget-level style would let a sub-AAA span pass under an AAA
  // default.
  group('Text.rich is measured per styled span', () {
    Widget richTextWith(Color spanColor) {
      return DefaultTextStyle(
        style: const TextStyle(
          fontFamily: testFontFamily,
          color: _aaaFloorGrey,
          fontSize: 15,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'compliant '),
              TextSpan(
                text: 'span',
                style: TextStyle(color: spanColor),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('a sub-AAA child span fails under an AAA default', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // #AAAAAA on white is about 2.3:1.
      await _pumpText(tester, richTextWith(const Color(0xFFAAAAAA)));

      await expectLater(tester, doesNotMeetGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });

    // The paired control: with a compliant span the same shape passes, so the
    // case above fails on the span's color and not on the shape.
    testWidgets('an AAA child span passes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpText(tester, richTextWith(_navy));

      await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });
  });

  // A style with no color cannot be measured; skipping it would silently drop
  // the text from coverage.
  testWidgets('text that declares no color fails', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: Text(
              'shader text',
              style: TextStyle(
                fontSize: 14,
                foreground: Paint()..color = Colors.black,
              ),
            ),
          ),
        ),
      ),
    );

    final Evaluation evaluation = await textContrastGuidelineAAA.evaluate(
      tester,
    );
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('declares no color'));
    handle.dispose();
  });

  // The exemption is scoped to the logotype widget, and these cases are what
  // say so. A color-scoped exemption would also pass the same gold used for
  // ordinary copy, which is the case that must keep failing.
  group('logotype exemption', () {
    testWidgets('the exempt logotype passes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpText(tester, const _Logo(), background: _cream);

      await expectLater(tester, meetsGuideline(_withLogoExempt));
      handle.dispose();
    });

    testWidgets('the same logotype fails without the exemption', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpText(tester, const _Logo(), background: _cream);

      await expectLater(tester, doesNotMeetGuideline(textContrastGuidelineAAA));
      handle.dispose();
    });

    testWidgets('the same color as ordinary copy still fails', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpText(
        tester,
        const Text(
          'Good morning',
          style: TextStyle(color: _gold, fontSize: 20),
        ),
        background: _cream,
      );

      await expectLater(tester, doesNotMeetGuideline(_withLogoExempt));
      handle.dispose();
    });
  });

  // WCAG's large text is 18pt, or 14pt bold: 24 and 18.66 logical pixels. The
  // stock guideline calls anything from 18px large. #6E6E6E on white sits
  // between the AAA large (4.5:1) and normal (7:1) bars, so each case lands on
  // one side by its size and weight alone.
  group('large-text threshold follows WCAG, not the stock 18px', () {
    for (final (size, weight, large) in [
      (18.0, FontWeight.w600, false),
      (18.66, FontWeight.w600, false),
      (18.66, FontWeight.w700, true),
      (24.0, FontWeight.w400, true),
    ]) {
      testWidgets(
        '${size}px ${weight.value} is ${large ? 'large' : 'normal'} text',
        (tester) async {
          await _pumpText(
            tester,
            Text(
              'threshold-sample',
              style: TextStyle(
                color: _aaOnlyGrey,
                fontSize: size,
                fontWeight: weight,
              ),
            ),
          );
          await expectLater(
            tester,
            large
                ? meetsGuideline(textContrastGuidelineAAA)
                : doesNotMeetGuideline(textContrastGuidelineAAA),
          );
        },
      );
    }
  });
}
