import 'ai_model.dart';

const openAiImageModels = <AiModel>[
  AiModel(
    id: 'gpt-image-2',
    name: 'GPT Image 2',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'gpt-image-1',
    name: 'GPT Image 1',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'gpt-image-1-mini',
    name: 'GPT Image 1 Mini',
    capabilities: ['vision', 'image'],
  ),
  AiModel(id: 'dall-e-3', name: 'DALL·E 3', capabilities: ['image']),
];

const grokImageModels = <AiModel>[
  AiModel(
    id: 'grok-imagine-image-quality',
    name: 'Grok Imagine Quality',
    capabilities: ['vision', 'image'],
  ),
];

const seedreamImageModels = <AiModel>[
  AiModel(
    id: 'doubao-seedream-5-0-lite-260128',
    name: 'Seedream 5.0 Lite',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'doubao-seedream-5-0-260128',
    name: 'Seedream 5.0',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'doubao-seedream-4-0-250828',
    name: 'Seedream 4.0',
    capabilities: ['vision', 'image'],
  ),
];

List<AiModel> withPresetModels(
  Iterable<AiModel> models,
  Iterable<AiModel> presets,
) {
  final existing = models.toList();
  final existingIds = existing.map((model) => model.id.toLowerCase()).toSet();
  return [
    ...existing,
    for (final preset in presets)
      if (!existingIds.contains(preset.id.toLowerCase())) preset,
  ];
}
