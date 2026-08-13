import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weaview_flutter/src/data/ai/anthropic_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('AnthropicClient', () {
    test('uses Anthropic headers and message payload', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Claude reply'},
            ],
          }),
          200,
        );
      });

      final text = await AnthropicClient(client: client).generate(
        apiKey: 'anthropic-key',
        baseUrl: 'https://api.anthropic.com/v1/',
        model: 'claude-test',
        messages: [ChatMessage.user('hello')],
        systemInstruction: 'be useful',
        timeout: const Duration(seconds: 1),
      );

      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'anthropic-key');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-test');
      expect(body['system'], 'be useful');
      expect((body['messages'] as List).single['role'], 'user');
      expect(text, 'Claude reply');
    });

    test('surfaces Anthropic error responses', () async {
      final client = MockClient((_) async => http.Response('bad request', 400));

      expect(
        AnthropicClient(client: client).generate(
          apiKey: 'anthropic-key',
          baseUrl: 'https://api.anthropic.com/v1',
          model: 'claude-test',
          messages: [ChatMessage.user('hello')],
          systemInstruction: '',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('400')),
        ),
      );
    });
  });
}
