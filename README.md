# flutter_a11y_guidelines

## What it is

Accessibility guidelines for Flutter widget tests. Each one is an
`AccessibilityGuideline` from `flutter_test`, so you check it the same way as
the stock guidelines, with `meetsGuideline`:

- `textContrastGuidelineAAA`: WCAG AAA text contrast (7:1, or 4.5:1 for large
  text). It measures the color the text declares against the background
  actually painted behind it.
- `stateContrastGuidelineAAA`: hovers, presses and focuses every enabled
  control, scrolling through each vertical scrollable, and measures text
  contrast again in each state.
- `GraphicContrastGuideline<T>`: WCAG 1.4.11's 3:1 for the non-text graphics
  you name, such as a status dot, measured against what each is drawn on.
- `explicitSemanticsLabelGuideline`: rejects a tappable node whose only label is
  a widget-type word such as "Button".
- `headingLabelQualityGuideline`: WCAG 2.4.6 for headings. A header node needs a
  label that is neither empty nor a widget-type word.
- `pageTitledGuideline`: WCAG 2.4.2. The screen exposes a route title that
  assistive technology announces on navigation.
- `localizationScopeGuideline`: the tree resolves a content locale through a
  `Localizations` ancestor.

## Why it exists

`flutter_test` ships tap-target, label and text-contrast guidelines. They leave
gaps that real apps fall into:

- **Its contrast verdict depends on the font.** The stock
  `textContrastGuideline` and `MinimumTextContrastGuidelineAAA` read both colors
  off rendered pixels. Under the test's default box font every glyph pixel is
  fully covered, and the reading is right. Load your app's real fonts, which you
  should do for layout tests anyway, and antialiased strokes leave most glyph
  pixels part-covered. The "text color" the stock guideline finds is then a
  blend of the text and its background, so it fails text whose declared colors
  pass. `textContrastGuidelineAAA` takes the foreground from the declared style,
  including each styled span of a `Text.rich`. It still samples the background,
  so an image or an unplanned fill behind the text is caught. It also uses
  WCAG's large-text sizes (24px, or 18.66px bold) where the stock ones use
  18px, or 14px bold.
- **It measures only the page at rest.** A button whose hover overlay darkens
  the fill under its label, or whose pressed label turns grey, passes every
  resting check. `TextButton.styleFrom(foregroundColor: x)` does this by
  default: it derives an `x`-tinted overlay for hover, focus and press.
- **Non-empty is not meaningful.** `labeledTapTargetGuideline` accepts a label
  of "Button". It has nothing to say about headings, page titles or non-text
  contrast.

## How to use it

This package is not on pub.dev. Add it as a git dependency at a release tag:

```yaml
dev_dependencies:
  flutter_a11y_guidelines:
    git:
      url: https://github.com/curlewlabs-com/flutter-a11y-guidelines.git
      ref: v0.1.0
```

Then check each guideline in a widget test, after the stock ones:

```dart
import 'package:flutter_a11y_guidelines/flutter_a11y_guidelines.dart';
import 'package:flutter_test/flutter_test.dart';

testWidgets('settings page meets the accessibility guidelines', (tester) async {
  await tester.pumpWidget(const MyApp(home: SettingsPage()));

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuidelineAAA));
  await expectLater(tester, meetsGuideline(explicitSemanticsLabelGuideline));
  await expectLater(tester, meetsGuideline(headingLabelQualityGuideline));
  await expectLater(tester, meetsGuideline(pageTitledGuideline));
  await expectLater(tester, meetsGuideline(localizationScopeGuideline));
  // Last: it moves the pointer, focus and scroll position, and a guideline
  // after it would measure whatever it left behind.
  await expectLater(tester, meetsGuideline(stateContrastGuidelineAAA));
});
```

Wrap these calls in one helper of your own and call it from every page test.
Then each page reports every violation in one run, and adding a guideline is a
one-line change.

`testWidgets` turns semantics on by default. A test that turns it off must call
`tester.ensureSemantics()` before checking these guidelines.

### Configuring the contrast guidelines

**A logotype exemption.** WCAG 1.4.3 exempts text that is part of a logo. Name
your logotype widget, not its color: the same color used for ordinary copy
elsewhere should still fail.

