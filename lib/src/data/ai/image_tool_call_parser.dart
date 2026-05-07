import 'dart:convert';

class ParsedImageToolCall {
  const ParsedImageToolCall({required this.prompt, required this.raw});

  final String prompt;
  final String raw;
}

ParsedImageToolCall? parseImageToolCall(String text) {
  for (final raw in _toolCallBlocks(text)) {
    if (!raw.toLowerCase().contains('sync_gen_images')) continue;
    final prompt = _promptFromArguments(raw) ?? _promptFromJsonLikeText(raw);
    if (prompt == null || prompt.trim().isEmpty) continue;
    return ParsedImageToolCall(prompt: prompt.trim(), raw: raw);
  }
  return null;
}

String stripImageToolCalls(String text) {
  return text
      .replaceAll(_toolCallPattern, '')
      .replaceAll(RegExp(r'\n[ \t]*\n'), '\n')
      .trimRight();
}

Iterable<String> _toolCallBlocks(String text) sync* {
  for (final match in _toolCallPattern.allMatches(text)) {
    final raw = match.group(0);
    if (raw != null && raw.trim().isNotEmpty) yield raw;
  }
}

final _toolCallPattern = RegExp(
  r'<tool_call\b[\s\S]*?(?:</tool_call>|$)',
  caseSensitive: false,
);

String? _promptFromArguments(String raw) {
  final match = RegExp(
    r'(?:arguments|parameters)\s*=\s*"((?:\\.|[^"\\])*)"',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final encoded = match.group(1);
  if (encoded == null || encoded.trim().isEmpty) return null;
  return _promptFromJsonLikeText(_decodeAttribute(encoded));
}

String? _promptFromJsonLikeText(String raw) {
  final candidates = <String>[
    raw,
    _decodeAttribute(raw),
    raw.replaceAll('&quot;', '"'),
  ];
  for (final candidate in candidates) {
    final prompt = _promptFromDecodedJson(candidate);
    if (prompt != null && prompt.trim().isNotEmpty) return prompt;
  }

  final promptMatch = RegExp(
    r'"prompt"\s*:\s*"((?:\\.|[^"\\])*)"',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(_decodeAttribute(raw));
  final encodedPrompt = promptMatch?.group(1);
  if (encodedPrompt == null) return null;
  try {
    final decoded = jsonDecode('"$encodedPrompt"');
    return decoded is String ? decoded : encodedPrompt;
  } catch (_) {
    return encodedPrompt.replaceAll(r'\"', '"');
  }
}

String? _promptFromDecodedJson(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    return _promptFromNode(decoded);
  } catch (_) {
    return null;
  }
}

String? _promptFromNode(dynamic node) {
  if (node is Map) {
    final direct = node['prompt'];
    if (direct is String) return direct;
    final args = node['arguments'] ?? node['parameters'];
    final nested = _promptFromNode(args);
    if (nested != null) return nested;
    for (final value in node.values) {
      final found = _promptFromNode(value);
      if (found != null) return found;
    }
  }
  if (node is String) {
    return _promptFromJsonLikeText(node);
  }
  if (node is List) {
    for (final value in node) {
      final found = _promptFromNode(value);
      if (found != null) return found;
    }
  }
  return null;
}

String _decodeAttribute(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll(r'\"', '"');
}
