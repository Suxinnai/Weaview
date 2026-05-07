import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/app/ai_theme_guard.dart';

void main() {
  group('AiThemeGuard', () {
    test('keeps unrelated fields when prompt has no style intent', () {
      final guarded = AiThemeGuard.guard({
        'backgroundColor': '#000000',
        'textColor': '#FFFFFF',
        'bubbleStyle': 'glass',
      }, userPrompt: '总结一下这段内容');

      expect(guarded, {
        'backgroundColor': '#000000',
        'textColor': '#FFFFFF',
        'bubbleStyle': 'glass',
      });
    });

    test('bubble removal prompt cannot rewrite global theme fields', () {
      final guarded = AiThemeGuard.guard({
        'resetTheme': true,
        'backgroundColor': '#000000',
        'textColor': '#FFFFFF',
        'fontFamily': 'serif',
        'bubbleStyle': 'solid',
        'bubbleColor': '#FF0000',
      }, userPrompt: '请去掉聊天气泡');

      expect(guarded, {'bubbleStyle': 'none', 'bubbleOpacity': 0.0});
    });

    test('font prompt only permits font and text fields', () {
      final guarded = AiThemeGuard.guard({
        'backgroundColor': '#000000',
        'bubbleStyle': 'solid',
        'fontFamily': 'serif',
        'fontStyle': 'italic',
        'fontWeight': 'bold',
      }, userPrompt: '把字体改成斜体加粗的衬线字体');

      expect(guarded, {
        'fontFamily': 'serif',
        'fontStyle': 'italic',
        'fontWeight': 'bold',
      });
    });

    test('background prompt only permits background fields', () {
      final guarded = AiThemeGuard.guard({
        'backgroundColor': '#101010',
        'isDark': true,
        'textColor': '#FFFFFF',
        'bubbleStyle': 'glass',
      }, userPrompt: '把背景改成深色');

      expect(guarded, {'backgroundColor': '#101010', 'isDark': true});
    });
  });
}
