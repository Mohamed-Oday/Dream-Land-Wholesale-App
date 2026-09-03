import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's bundled Arabic font into the test binding so widget tests
/// measure text with the same metrics as the device (and the printer).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    final loader = FontLoader('IBMPlexSansArabic');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final path = 'fonts/IBMPlexSansArabic-$weight.ttf';
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  } catch (e) {
    debugPrint(
      'WARNING: could not load fonts/IBMPlexSansArabic-*.ttf ($e). '
      'Widget tests will run with the fallback test font, so text metrics '
      'and layout-sensitive expectations may differ.',
    );
  }
  await testMain();
}
