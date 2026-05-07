import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/features/chat/markdown_segments.dart';

void main() {
  group('markdown segments', () {
    test('keeps plain markdown as one segment', () {
      final segments = splitMarkdownSegments('hello **world**');

      expect(segments, hasLength(1));
      expect(segments.single.kind, MarkdownSegmentKind.markdown);
      expect(segments.single.text, 'hello **world**');
    });

    test('extracts fenced code blocks with language labels', () {
      final segments = splitMarkdownSegments(
        'before\n```dart\nprint(1);\n```\nafter',
      );

      expect(segments.map((segment) => segment.kind), [
        MarkdownSegmentKind.markdown,
        MarkdownSegmentKind.code,
        MarkdownSegmentKind.markdown,
      ]);
      expect(segments[1].language, 'dart');
      expect(segments[1].text, 'print(1);');
    });

    test('extracts formula blocks outside code fences', () {
      final segments = splitMarkdownSegments('A\n\$\$x^2 + y^2\$\$\nB');

      expect(segments.map((segment) => segment.kind), [
        MarkdownSegmentKind.markdown,
        MarkdownSegmentKind.formula,
        MarkdownSegmentKind.markdown,
      ]);
      expect(segments[1].text, 'x^2 + y^2');
    });
  });
}
