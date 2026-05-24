import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';

void main() {
  test(
    'WeaviewState uses skill as chat context instead of runner execution',
    () async {
      SharedPreferences.setMockInitialValues({
        'skill_runner_base_url': 'http://127.0.0.1:1',
        'skills':
            '[{"id":"x-tweet-fetcher","name":"X Tweet Fetcher","description":"Fetch tweets","sourceUrl":"https://github.com/ythx-101/x-tweet-fetcher","enabled":true,"triggers":["tweet"],"systemPrompt":"Use visible tweet context only.","createdAt":1,"updatedAt":1}]',
      });
      final state = WeaviewState();

      try {
        await state.load();
        final skill = state.skills.single;

        await state.submitSkillMessage(
          'tweet https://x.com/example/status/123',
          skill: skill,
        );

        expect(state.messages.length, 2);
        expect(state.messages.first.role, 'user');
        expect(state.messages.last.role, 'model');
        expect(state.messages.last.content, contains('主对话模型'));
        expect(state.messages.last.content, isNot(contains('技能执行失败')));
        expect(state.messages.last.isThinking, isFalse);
      } finally {
        state.dispose();
      }
    },
  );
}
