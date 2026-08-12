import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('ships mainstream providers with real image-capable models', () {
    final providers = {
      for (final provider in AiProvider.defaults()) provider.name: provider,
    };

    final expectedModels = <String, String>{
      'OpenAI': 'gpt-image-2',
      'Gemini': 'gemini-3.1-flash-image',
      'Grok': 'grok-imagine-image-quality',
      '火山方舟': 'doubao-seedream-5-0-lite-260128',
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

  test('excludes image-only provider presets by default', () {
    final names = AiProvider.defaults().map((item) => item.name).toSet();
    expect(names, isNot(contains('Recraft')));
    expect(names, isNot(contains('Stability AI')));
    expect(names, isNot(contains('Black Forest Labs')));
    expect(names, isNot(contains('Ideogram')));
    expect(names, isNot(contains('Replicate')));
  });

  test('preserves image API routing when provider settings round-trip', () {
    final openAi = AiProvider.defaults().firstWhere(
      (item) => item.name == 'OpenAI',
    );
    final restored = AiProvider.fromJson(openAi.toJson());
    expect(restored.imageApi, ImageApiKind.openAi);
    expect(restored.models.map((model) => model.id), contains('gpt-image-2'));

    final ark = AiProvider.defaults().firstWhere((item) => item.name == '火山方舟');
    expect(AiProvider.fromJson(ark.toJson()).imageApi, ImageApiKind.ark);
  });
}
