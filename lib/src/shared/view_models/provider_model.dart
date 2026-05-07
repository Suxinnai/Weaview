import '../../domain/models.dart';

class ProviderModel {
  const ProviderModel({required this.provider, required this.model});

  final AiProvider provider;
  final AiModel model;

  bool get supportsImageGeneration {
    final caps = model.capabilities.map((cap) => cap.toLowerCase()).toSet();
    final id = model.id.toLowerCase();
    final name = model.name.toLowerCase();
    return caps.contains('image') ||
        id.contains('gpt-image') ||
        name.contains('gpt-image') ||
        id.contains('dall-e') ||
        name.contains('dall-e');
  }
}
