import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/openai_image_generation_parser.dart';

void main() {
  group('OpenAI image generation parser', () {
    test('extracts Responses API image generation result', () {
      final parsed = parseResponsesImageGeneration({
        'output': [
          {'type': 'message', 'content': []},
          {
            'type': 'image_generation_call',
            'result': 'ZmFrZS1pbWFnZQ==',
            'revised_prompt': 'a soft glass planet',
          },
        ],
      });

      expect(parsed.base64Data, 'ZmFrZS1pbWFnZQ==');
      expect(parsed.revisedPrompt, 'a soft glass planet');
      expect(parsed.mimeType, 'image/png');
    });

    test('extracts Codex /v1/images generations payload', () {
      final parsed = parseImagesGeneration({
        'data': [
          {'b64_json': 'ZmFrZS1pbWFnZQ==', 'revised_prompt': 'woven light'},
        ],
      });

      expect(parsed.base64Data, 'ZmFrZS1pbWFnZQ==');
      expect(parsed.revisedPrompt, 'woven light');
    });

    test('supports data URI payloads', () {
      final parsed = parseImagesGeneration({
        'data': [
          {'b64_json': 'data:image/webp;base64, ZmFrZS1pbWFnZQ== '},
        ],
      });

      expect(parsed.base64Data, 'ZmFrZS1pbWFnZQ==');
      expect(parsed.mimeType, 'image/webp');
    });
  });
}
