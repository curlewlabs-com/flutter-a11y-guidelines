import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real face the font-independence tests render in. `flutter_test` draws
/// every glyph as a filled box unless a font is loaded, and a filled box covers
/// its pixels fully, so pixel sampling and declared colors agree under it and
/// the difference this package's text guideline exists for never shows.
const String testFontFamily = 'Plus Jakarta Sans';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    final loader = FontLoader(testFontFamily)
      ..addFont(
        File('test/fonts/PlusJakartaSans-VariableFont_wght.ttf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await loader.load();
  });
  await testMain();
}
