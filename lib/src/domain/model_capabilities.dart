bool looksLikeImageGenerationModel({
  required String id,
  required String name,
  Iterable<String> capabilities = const [],
}) {
  final normalizedCaps = capabilities.map(_normalize).toSet();
  if (normalizedCaps.any(_isImageCapability)) return true;

  final text = _normalize('$id $name');
  return _imageModelNeedles.any(text.contains);
}

bool shouldUseResponsesImageTool(String modelId) {
  final text = _normalize(modelId);
  return _responsesImageNeedles.any(text.contains);
}

List<String> guessModelCapabilities(String id, {String name = ''}) {
  final text = _normalize('$id $name');
  final caps = <String>[];
  if (text.contains('vision') || text.contains('vl') || text.contains('omni')) {
    caps.add('vision');
  }
  if (looksLikeImageGenerationModel(id: id, name: name)) {
    caps.add('image');
  }
  if (text.contains('tool') || text.contains('function')) caps.add('tool');
  if (text.contains('reason') || text.contains('think')) caps.add('reason');
  return caps.isEmpty ? ['chat'] : caps;
}

bool _isImageCapability(String capability) {
  return capability == 'image' ||
      capability == 'images' ||
      capability == 'image_generation' ||
      capability == 'image-generation' ||
      capability == 'text_to_image' ||
      capability == 'text-to-image' ||
      capability == 'image_edit' ||
      capability == 'image-edit';
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _responsesImageNeedles = [
  'gpt-image',
  'gpt image',
  'chatgpt-image',
  'chatgpt image',
  'chatgpt images',
  'dall-e',
  'dalle',
];

const _imageModelNeedles = [
  ..._responsesImageNeedles,
  'imagen',
  'gemini 3 pro image',
  'gemini-3-pro-image',
  'gemini_image',
  'gemini-image',
  'nano banana',
  'nano-banana',
  'nanobanana',
  'banana pro',
  'flux',
  'qwen-image',
  'qwen_image',
  'qwen/image',
  'qwen image',
  'grok-imagine',
  'grok_imagine',
  'grok imagine',
  'imagine-1.0',
  'imagine_1.0',
  'seedream',
  'dreamina',
  'recraft',
  'stable-diffusion',
  'stable diffusion',
  'sdxl',
  'kolors',
  'hidream',
  'jimeng',
];
