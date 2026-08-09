import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('ships mainstream image providers with real image-capable models', () {
    final providers = {
      for (final provider in AiProvider.defaults()) provider.name: provider,
    };

    final expectedModels = <String, String>{
      'OpenAI': 'gpt-image-2',
      'Gemini': 'gemini-3.1-flash-image',
      'Grok': 'grok-imagine-image-quality',
      '火山方舟': 'doubao-seedream-5-0-lite-260128',
      'Recraft': 'recraftv4',
      'Stability AI': 'stable-image-ultra',
      'Black Forest Labs': 'flux-2-pro-preview',
      'Ideogram': 'ideogram-v4',
      'Replicate': 'qwen/qwen-image',
    };

    for (final entry in expectedModels.entries) {
      final provider = providers[entry.key];
      expect(provider, isNotNull, reason: '${entry.key} should be built in');
      expect(
        provider!.models.map((model) => model.id),
        contains(entry.value),
        reason: '${entry.key} should include ${entry.value}',
      );
      expect(
        provider.models
            .where((model) => model.id == entry.value)
            .single
            .capabilities,
        contains('image'),
      );
    }
  });

  test('preserves image API routing when provider settings round-trip', () {
    final provider = AiProvider.defaults().firstWhere(
      (item) => item.name == 'Black Forest Labs',
    );

    final restored = AiProvider.fromJson(provider.toJson());

    expect(restored.imageApi, ImageApiKind.bfl);
    expect(restored.models.map((model) => model.id), contains('flux-pro-1.1'));

    final ark = AiProvider.defaults().firstWhere((item) => item.name == '火山方舟');
    expect(AiProvider.fromJson(ark.toJson()).imageApi, ImageApiKind.ark);
  });
}
