import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';

void main() {
  group('AiGateway transport policy', () {
    test('permits user-configured cleartext model endpoints', () {
      expect(secureBaseUrlIssue('http://api.example.com/v1'), isNull);
    });

    test('still rejects unsupported transport schemes', () {
      expect(secureBaseUrlIssue('ftp://api.example.com/v1'), contains('HTTP'));
    });

    test('identifies HTTP so settings can show an inline warning', () {
      expect(isCleartextBaseUrl('http://tts.example.com/v1'), isTrue);
      expect(isCleartextBaseUrl('https://tts.example.com/v1'), isFalse);
    });
  });
}
