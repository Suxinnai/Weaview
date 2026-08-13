import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weaview_flutter/src/data/ai/openai_chat_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('OpenAiChatClient', () {
    test('sends the expected chat request and parses reasoning', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'reasoning_content': 'brief thought',
                  'content': 'hello',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final text = await OpenAiChatClient(client: client).generate(
        apiKey: 'test-key',
        baseUrl: 'https://api.example.com/v1',
        model: 'chat-model',
        messages: [ChatMessage.user('hi')],
        systemInstruction: 'be concise',
        timeout: const Duration(seconds: 1),
      );

      expect(
        captured.url.toString(),
        'https://api.example.com/v1/chat/completions',
      );
      expect(captured.headers['authorization'], 'Bearer test-key');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'chat-model');
      expect((body['messages'] as List).first['role'], 'system');
      expect(text, contains('brief thought'));
      expect(text, contains('hello'));
    });

    test('fetches and deduplicates model records', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/models');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'gpt-test', 'name': 'GPT Test'},
              {'id': 'gpt-test', 'name': 'GPT Test duplicate'},
            ],
          }),
          200,
        );
      });

      final models = await OpenAiChatClient(client: client).fetchModels(
        apiKey: 'test-key',
        baseUrl: 'https://api.example.com/v1',
        timeout: const Duration(seconds: 1),
      );

      expect(models, hasLength(1));
      expect(models.single.id, 'gpt-test');
    });

    test('surfaces the upstream status and body', () async {
      final client = MockClient(
        (_) async => http.Response('rate limited', 429),
      );

      expect(
        OpenAiChatClient(client: client).generate(
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com/v1',
          model: 'chat-model',
          messages: [ChatMessage.user('hi')],
          systemInstruction: '',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('429')),
        ),
      );
    });
  });
}
