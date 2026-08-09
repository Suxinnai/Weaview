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

const recraftImageModels = <AiModel>[
  AiModel(id: 'recraftv4', name: 'Recraft V4.1', capabilities: ['image']),
  AiModel(
    id: 'recraftv4_pro',
    name: 'Recraft V4.1 Pro',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'recraftv4_vector',
    name: 'Recraft V4.1 Vector',
    capabilities: ['image'],
  ),
];

const stabilityImageModels = <AiModel>[
  AiModel(
    id: 'stable-image-ultra',
    name: 'Stable Image Ultra',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'stable-image-core',
    name: 'Stable Image Core',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'sd3.5-large',
    name: 'Stable Diffusion 3.5 Large',
    capabilities: ['image'],
  ),
];

const bflImageModels = <AiModel>[
  AiModel(
    id: 'flux-2-pro-preview',
    name: 'FLUX.2 Pro（最新）',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'flux-2-max',
    name: 'FLUX.2 Max',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'flux-2-flex',
    name: 'FLUX.2 Flex',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'flux-2-klein-4b',
    name: 'FLUX.2 Klein 4B',
    capabilities: ['vision', 'image'],
  ),
  AiModel(id: 'flux-pro-1.1', name: 'FLUX 1.1 Pro', capabilities: ['image']),
  AiModel(
    id: 'flux-pro-1.1-ultra',
    name: 'FLUX 1.1 Pro Ultra',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'flux-kontext-pro',
    name: 'FLUX Kontext Pro',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'flux-kontext-max',
    name: 'FLUX Kontext Max',
    capabilities: ['vision', 'image'],
  ),
];

const ideogramImageModels = <AiModel>[
  AiModel(id: 'ideogram-v4', name: 'Ideogram 4.0', capabilities: ['image']),
  AiModel(
    id: 'ideogram-v3',
    name: 'Ideogram 3.0',
    capabilities: ['vision', 'image'],
  ),
];

const replicateImageModels = <AiModel>[
  AiModel(id: 'google/imagen-4', name: 'Imagen 4', capabilities: ['image']),
  AiModel(
    id: 'google/imagen-4-ultra',
    name: 'Imagen 4 Ultra',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'black-forest-labs/flux-1.1-pro',
    name: 'FLUX 1.1 Pro',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'black-forest-labs/flux-kontext-pro',
    name: 'FLUX Kontext Pro',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'ideogram-ai/ideogram-v3-turbo',
    name: 'Ideogram V3 Turbo',
    capabilities: ['image'],
  ),
  AiModel(
    id: 'bytedance/seedream-5-lite',
    name: 'Seedream 5.0 Lite',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'bytedance/seedream-4',
    name: 'Seedream 4.0',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'qwen/qwen-image-2-pro',
    name: 'Qwen Image 2 Pro',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'qwen/qwen-image',
    name: 'Qwen Image',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'recraft-ai/recraft-v3',
    name: 'Recraft V3',
    capabilities: ['image'],
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
