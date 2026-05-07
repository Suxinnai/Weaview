import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weaview_flutter/src/data/ai/tts_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test(
    'posts OpenAI-compatible speech request and returns audio bytes',
    () async {
      late Uri seenUri;
      late Map<String, dynamic> seenBody;
      final client = TtsClient(
        client: MockClient((request) async {
          seenUri = request.url;
          seenBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['Authorization'], 'Bearer tts-key');
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'audio/mpeg'},
          );
        }),
      );

      final result = await client.synthesize(
        config: const TtsProviderConfig(
          id: 'openai',
          type: 'openai',
          name: 'OpenAI TTS',
          apiKey: 'tts-key',
          baseUrl: 'https://example.test/v1',
          model: 'gpt-4o-mini-tts',
          voice: 'alloy',
        ),
        text: '你好',
        timeout: const Duration(seconds: 1),
      );

      expect(seenUri.toString(), 'https://example.test/v1/audio/speech');
      expect(seenBody['model'], 'gpt-4o-mini-tts');
      expect(seenBody['input'], '你好');
      expect(seenBody['voice'], 'alloy');
      expect(seenBody['response_format'], 'mp3');
      expect(result.bytes, [1, 2, 3]);
      expect(result.mimeType, 'audio/mpeg');
    },
  );

  test('accepts base URL already pointing at speech endpoint', () async {
    late Uri seenUri;
    final client = TtsClient(
      client: MockClient((request) async {
        seenUri = request.url;
        return http.Response.bytes([9], 200);
      }),
    );

    await client.synthesize(
      config: const TtsProviderConfig(
        id: 'custom',
        type: 'openai',
        name: 'Custom TTS',
        apiKey: 'key',
        baseUrl: 'https://example.test/audio/speech',
        model: 'tts',
        voice: 'alloy',
      ),
      text: 'test',
      timeout: const Duration(seconds: 1),
    );

    expect(seenUri.toString(), 'https://example.test/audio/speech');
  });

  test('rejects missing remote TTS configuration', () async {
    final client = TtsClient(
      client: MockClient((_) async => http.Response('', 500)),
    );

    expect(
      () => client.synthesize(
        config: const TtsProviderConfig(
          id: 'broken',
          type: 'openai',
          name: 'Broken',
          apiKey: '',
          baseUrl: 'https://example.test/v1',
          model: 'tts',
          voice: 'alloy',
        ),
        text: 'hello',
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
