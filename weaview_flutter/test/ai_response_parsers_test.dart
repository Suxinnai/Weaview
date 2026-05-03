import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/ai_response_parsers.dart';

void main() {
  group('AI response parsers', () {
    test('splits completed reasoning blocks from answer text', () {
      final parsed = splitReasoning('<think>分析过程</think>\n最终答案');

      expect(parsed.answer, '最终答案');
      expect(parsed.reasoning, '分析过程');
      expect(parsed.thinking, isFalse);
    });

    test('marks unfinished reasoning as still thinking', () {
      final parsed = splitReasoning('开头<think>还在思考');

      expect(parsed.answer, '开头');
      expect(parsed.reasoning, '还在思考');
      expect(parsed.thinking, isTrue);
    });

    test(
      'consumes hidden theme command without leaking it into answer text',
      () {
        final parsed = consumeThemeCommand(
          '好的<modify_ui_state>{"bubbleStyle":"none"}</modify_ui_state>',
        );

        expect(parsed.text, '好的');
        expect(parsed.args, {'bubbleStyle': 'none'});
      },
    );

    test('leaves plain text unchanged when no theme command exists', () {
      final parsed = consumeThemeCommand('普通回答');

      expect(parsed.text, '普通回答');
      expect(parsed.args, isNull);
    });
  });
}
