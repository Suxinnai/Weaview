import 'ai_model.dart';

/// Gemini image models that Weaview supports through the native
/// `generateContent` image API.
const geminiImageModels = <AiModel>[
  AiModel(
    id: 'gemini-3.1-flash-lite-image',
    name: 'Nano Banana 2 Lite',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'gemini-3.1-flash-image',
    name: 'Nano Banana 2',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'gemini-3-pro-image',
    name: 'Nano Banana Pro',
    capabilities: ['vision', 'image'],
  ),
  AiModel(
    id: 'gemini-2.5-flash-image',
    name: 'Nano Banana',
    capabilities: ['vision', 'image'],
  ),
];

List<AiModel> withGeminiImageModels(Iterable<AiModel> models) {
  final existing = models.toList();
  final existingIds = existing.map((model) => model.id.toLowerCase()).toSet();
  return [
    ...existing,
    for (final preset in geminiImageModels)
      if (!existingIds.contains(preset.id.toLowerCase())) preset,
  ];
}
