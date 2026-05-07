class ParsedImageGenerationResult {
  const ParsedImageGenerationResult({
    this.base64Data,
    this.url,
    this.mimeType = 'image/png',
    this.revisedPrompt,
  });

  final String? base64Data;
  final String? url;
  final String mimeType;
  final String? revisedPrompt;

  bool get hasImage =>
      (base64Data?.trim().isNotEmpty ?? false) ||
      (url?.trim().isNotEmpty ?? false);
}

ParsedImageGenerationResult parseResponsesImageGeneration(dynamic decoded) {
  if (decoded is Map) {
    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map) continue;
        final type = item['type']?.toString();
        if (type != 'image_generation_call') continue;
        final revisedPrompt = _stringForKey(item, 'revised_prompt');
        final payload = _payloadFromKeys(
          item,
          revisedPrompt: revisedPrompt,
          base64Keys: const ['result', 'image_base64', 'b64_json'],
          urlKeys: const ['url'],
        );
        if (payload.hasImage) return payload;
      }
    }
  }

  return _payloadFromKeys(
    decoded,
    base64Keys: const ['result', 'image_base64', 'b64_json'],
    urlKeys: const ['url'],
  );
}

ParsedImageGenerationResult parseImagesGeneration(dynamic decoded) {
  if (decoded is Map) {
    final data = decoded['data'];
    if (data is List) {
      for (final item in data) {
        final payload = _payloadFromKeys(
          item,
          revisedPrompt: item is Map
              ? _stringForKey(item, 'revised_prompt')
              : null,
          base64Keys: const ['b64_json', 'image_base64', 'result'],
          urlKeys: const ['url'],
        );
        if (payload.hasImage) return payload;
      }
    }
  }

  return _payloadFromKeys(
    decoded,
    base64Keys: const ['b64_json', 'image_base64', 'result'],
    urlKeys: const ['url'],
  );
}

ParsedImageGenerationResult _payloadFromKeys(
  dynamic node, {
  required List<String> base64Keys,
  required List<String> urlKeys,
  String? revisedPrompt,
}) {
  for (final key in base64Keys) {
    final value = _stringForKey(node, key);
    if (value == null || value.trim().isEmpty) continue;
    return _payloadFromBase64(value, revisedPrompt: revisedPrompt);
  }
  for (final key in urlKeys) {
    final value = _stringForKey(node, key);
    if (value == null || value.trim().isEmpty) continue;
    return ParsedImageGenerationResult(
      url: value.trim(),
      revisedPrompt: revisedPrompt,
    );
  }
  return ParsedImageGenerationResult(revisedPrompt: revisedPrompt);
}

ParsedImageGenerationResult _payloadFromBase64(
  String value, {
  String? revisedPrompt,
}) {
  final trimmed = value.trim();
  final dataUri = RegExp(
    r'^data:(image/[-+\w.]+);base64,(.+)$',
    dotAll: true,
  ).firstMatch(trimmed);
  if (dataUri != null) {
    return ParsedImageGenerationResult(
      base64Data: dataUri.group(2)!.trim(),
      mimeType: dataUri.group(1)!,
      revisedPrompt: revisedPrompt,
    );
  }
  return ParsedImageGenerationResult(
    base64Data: trimmed,
    revisedPrompt: revisedPrompt,
  );
}

String? _stringForKey(dynamic node, String key) {
  if (node is Map) {
    final direct = node[key];
    if (direct is String) return direct;
    for (final value in node.values) {
      final nested = _stringForKey(value, key);
      if (nested != null) return nested;
    }
  }
  if (node is List) {
    for (final value in node) {
      final nested = _stringForKey(value, key);
      if (nested != null) return nested;
    }
  }
  return null;
}
