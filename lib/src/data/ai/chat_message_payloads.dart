import 'dart:convert';
import 'dart:io';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';

Future<List<Map<String, dynamic>>> geminiContents(
  List<ChatMessage> messages,
) async {
  final contents = <Map<String, dynamic>>[];
  for (final message in messages) {
    final parts = <Map<String, dynamic>>[];
    final text = messageTextWithAttachments(message);
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

String messageTextWithAttachments(ChatMessage message) {
  if (message.attachments.isEmpty) return message.content;
  final buffer = StringBuffer(message.content);
  if (buffer.isNotEmpty) buffer.write('\n\n');
  buffer.writeln('[用户上传的附件]');
  for (final attachment in message.attachments) {
    buffer.writeln(
      '- ${attachment.name} (${attachment.mimeType}, ${app_utils.formatBytes(attachment.size ?? 0)})',
    );
    if (!attachment.isImage) {
      final file = File(attachment.path);
      if (file.existsSync() && (attachment.size ?? 0) <= 128 * 1024) {
        final text = tryReadTextFile(file);
        if (text != null && text.trim().isNotEmpty) {
          buffer.writeln('```');
          buffer.writeln(text.length > 6000 ? text.substring(0, 6000) : text);
          buffer.writeln('```');
        }
      }
    }
  }
  return buffer.toString();
}

Future<List<Map<String, dynamic>>> openAiMessagesWithAttachments({
  required String systemInstruction,
  required List<ChatMessage> messages,
}) async {
  return [
    {'role': 'system', 'content': systemInstruction},
    for (final message in messages)
      {
        'role': message.role == 'model' ? 'assistant' : 'user',
        'content': await openAiMessageContent(message),
      },
  ];
}

Future<Object> openAiMessageContent(ChatMessage message) async {
  final imageAttachments = message.role == 'user'
      ? message.attachments.where((attachment) => attachment.isImage).toList()
      : const <MessageAttachment>[];
  if (imageAttachments.isEmpty) return messageTextWithAttachments(message);

  final parts = <Map<String, dynamic>>[];
  final text = messageTextWithAttachments(message);
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
  return parts.isEmpty ? messageTextWithAttachments(message) : parts;
}

String? tryReadTextFile(File file) {
  try {
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}
