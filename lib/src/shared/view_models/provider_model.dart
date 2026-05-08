import '../../domain/models.dart';

class ProviderModel {
  const ProviderModel({required this.provider, required this.model});

  final AiProvider provider;
  final AiModel model;

  bool get supportsImageGeneration {
    return looksLikeImageGenerationModel(
      id: model.id,
      name: model.name,
      capabilities: model.capabilities,
    );
  }
}
