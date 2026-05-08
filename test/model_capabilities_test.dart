import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/shared/view_models/provider_model.dart';

void main() {
  group('image model capability detection', () {
    test('recognizes common non-OpenAI image model families', () {
      const imageModels = [
        'gpt-image-2',
        'GPT Image 2',
        'ChatGPT Images 2.0',
        'imagen-4',
        'gemini-3-pro-image',
        'nano-banana-pro',
        'FLUX.2',
        'qwen-image-edit',
        'grok-imagine-1.0-fast',
      ];

      for (final modelId in imageModels) {
        expect(
          looksLikeImageGenerationModel(id: modelId, name: modelId),
          isTrue,
          reason: '$modelId should be selectable as a generation model',
        );
      }
    });

    test('does not treat regular chat models as image models', () {
      expect(
        looksLikeImageGenerationModel(
          id: 'nvidia/minimaxai/minimax-m2.7',
          name: 'nvidia/minimaxai/minimax-m2.7',
        ),
        isFalse,
      );
      expect(
        looksLikeImageGenerationModel(id: 'gpt-4o-mini', name: 'gpt-4o-mini'),
        isFalse,
      );
    });

    test('uses Responses image tool only for OpenAI image families', () {
      expect(shouldUseResponsesImageTool('gpt-image-2'), isTrue);
      expect(shouldUseResponsesImageTool('dall-e-3'), isTrue);
      expect(shouldUseResponsesImageTool('grok-imagine-1.0'), isFalse);
      expect(shouldUseResponsesImageTool('qwen-image-edit'), isFalse);
    });

    test('ProviderModel reflects inferred image capabilities', () {
      const provider = AiProvider(
        name: 'xAI',
        status: '使用中',
        current: true,
        color: Color(0xFF111111),
      );
      const item = ProviderModel(
        provider: provider,
        model: AiModel(id: 'grok-imagine-1.0', name: 'grok-imagine-1.0'),
      );

      expect(item.supportsImageGeneration, isTrue);
    });
  });
}
