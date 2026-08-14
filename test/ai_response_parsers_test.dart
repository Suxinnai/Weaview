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

    test('hides an unfinished theme command while streaming', () {
      expect(
        stripThemeCommandMarkup('正在换一层春雾。<modify_ui_state>{"backgroundColor":'),
        '正在换一层春雾。',
      );
    });

    test('hides even the first partial theme token while streaming', () {
      expect(stripThemeCommandMarkup('正在更新。<modif'), '正在更新。');
      expect(stripThemeCommandMarkup('<m'), isEmpty);
    });

    test('removes a theme command without swallowing following prose', () {
      expect(
        stripThemeCommandMarkup(
          '稍候。<modify_ui_state>{"bubbleStyle":"glass"}</modify_ui_state>气泡已经变得轻盈。',
        ),
        '稍候。气泡已经变得轻盈。',
      );
    });
  });
}
