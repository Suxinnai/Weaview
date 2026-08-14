import 'dart:convert';

class ReasoningSplit {
  const ReasoningSplit({
    required this.answer,
    required this.reasoning,
    required this.thinking,
  });

  final String answer;
  final String reasoning;
  final bool thinking;
}

ReasoningSplit splitReasoning(String raw) {
  final answer = StringBuffer();
  final reasoning = StringBuffer();
  var index = 0;
  var thinking = false;

  while (index < raw.length) {
    final start = raw.indexOf('<think>', index);
    if (start < 0) {
      answer.write(raw.substring(index));
      break;
    }
    answer.write(raw.substring(index, start));
    final contentStart = start + '<think>'.length;
    final end = raw.indexOf('</think>', contentStart);
    if (end < 0) {
      reasoning.write(raw.substring(contentStart));
      thinking = true;
      break;
    }
    reasoning.write(raw.substring(contentStart, end));
    reasoning.write('\n\n');
    index = end + '</think>'.length;
  }

  return ReasoningSplit(
    answer: answer.toString().trimLeft(),
    reasoning: reasoning.toString().trim(),
    thinking: thinking,
  );
}

({String text, Map<String, dynamic>? args}) consumeThemeCommand(String text) {
  final match = RegExp(
    r'<modify_ui_state>(.*?)</modify_ui_state>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text);
  if (match == null) {
    return (text: stripThemeCommandMarkup(text), args: null);
  }
  final command = match.group(1)?.trim() ?? '';
  Map<String, dynamic>? args;
  try {
    final decoded = jsonDecode(command);
    if (decoded is Map) args = decoded.cast<String, dynamic>();
  } catch (_) {}
  final cleaned = stripThemeCommandMarkup(text);
  return (text: cleaned, args: args);
}

/// Removes complete and still-streaming theme commands from user-visible text.
///
/// Compatible providers sometimes emit the XML fallback token-by-token. The
/// command is implementation detail and must never flash inside a chat bubble.
String stripThemeCommandMarkup(String text) {
  final withoutComplete = text.replaceAll(
    RegExp(
      r'<modify_ui_state>.*?</modify_ui_state>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  final unfinished = RegExp(
    r'<modify_ui_state(?:>|\s)',
    caseSensitive: false,
  ).firstMatch(withoutComplete);
  var cutoff = unfinished?.start;
  if (cutoff == null) {
    final possibleStart = withoutComplete.lastIndexOf('<');
    if (possibleStart >= 0) {
      final tail = withoutComplete.substring(possibleStart).toLowerCase();
      if ('<modify_ui_state>'.startsWith(tail)) cutoff = possibleStart;
    }
  }
  final visible = cutoff == null
      ? withoutComplete
      : withoutComplete.substring(0, cutoff);
  return visible.trim();
}