```dart
bool isLogotype(Element element) =>
    element.findAncestorWidgetOfExactType<CompanyLogo>() != null;

const textContrast = DeclaredColorTextContrastGuidelineAAA(isExempt: isLogotype);

// Hand the same instance to the state guideline, so the exemption holds while
// a control is hovered, pressed or focused too.
const stateContrast = StateContrastGuidelineAAA(textContrast: textContrast);
```

**Graphics that carry meaning.** WCAG 1.4.11 asks 3:1 only of graphics needed
to understand the content, so name those types yourself:

```dart
const statusDotContrast = GraphicContrastGuideline<StatusDot>(
  colorOf: statusDotColor,
  hint: 'Status colors are defined in AppColors.',
);

Color statusDotColor(StatusDot dot) => dot.color;
```

The guideline expects a solid mark of one color. It samples `ring` logical
pixels around the widget's box (6 by default) and takes the most frequent color
that is not the mark's own as the background. The ring has to be wide enough
for that background to outnumber the mark's antialiased edge pixels.

## What each guideline rejects

| Guideline                         | A widget it rejects                                                                     |
| --------------------------------- | --------------------------------------------------------------------------------------- |
| `textContrastGuidelineAAA`        | `Text('Hi', style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 14))` on white (5.1:1) |
| `stateContrastGuidelineAAA`       | `TextButton(style: TextButton.styleFrom(foregroundColor: Color(0xFF244A6A)), ...)` on `Color(0xFFECE4D5)`: passes at rest; its hover, press and focus overlays each take it under 7:1 |
| `GraphicContrastGuideline<T>`     | A 10px `T` filled `Color(0xFFCFE0CF)` on white (1.38:1)                                 |
| `explicitSemanticsLabelGuideline` | `Semantics(button: true, label: 'Button', child: GestureDetector(onTap: ...))`          |
| `headingLabelQualityGuideline`    | `Semantics(header: true, label: 'Tab', child: ...)`                                     |
| `pageTitledGuideline`             | A `Scaffold` with body text, no `AppBar` title and no `namesRoute` node                 |
| `localizationScopeGuideline`      | A tree pumped under a bare `Directionality`, with no `WidgetsApp` or `Localizations`    |

The tests under `test/` hold each of these cases, and a passing one beside it.

## Behavior to know about

- **Load your real fonts in tests.** The text guideline gives the same verdict
  under any font. Your layout tests do not, and loading fonts is what makes the
  stock guideline disagree with this one. `test/flutter_test_config.dart` in
  this repository shows a `FontLoader` setup.
- **Text with no color fails.** A style with a `foreground` paint (gradient or
  shader text), or a gap in the `DefaultTextStyle` chain, declares no single
  color to measure. The guideline fails it rather than drop it from coverage.
- **The state guideline never completes a tap.** It holds each press and then
  cancels it, so the page under test does not navigate, open a dialog, or call
  a service. Disabled controls are not driven, since WCAG exempts inactive
  components. It settles the page for every state of every control, so its
  cost grows with the number of controls on the page.
- **Generic words are matched whole.** "Button", "IconButton", "Switch",
  "Toggle", "Checkbox", "Radio" and "Tab" are rejected in any case; "Switch
  accounts" is a real label.
- **Modal routes pass `pageTitledGuideline` without a title of their own.**
  Flutter gives every dialog and sheet a route announcement ("Dialog",
  "Alert"), and screen-reader users expect it.
- **`localizationScopeGuideline` supports WCAG 3.1.1 but does not check it.**
  3.1.1 is about the platform telling assistive technology the content
  language, which happens in the engine, below what a widget test can see. The
  guideline checks the floor under it: a localization scope exists.

## Requirements

Flutter 3.47 or later (Dart 3.13). CI runs the tests on the Flutter release
pinned in `.github/workflows/ci.yml`, on Linux and macOS.

## License

MIT. See [LICENSE](LICENSE). The test font under `test/fonts/` is Plus Jakarta
Sans, under the SIL Open Font License beside it; it is used by the tests only
and is not part of the library.
