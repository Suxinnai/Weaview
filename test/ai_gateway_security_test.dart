import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/ai_gateway.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('AiGateway transport policy', () {
    test('rejects a remote cleartext model endpoint before network I/O', () {
      expect(
        AiGateway.fetchModels(
          apiKey: 'secret',
          baseUrl: 'http://api.example.com/v1',
          providerName: 'Custom',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => '$error',
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });

    test('rejects a provider with a remote cleartext route', () {
      const model = AiModel(
        id: 'chat-model',
        name: 'Chat Model',
        capabilities: ['chat'],
      );
      const provider = AiProvider(
        name: 'Custom',
        status: '已连接',
        current: true,
        color: Color(0xFF000000),
        apiKey: 'secret',
        baseUrl: 'http://api.example.com/v1',
        models: [model],
      );

      expect(
        AiGateway.generate(
          messages: [ChatMessage.user('hello')],
          systemInstruction: '',
          provider: provider,
          assignment: const ModelAssignment(
            provider: 'Custom',
            model: 'chat-model',
            prompt: '',
          ),
          onThemeUpdate: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (error) => '$error',
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });

    test('rejects remote cleartext TTS endpoints', () {
      expect(
        () => AiGateway.synthesizeSpeech(
          config: const TtsProviderConfig(
            id: 'custom',
            type: 'openai',
            name: 'Custom',
            apiKey: 'secret',
            baseUrl: 'http://tts.example.com/v1',
            model: 'tts-model',
            voice: 'voice',
          ),
          text: 'hello',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => '$error',
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });
  });
}
