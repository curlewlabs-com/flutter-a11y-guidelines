import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_a11y_guidelines/flutter_a11y_guidelines.dart';

// A 10px status dot that fades and scales in, the shape the guideline is
// written for. The entrance matters: mid-flight no pixel on screen is the
// declared color.
class _Dot extends StatefulWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 360),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(_controller),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

const AccessibilityGuideline _dotContrast = GraphicContrastGuideline<_Dot>(
  colorOf: _dotColor,
  hint: 'Status colors live in the palette.',
);

Color _dotColor(_Dot dot) => dot.color;

// 1.38:1 on white: a pale fill, under 1.4.11's 3:1.
const Color _paleGreen = Color(0xFFCFE0CF);
// About 4:1 on white.
const Color _markGreen = Color(0xFF5A8A57);

Future<void> _pumpDot(WidgetTester tester, Color color) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: _Dot(color: color)),
      ),
    ),
  );
}

void main() {
  testWidgets('rejects a sub-3:1 graphic, naming its type and the hint', (
    tester,
  ) async {
    await _pumpDot(tester, _paleGreen);
    await tester.pumpAndSettle();

    final Evaluation evaluation = await _dotContrast.evaluate(tester);
    expect(evaluation.passed, isFalse);
    expect(evaluation.reason, contains('_Dot('));
    expect(evaluation.reason, contains('Status colors live in the palette.'));
  });

  // The passing control: a guideline that rejected everything, or sampled the
  // wrong pixels, would satisfy the case above.
  testWidgets('accepts a graphic at 3:1 or more', (tester) async {
    await _pumpDot(tester, _markGreen);
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(_dotContrast));
  });

  // Mid-entrance the dot is scaled and partly transparent, so no pixel carries
  // the declared color. A guideline that skipped a graphic it could not find
  // on screen would pass here on a dot that fails at rest - on every page, at
  // every frame of its entrance.
  testWidgets('rejects a sub-3:1 graphic mid-entrance, before it settles', (
    tester,
  ) async {
    await _pumpDot(tester, _paleGreen);
    await tester.pump(const Duration(milliseconds: 120));

    await expectLater(tester, doesNotMeetGuideline(_dotContrast));
    await tester.pumpAndSettle();
  });

  // Only the named type is measured: a quiet divider or border elsewhere is
  // not held to 3:1.
  testWidgets('ignores graphics of other types', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 10,
              height: 10,
              child: ColoredBox(color: _paleGreen),
            ),
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(_dotContrast));
  });
}
