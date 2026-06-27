import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/attachment_text_extractor.dart';
import 'package:weaview_flutter/src/data/ai/chat_message_payloads.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('weaview-attachment-');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'embeds useful head and tail content for text files over 128 KiB',
    () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}novel.txt');
      final body = [
        '开头标记：冬野夜空',
        List.filled(40000, '这是正文段落。').join(),
        '结尾标记：故事结束',
      ].join('\n');
      await file.writeAsString(body);
      expect(await file.length(), greaterThan(128 * 1024));

      final payload = await openAiMessagesWithAttachments(
        systemInstruction: 'system',
        messages: [
          ChatMessage.user(
            '这是讲的什么？',
            attachments: [
              MessageAttachment(
                path: file.path,
                name: 'novel.txt',
                mimeType: 'text/plain',
                kind: 'file',
                size: await file.length(),
              ),
            ],
          ),
        ],
      );

      final content = payload.last['content'] as String;
      expect(content, contains('附件内容已由客户端读取'));
      expect(content, contains('开头标记：冬野夜空'));
      expect(content, contains('结尾标记：故事结束'));
      expect(content, contains('truncated="true"'));
      expect(content, contains('不要声称稍后读取文件'));
    },
  );

  test(
    'surfaces a missing current attachment as an actionable error',
    () async {
      final missing = MessageAttachment(
        path: '${tempDir.path}${Platform.pathSeparator}missing.txt',
        name: 'missing.txt',
        mimeType: 'text/plain',
        kind: 'file',
        size: 12,
      );

      await expectLater(
        openAiMessageContent(ChatMessage.user('总结', attachments: [missing])),
        throwsA(
          isA<AttachmentPayloadException>().having(
            (error) => error.message,
            'message',
            contains('重新选择'),
          ),
        ),
      );
    },
  );

  test(
    'does not let an expired historical attachment block a new prompt',
    () async {
      final current = File(
        '${tempDir.path}${Platform.pathSeparator}current.md',
      );
      await current.writeAsString('# 当前文件');
      final payload = await openAiMessagesWithAttachments(
        systemInstruction: 'system',
        messages: [
          ChatMessage.user(
            '旧消息',
            attachments: [
              MessageAttachment(
                path: '${tempDir.path}${Platform.pathSeparator}gone.txt',
                name: 'gone.txt',
                mimeType: 'text/plain',
                kind: 'file',
              ),
            ],
          ),
          ChatMessage.model('旧回答'),
          ChatMessage.user(
            '新问题',
            attachments: [
              MessageAttachment(
                path: current.path,
                name: 'current.md',
                mimeType: 'text/markdown',
                kind: 'file',
                size: await current.length(),
              ),
            ],
          ),
        ],
      );

      expect(payload[1]['content'], contains('历史附件当前不可读'));
      expect(payload.last['content'], contains('# 当前文件'));
    },
  );

  test(
    'rejects unsupported binary documents instead of sending metadata only',
    () async {
      final pdf = File('${tempDir.path}${Platform.pathSeparator}report.pdf');
      await pdf.writeAsBytes(utf8.encode('%PDF-1.7 fake payload'));
      final attachment = MessageAttachment(
        path: pdf.path,
        name: 'report.pdf',
        mimeType: 'application/pdf',
        kind: 'file',
        size: await pdf.length(),
      );

      await expectLater(
        extractAttachmentText(attachment),
        throwsA(
          isA<AttachmentPayloadException>().having(
            (error) => error.message,
            'message',
            contains('TXT/Markdown'),
          ),
        ),
      );
    },
  );
}
