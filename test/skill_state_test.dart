import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';

void main() {
  test('WeaviewState appends skill run result as model message', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true,"text":"tweet result"}');
      await request.response.close();
    });
    SharedPreferences.setMockInitialValues({
      'skill_runner_base_url': 'http://127.0.0.1:${server.port}',
      'skills':
          '[{"id":"x-tweet-fetcher","name":"X Tweet Fetcher","description":"Fetch tweets","sourceUrl":"https://github.com/ythx-101/x-tweet-fetcher","enabled":true,"triggers":["tweet"],"createdAt":1,"updatedAt":1}]',
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
      expect(state.messages.last.content, 'tweet result');
      expect(state.messages.last.isThinking, isFalse);
    } finally {
      state.dispose();
      await serving.cancel();
      await server.close(force: true);
    }
  });
}
