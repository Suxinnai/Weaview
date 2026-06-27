import 'dart:convert';
import 'dart:io';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import 'attachment_text_extractor.dart';

Future<List<Map<String, dynamic>>> geminiContents(
  List<ChatMessage> messages,
) async {
  final contents = <Map<String, dynamic>>[];
  final latestUserIndex = messages.lastIndexWhere(
    (message) => message.role != 'model',
  );
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final parts = <Map<String, dynamic>>[];
    final text = await messageTextWithAttachments(
      message,
      requireAvailableAttachments: index == latestUserIndex,
    );
    if (text.trim().isNotEmpty) {
      parts.add({'text': text});
    }
    for (final attachment in message.attachments) {
      if (!attachment.isImage) continue;
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      parts.add({
        'inlineData': {
          'mimeType': attachment.mimeType,
          'data': base64Encode(bytes),
        },
      });
    }
    contents.add({
      'role': message.role == 'model' ? 'model' : 'user',
      'parts': parts.isEmpty
          ? [
              {'text': message.content},
            ]
          : parts,
    });
  }
  return contents;
}

Future<String> messageTextWithAttachments(
  ChatMessage message, {
  bool requireAvailableAttachments = true,
}) async {
  if (message.attachments.isEmpty) return message.content;
  final buffer = StringBuffer(message.content);
  if (buffer.isNotEmpty) buffer.write('\n\n');
  buffer.writeln('[附件内容已由客户端读取]');
  buffer.writeln('请直接基于下方内容回答，不要声称稍后读取文件。');
  for (final attachment in message.attachments) {
    buffer.writeln(
      '- ${attachment.name} (${attachment.mimeType}, ${app_utils.formatBytes(attachment.size ?? 0)})',
    );
    try {
      final extracted = await extractAttachmentText(attachment);
      if (extracted != null) {
        buffer.writeln(
          '<attachment_content name="${_escapeAttribute(attachment.name)}" truncated="${extracted.truncated}">',
        );
        buffer.writeln(extracted.text);
        buffer.writeln('</attachment_content>');
        if (extracted.truncated) {
          buffer.writeln('[说明：文件较长，已提供开头和结尾的可读节选。回答时应明确说明结论基于节选。]');
        }
      }
    } on AttachmentPayloadException catch (error) {
      if (requireAvailableAttachments) rethrow;
      buffer.writeln('[历史附件当前不可读：${error.message}]');
    }
  }
  return buffer.toString();
}

Future<List<Map<String, dynamic>>> openAiMessagesWithAttachments({
  required String systemInstruction,
  required List<ChatMessage> messages,
}) async {
  final result = <Map<String, dynamic>>[
    {'role': 'system', 'content': systemInstruction},
  ];
  final latestUserIndex = messages.lastIndexWhere(
    (message) => message.role != 'model',
  );
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    result.add({
      'role': message.role == 'model' ? 'assistant' : 'user',
      'content': await openAiMessageContent(
        message,
        requireAvailableAttachments: index == latestUserIndex,
      ),
    });
  }
  return result;
}

Future<Object> openAiMessageContent(
  ChatMessage message, {
  bool requireAvailableAttachments = true,
}) async {
  final imageAttachments = message.role == 'user'
      ? message.attachments.where((attachment) => attachment.isImage).toList()
      : const <MessageAttachment>[];
  final text = await messageTextWithAttachments(
    message,
    requireAvailableAttachments: requireAvailableAttachments,
  );
  if (imageAttachments.isEmpty) return text;

  final parts = <Map<String, dynamic>>[];
  if (text.trim().isNotEmpty) {
    parts.add({'type': 'text', 'text': text});
  }
  for (final attachment in imageAttachments) {
    final file = File(attachment.path);
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    final mimeType = attachment.resolvedImageMimeType(headerBytes: bytes);
    parts.add({
      'type': 'image_url',
      'image_url': {'url': 'data:$mimeType;base64,${base64Encode(bytes)}'},
    });
  }
  return parts.isEmpty ? text : parts;
}

String _escapeAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
