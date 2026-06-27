import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/message_attachment.dart';
import 'package:weaview_flutter/src/features/chat/attachment_limits.dart';

void main() {
  MessageAttachment attachment(String name, int size) => MessageAttachment(
    path: '/tmp/$name',
    name: name,
    mimeType: 'text/plain',
    kind: 'file',
    size: size,
  );

  test('accepts files at or below the 10MB upload limit', () {
    final result = applyChatAttachmentLimits(
      existingCount: 0,
      incoming: [
        attachment('small.txt', 1),
        attachment('limit.txt', maxChatAttachmentBytes),
      ],
    );

    expect(result.accepted.map((item) => item.name), [
      'small.txt',
      'limit.txt',
    ]);
    expect(result.rejectedOversized, isEmpty);
    expect(result.rejectedOverflow, isEmpty);
  });

  test('rejects files over the 10MB upload limit', () {
    final result = applyChatAttachmentLimits(
      existingCount: 0,
      incoming: [
        attachment('too-large.txt', maxChatAttachmentBytes + 1),
        attachment('ok.txt', 1024),
      ],
    );

    expect(result.accepted.map((item) => item.name), ['ok.txt']);
    expect(result.rejectedOversized.map((item) => item.name), [
      'too-large.txt',
    ]);
    expect(result.message, contains('超过 10MB'));
  });

  test('caps total uploaded attachments at eight files', () {
    final result = applyChatAttachmentLimits(
      existingCount: 6,
      incoming: List.generate(
        4,
        (index) => attachment('file-$index.txt', 1024),
      ),
    );

    expect(result.accepted.map((item) => item.name), [
      'file-0.txt',
      'file-1.txt',
    ]);
    expect(result.rejectedOverflow.map((item) => item.name), [
      'file-2.txt',
      'file-3.txt',
    ]);
    expect(result.message, contains('最多上传 8 个文件'));
  });
}
