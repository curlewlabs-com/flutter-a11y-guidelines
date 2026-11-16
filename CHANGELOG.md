# Changelog

## 0.2.0

### Removed

- `GraphicContrastGuideline(ring:)`. The sampled ring is a fixed width wide
  enough for any solid mark's antialiased edge. To move, drop the argument.

### Changed

Each change below makes a guideline measure more of what is painted, so a test
that passed on 0.1.0 can fail on 0.2.0 where the page really falls short.

- `textContrastGuidelineAAA`:
  - an `Opacity` or `FadeTransition` above the text fades it in the
    measurement;
  - large text is judged at the smaller of its declared and its painted size;
  - every color a paragraph's spans declare is set aside when finding the
    background, so a short span is not measured against a longer span's glyphs;
  - an `EditableText` is measured in the spans its controller paints.
- `stateContrastGuidelineAAA`:
  - steps each vertical scrollable from its start, half a viewport at a time;
  - walks scrollables that only appear further down, and nested lazy lists,
    where they appear, instead of driving one that was disposed;
  - drives a control again as more of it comes into view.
- `pageTitledGuideline` does not count a hidden or invisible title.
- `localizationScopeGuideline` checks every leaf of the tree, not one.

The README's Known issues section is now Limits, and lists what remains.

## 0.1.0

First release: `textContrastGuidelineAAA` and
`DeclaredColorTextContrastGuidelineAAA`, `stateContrastGuidelineAAA` and
`StateContrastGuidelineAAA`, `GraphicContrastGuideline`,
`explicitSemanticsLabelGuideline`, `headingLabelQualityGuideline`,
`pageTitledGuideline`, and `localizationScopeGuideline`.
