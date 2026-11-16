/// Accessibility guidelines for Flutter widget tests, for use with
/// `flutter_test`'s `meetsGuideline` beside its stock guidelines.
library;

export 'src/graphic_contrast.dart' show GraphicContrastGuideline;
export 'src/semantics_guidelines.dart'
    show
        explicitSemanticsLabelGuideline,
        headingLabelQualityGuideline,
        localizationScopeGuideline,
        pageTitledGuideline;
export 'src/state_contrast.dart'
    show StateContrastGuidelineAAA, stateContrastGuidelineAAA;
export 'src/text_contrast.dart'
    show
        DeclaredColorTextContrastGuidelineAAA,
        TextContrastExemption,
        textContrastGuidelineAAA;
