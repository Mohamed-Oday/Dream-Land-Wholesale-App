import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/core/utils/version_utils.dart';

void main() {
  group('isNewerVersion', () {
    test('major bump is newer', () {
      expect(isNewerVersion('2.0.0', '1.0.0'), isTrue);
    });

    test('minor bump is newer', () {
      expect(isNewerVersion('1.1.0', '1.0.0'), isTrue);
    });

    test('patch bump is newer', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });

    test('equal versions returns false', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('older version returns false', () {
      expect(isNewerVersion('1.0.0', '2.0.0'), isFalse);
    });

    test('current app version 0.2.0 equals itself', () {
      expect(isNewerVersion('0.2.0', '0.2.0'), isFalse);
    });

    test('next patch 0.2.1 is newer than 0.2.0', () {
      expect(isNewerVersion('0.2.1', '0.2.0'), isTrue);
    });

    test('multi-digit version comparison', () {
      expect(isNewerVersion('10.0.0', '9.9.9'), isTrue);
    });

    test('shorter equal version returns false', () {
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    });

    test('longer version with extra segment is newer', () {
      expect(isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
    });
  });
}
