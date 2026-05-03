import 'dart:convert';

({String contentDelta, String reasoningDelta}) parseOpenAiStreamData(
  String data,
) {
  final decoded = jsonDecode(data);
  if (decoded is! Map) return (contentDelta: '', reasoningDelta: '');
  final choices = decoded['choices'] as List? ?? const [];
  if (choices.isEmpty) return (contentDelta: '', reasoningDelta: '');
  final first = choices.first;
  if (first is! Map) return (contentDelta: '', reasoningDelta: '');
  final delta = first['delta'] as Map? ?? const {};
  return (
    contentDelta: delta['content']?.toString() ?? '',
    reasoningDelta:
        delta['reasoning_content']?.toString() ??
        delta['reasoning']?.toString() ??
        '',
  );
}
