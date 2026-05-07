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

  test(
    'posts Xiaomi MiMo streaming TTS request and wraps pcm16 as wav',
    () async {
      late Uri seenUri;
      late Map<String, dynamic> seenBody;
      final firstChunk = base64Encode([1, 0, 2, 0]);
      final secondChunk = base64Encode([3, 0, 4, 0]);
      final client = TtsClient(
        client: MockClient((request) async {
          seenUri = request.url;
          seenBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['api-key'], 'mimo-key');
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            '''
data: {"choices":[{"delta":{"audio":{"data":"$firstChunk"}}}]}

data: {"choices":[{"delta":{"audio":"$secondChunk"}}]}

data: [DONE]
''',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final result = await client.synthesize(
        config: const TtsProviderConfig(
          id: 'xiaomi',
          type: 'xiaomi',
          name: 'Xiaomi MiMo TTS',
          apiKey: 'mimo-key',
          baseUrl: 'https://api.xiaomimimo.com/v1',
          model: 'mimo-v2-tts',
          voice: 'default_en',
        ),
        text: 'hello',
        timeout: const Duration(seconds: 1),
      );

      expect(
        seenUri.toString(),
        'https://api.xiaomimimo.com/v1/chat/completions',
      );
      expect(seenBody['model'], 'mimo-v2-tts');
      expect(seenBody['messages'], [
        {'role': 'assistant', 'content': 'hello'},
      ]);
      expect(seenBody['audio'], {'format': 'pcm16', 'voice': 'default_en'});
      expect(seenBody['stream'], isTrue);
      expect(result.mimeType, 'audio/wav');
      expect(String.fromCharCodes(result.bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(result.bytes.skip(8).take(4)), 'WAVE');
      expect(result.bytes.skip(44).toList(), [1, 0, 2, 0, 3, 0, 4, 0]);
    },
  );

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
