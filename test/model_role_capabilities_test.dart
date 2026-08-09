import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('role-aware model capability filtering', () {
    test(
      'treats Gemini image catalog entries as pure image generation models',
      () {
        expect(
          isPureImageGenerationModel(
            id: 'gemini-3.1-flash-image',
            name: 'Nano Banana 2',
            capabilities: const ['vision', 'image'],
          ),
          isTrue,
        );
      },
    );

    test(
      'treats name-inferred image models without explicit caps as pure image generation',
      () {
        expect(
          isPureImageGenerationModel(
            id: 'gemini-3.1-flash-lite-image',
            name: 'Nano Banana 2 Lite',
          ),
          isTrue,
        );
        expect(
          supportsModelRole(
            role: 'chat',
            id: 'gemini-3.1-flash-lite-image',
            name: 'Nano Banana 2 Lite',
          ),
          isFalse,
        );
      },
    );

    test('excludes pure image models from non-image roles', () {
      const id = 'gemini-3-pro-image';
      const name = 'Nano Banana Pro';
      const capabilities = ['vision', 'image'];

      expect(
        supportsModelRole(
          role: 'image',
          id: id,
          name: name,
          capabilities: capabilities,
        ),
        isTrue,
      );
      for (final role in const [
        'chat',
        'title',
        'suggest',
        'translate',
        'tool',
      ]) {
        expect(
          supportsModelRole(
            role: role,
            id: id,
            name: name,
            capabilities: capabilities,
          ),
          isFalse,
          reason: '$role should reject pure image generation models',
        );
      }
    });

    test('allows chat models for text roles and tool fallback', () {
      for (final role in const [
        'chat',
        'title',
        'suggest',
        'translate',
        'tool',
      ]) {
        expect(
          supportsModelRole(
            role: role,
            id: 'gpt-4o-mini',
            name: 'gpt-4o-mini',
            capabilities: const ['chat'],
          ),
          isTrue,
          reason: '$role should allow standard chat models',
        );
      }
    });

    test(
      'keeps multimodal chat models eligible for both image and chat roles',
      () {
        const capabilities = ['chat', 'vision', 'image'];

        expect(
          isPureImageGenerationModel(
            id: 'provider/multimodal-image-editor',
            name: 'Multimodal Image Editor',
            capabilities: capabilities,
          ),
          isFalse,
        );
        expect(
          supportsModelRole(
            role: 'chat',
            id: 'provider/multimodal-image-editor',
            name: 'Multimodal Image Editor',
            capabilities: capabilities,
          ),
          isTrue,
        );
        expect(
          supportsModelRole(
            role: 'image',
            id: 'provider/multimodal-image-editor',
            name: 'Multimodal Image Editor',
            capabilities: capabilities,
          ),
          isTrue,
        );
      },
    );

    test('tool role accepts explicit tool models', () {
      expect(
        supportsModelRole(
          role: 'tool',
          id: 'gpt-5',
          name: 'gpt-5',
          capabilities: const ['chat', 'tool'],
        ),
        isTrue,
      );
    });
  });
}
