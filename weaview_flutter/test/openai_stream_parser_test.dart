import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/openai_stream_parser.dart';

void main() {
  group('OpenAI stream parser', () {
    test('extracts content deltas', () {
      final parsed = parseOpenAiStreamData(
        '{"choices":[{"delta":{"content":"你好"}}]}',
      );

      expect(parsed.contentDelta, '你好');
      expect(parsed.reasoningDelta, isEmpty);
    });

    test('extracts both reasoning field spellings', () {
      final reasoningContent = parseOpenAiStreamData(
        '{"choices":[{"delta":{"reasoning_content":"正在分析"}}]}',
      );
      final reasoning = parseOpenAiStreamData(
        '{"choices":[{"delta":{"reasoning":"thinking"}}]}',
      );

      expect(reasoningContent.reasoningDelta, '正在分析');
      expect(reasoning.reasoningDelta, 'thinking');
    });

    test('ignores non-choice payloads', () {
      final parsed = parseOpenAiStreamData('{"id":"chunk"}');

      expect(parsed.contentDelta, isEmpty);
      expect(parsed.reasoningDelta, isEmpty);
    });
  });
}
