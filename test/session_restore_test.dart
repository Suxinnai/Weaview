import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  final older = ChatSession(
    id: 'older',
    title: '较早会话',
    updatedAt: 100,
    messages: [ChatMessage(role: 'user', content: '较早内容')],
  );
  final newer = ChatSession(
    id: 'newer',
    title: '最近会话',
    updatedAt: 200,
    messages: [ChatMessage(role: 'user', content: '最近内容')],
  );

  test('restores the explicitly active conversation on launch', () async {
    SharedPreferences.setMockInitialValues({
      'chat_sessions': jsonEncode([older.toJson(), newer.toJson()]),
      'last_session_id': older.id,
    });
    final state = WeaviewState();

    await state.load();

    expect(state.currentSessionId, older.id);
    expect(state.messages.single.content, '较早内容');
    state.dispose();
  });

  test(
    'migrates existing installs by restoring the most recent session',
    () async {
      SharedPreferences.setMockInitialValues({
        'chat_sessions': jsonEncode([older.toJson(), newer.toJson()]),
      });
      final state = WeaviewState();

      await state.load();

      expect(state.currentSessionId, newer.id);
      expect(state.messages.single.content, '最近内容');
      state.dispose();
    },
  );

  test(
    'keeps an explicitly opened new conversation blank after restart',
    () async {
      SharedPreferences.setMockInitialValues({
        'chat_sessions': jsonEncode([older.toJson(), newer.toJson()]),
        'last_session_id': '',
      });
      final state = WeaviewState();

      await state.load();

      expect(state.currentSessionId, isNull);
      expect(state.messages, isEmpty);
      state.dispose();
    },
  );
}
