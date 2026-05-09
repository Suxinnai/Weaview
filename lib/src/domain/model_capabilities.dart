bool looksLikeImageGenerationModel({
  required String id,
  required String name,
  Iterable<String> capabilities = const [],
}) {
  final normalizedCaps = capabilities.map(_normalizeCapabilityToken).toSet();
  if (normalizedCaps.any(_isImageCapability)) return true;

  final text = _normalize('$id $name');
  return _imageModelNeedles.any(text.contains);
}

bool shouldUseResponsesImageTool(String modelId) {
  final text = _normalize(modelId);
  return _responsesImageNeedles.any(text.contains);
}

List<String> guessModelCapabilities(
  String id, {
  String name = '',
  Iterable<Object?> hints = const [],
}) {
  final text = _normalize('$id $name');
  final caps = <String>{};
  for (final hint in hints) {
    caps.addAll(_capabilitiesFromValue(hint));
  }
  if (text.contains('vision') || text.contains('vl') || text.contains('omni')) {
    caps.add('vision');
  }
  if (looksLikeImageGenerationModel(id: id, name: name)) {
    caps.add('image');
  }
  if (text.contains('tool') || text.contains('function')) caps.add('tool');
  if (text.contains('reason') || text.contains('think')) caps.add('reason');
  if (caps.isEmpty || caps.contains('vision') || caps.contains('tool')) {
    caps.add('chat');
  }
  return normalizeModelCapabilities(caps);
}

List<String> modelCapabilitiesFromRecord(dynamic record) {
  if (record is! Map) {
    final value = record?.toString() ?? '';
    return guessModelCapabilities(value, name: value);
  }
  final id = (record['id'] ?? record['name'] ?? '').toString();
  final name = (record['name'] ?? id).toString();
  final hints = <Object?>[
    record['capabilities'],
    record['capability'],
    record['supported_capabilities'],
    record['modalities'],
    record['supported_modalities'],
    record['features'],
    record['supported_features'],
    record['tags'],
    record['type'],
    record['abilities'],
    record['supported_abilities'],
    record['parameters'],
    record['supported_parameters'],
    record['supported_tools'],
    record['tools'],
    record['tool_calls'],
    record['tool_calling'],
    record['function_calling'],
    record['functions'],
  ];

  final caps = <String>{};
  for (final hint in hints) {
    caps.addAll(_capabilitiesFromValue(hint));
  }
  for (final value in _flattenValues(record['input_modalities'])) {
    if (_looksLikeImageInput(value)) caps.add('vision');
    if (_looksLikeText(value)) caps.add('chat');
  }
  for (final value in _flattenValues(record['output_modalities'])) {
    if (_looksLikeImageOutput(value)) caps.add('image');
    if (_looksLikeText(value)) caps.add('chat');
  }
  caps.addAll(guessModelCapabilities(id, name: name, hints: hints));
  return normalizeModelCapabilities(caps);
}

List<String> normalizeModelCapabilities(Iterable<Object?> capabilities) {
  final normalized = <String>{};
  for (final capability in capabilities) {
    normalized.addAll(_capabilitiesFromValue(capability));
  }
  if (normalized.isEmpty) normalized.add('chat');
  return [
    for (final cap in _capabilityOrder)
      if (normalized.contains(cap)) cap,
    for (final cap in normalized)
      if (!_capabilityOrder.contains(cap)) cap,
  ];
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

Iterable<String> _capabilitiesFromValue(Object? value) sync* {
  if (value == null) return;
  if (value is Iterable) {
    for (final item in value) {
      yield* _capabilitiesFromValue(item);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      final enabled = entry.value;
      if (enabled == false || enabled == null) continue;
      yield* _capabilitiesFromValue(entry.key);
      if (enabled is String || enabled is Iterable || enabled is Map) {
        yield* _capabilitiesFromValue(enabled);
      }
    }
    return;
  }
  final token = _normalizeCapabilityToken(value.toString());
  if (token.isEmpty) return;
  if (_chatCapabilityNeedles.any(token.contains)) yield 'chat';
  if (_visionCapabilityNeedles.any(token.contains)) yield 'vision';
  if (_imageCapabilityNeedles.any(token.contains)) yield 'image';
  if (_toolCapabilityNeedles.any(token.contains)) yield 'tool';
  if (_reasonCapabilityNeedles.any(token.contains)) yield 'reason';
}

Iterable<String> _flattenValues(Object? value) sync* {
  if (value == null) return;
  if (value is Iterable) {
    for (final item in value) {
      yield* _flattenValues(item);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value == false || entry.value == null) continue;
      yield entry.key.toString();
      yield* _flattenValues(entry.value);
    }
    return;
  }
  yield value.toString();
}

bool _looksLikeImageInput(String value) {
  final token = _normalizeCapabilityToken(value);
  return token == 'image' ||
      token == 'images' ||
      token == 'image_input' ||
      token == 'input_image' ||
      token == 'vision';
}

bool _looksLikeImageOutput(String value) {
  final token = _normalizeCapabilityToken(value);
  return _isImageCapability(token) ||
      token == 'image' ||
      token == 'images' ||
      token == 'output_image';
}

bool _looksLikeText(String value) {
  final token = _normalizeCapabilityToken(value);
  return token == 'text' || token == 'chat' || token == 'completion';
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeCapabilityToken(String value) {
  return _normalize(value)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

const _capabilityOrder = ['chat', 'vision', 'image', 'tool', 'reason'];

const _chatCapabilityNeedles = [
  'chat',
  'text',
  'llm',
  'language',
  'completion',
  'conversation',
];

const _visionCapabilityNeedles = [
  'vision',
  'visual',
  'image_input',
  'input_image',
  'image_to_text',
  'image_understanding',
  'multimodal',
  'omni',
  'vl',
];

const _imageCapabilityNeedles = [
  'image',
  'images',
  'image_generation',
  'image_generation_model',
  'image_generate',
  'text_to_image',
  'image_edit',
  'output_image',
  'image_output',
  'generate_image',
];

const _toolCapabilityNeedles = [
  'tool',
  'tools',
  'tool_choice',
  'tool_calls',
  'parallel_tool_calls',
  'function',
  'functions',
  'function_call',
  'function_calls',
  'function_calling',
  'tool_use',
  'json_schema',
  'structured_output',
];

const _reasonCapabilityNeedles = ['reason', 'reasoning', 'think', 'thinking'];

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
  'gemini-3.1-flash-image',
  'gemini-3-flash-image',
  'gemini-2.5-flash-image',
  'flash-image-preview',
  'image-preview',
  'image-generation',
  'image_generation',
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
