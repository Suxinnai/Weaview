import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';

void main() {
  group('app utils', () {
    test('normalizes OpenAI-compatible base URLs without changing paths', () {
      expect(
        normalizeBaseUrl('api.example.com/v1/'),
        'https://api.example.com/v1',
      );
      expect(
        normalizeBaseUrl('HTTPS:/api.example.com/v1//'),
        'https://api.example.com/v1',
      );
      expect(
        normalizeBaseUrl('http:///localhost:11434/v1'),
        'http://localhost:11434/v1',
      );
      expect(
        normalizeBaseUrl(
          'http://[2409:8a60:365b:e0a0:fe6f:f17:1f82:dedf]:3141/v1/',
        ),
        'http://[2409:8a60:365b:e0a0:fe6f:f17:1f82:dedf]:3141/v1',
      );
    });

    test('parses enum and opacity inputs defensively', () {
      expect(enumPref(' BOLD ', const ['normal', 'bold'], 'normal'), 'bold');
      expect(enumPref('heavy', const ['normal', 'bold'], 'normal'), 'normal');
      expect(enumArg('Italic', const ['normal', 'italic']), 'italic');
      expect(enumArg('oblique', const ['normal', 'italic']), isNull);

      expect(opacityArg(40), 0.4);
      expect(opacityArg('0.25'), 0.25);
      expect(opacityArg(2), 0.02);
      expect(opacityArg('not-a-number'), isNull);
    });

    test('converts colors and picks readable text colors', () {
      const blue = Color(0xFF3366FF);

      expect(colorToHex(blue), '#3366FF');
      expect(colorFromHex('#3366FF'), blue);
      expect(readableTextFor(Colors.white), const Color(0xFF2C3E50));
      expect(readableTextFor(Colors.black), const Color(0xFFE5E7EB));
    });

    test('decodes list preferences from list or single map payloads', () {
      final list = decodeList<int>('[1,2,3]', (item) => item as int);
      final single = decodeList<String>('{"name":"one"}', (item) {
        return (item as Map)['name'] as String;
      });

      expect(list, [1, 2, 3]);
      expect(single, ['one']);
      expect(decodeList<int>('not json', (item) => item as int), isEmpty);
    });
  });
}
