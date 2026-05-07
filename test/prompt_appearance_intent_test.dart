import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/app/prompt_appearance_intent.dart';

void main() {
  test('prompt appearance intent ignores non-style prompts', () {
    expect(PromptAppearanceIntent.parse('帮我总结这段资料'), isEmpty);
  });

  test('prompt appearance intent parses text color and font controls', () {
    final args = PromptAppearanceIntent.parse('把聊天文字改成粉色粗体并居中');

    expect(args['textColor'], '#DB2777');
    expect(args['fontWeight'], 'bold');
    expect(args['messageAlignment'], 'center');
  });

  test('prompt appearance intent parses background color and dark mode', () {
    final args = PromptAppearanceIntent.parse('背景改成 #123abc 深色');

    expect(args['backgroundColor'], '#123ABC');
    expect(args['isDark'], isTrue);
  });

  test('prompt appearance intent parses glass bubble opacity', () {
    final args = PromptAppearanceIntent.parse('气泡用 glass 透明度 35%');

    expect(args['bubbleStyle'], 'glass');
    expect(args['bubbleOpacity'], 0.35);
  });

  test('prompt appearance intent parses bubble removal', () {
    final args = PromptAppearanceIntent.parse('去掉聊天气泡');

    expect(args['bubbleStyle'], 'none');
    expect(args['bubbleOpacity'], 0.0);
    expect(args, isNot(contains('backgroundColor')));
  });
}
