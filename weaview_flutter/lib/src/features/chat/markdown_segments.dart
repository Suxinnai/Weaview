enum MarkdownSegmentKind { markdown, code, formula }

class MarkdownSegment {
  const MarkdownSegment({
    required this.kind,
    required this.text,
    this.language = '',
  });

  final MarkdownSegmentKind kind;
  final String text;
  final String language;
}

List<MarkdownSegment> splitMarkdownSegments(String source) {
  final segments = <MarkdownSegment>[];
  final codeFence = RegExp(r'```([^\r\n`]*)\r?\n([\s\S]*?)```');
  var cursor = 0;
  for (final match in codeFence.allMatches(source)) {
    _addMarkdownAndFormulaSegments(
      segments,
      source.substring(cursor, match.start),
    );
    segments.add(
      MarkdownSegment(
        kind: MarkdownSegmentKind.code,
        language: match.group(1)?.trim() ?? '',
        text: (match.group(2) ?? '').replaceFirst(RegExp(r'\r?\n$'), ''),
      ),
    );
    cursor = match.end;
  }
  _addMarkdownAndFormulaSegments(segments, source.substring(cursor));
  if (segments.isEmpty) {
    segments.add(
      const MarkdownSegment(kind: MarkdownSegmentKind.markdown, text: ' '),
    );
  }
  return segments;
}

void _addMarkdownAndFormulaSegments(
  List<MarkdownSegment> segments,
  String source,
) {
  if (source.isEmpty) return;
  final formulaBlock = RegExp(r'\$\$([\s\S]*?)\$\$');
  var cursor = 0;
  for (final match in formulaBlock.allMatches(source)) {
    final markdown = source.substring(cursor, match.start);
    if (markdown.trim().isNotEmpty) {
      segments.add(
        MarkdownSegment(kind: MarkdownSegmentKind.markdown, text: markdown),
      );
    }
    final formula = match.group(1)?.trim() ?? '';
    if (formula.isNotEmpty) {
      segments.add(
        MarkdownSegment(kind: MarkdownSegmentKind.formula, text: formula),
      );
    }
    cursor = match.end;
  }
  final tail = source.substring(cursor);
  if (tail.trim().isNotEmpty || segments.isEmpty) {
    segments.add(
      MarkdownSegment(
        kind: MarkdownSegmentKind.markdown,
        text: tail.trim().isEmpty ? ' ' : tail,
      ),
    );
  }
}
