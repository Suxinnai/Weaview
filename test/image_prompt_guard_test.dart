import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/image_prompt_guard.dart';

void main() {
  group('image prompt quality guard', () {
    test('adds face clarity guard by default', () {
      final prompt = imagePromptWithDefaultQualityGuard(
        'a pastel anime poster',
      );

      expect(prompt, contains('a pastel anime poster'));
      expect(prompt, contains('non-mosaic'));
      expect(prompt, contains('non-pixelated'));
    });

    test('does not override explicit mosaic requests', () {
      const source = '给人物脸部加马赛克，保护隐私';

      expect(imagePromptWithDefaultQualityGuard(source), source);
    });
  });
}
