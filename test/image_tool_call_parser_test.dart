import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/image_tool_call_parser.dart';

void main() {
  group('image tool call parser', () {
    test(
      'extracts sync_gen_images prompt from escaped arguments attribute',
      () {
        const text = '''
正在生成，请稍候。
<tool_call>
name="sync_gen_images"
arguments="{\\"prompt\\":\\"16:9 avant-garde poster\\"}"
</tool_call>
''';

        final parsed = parseImageToolCall(text);

        expect(parsed, isNotNull);
        expect(parsed!.prompt, '16:9 avant-garde poster');
      },
    );

    test('strips complete and partial tool call markup from visible text', () {
      expect(
        stripImageToolCalls('前置说明\n<tool_call>name="sync_gen_images"'),
        '前置说明',
      );
      expect(
        stripImageToolCalls(
          '前置说明\n<tool_call>name="sync_gen_images"</tool_call>\n后置',
        ),
        '前置说明\n后置',
      );
    });
  });
}
