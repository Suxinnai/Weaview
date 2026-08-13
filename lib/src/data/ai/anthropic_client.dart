import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import 'ai_response_parsers.dart';
import 'chat_message_payloads.dart';

class AnthropicClient {
  const AnthropicClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<String> generate({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required Duration timeout,
    ValueChanged<Map<String, dynamic>>? onThemeUpdate,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/messages');
    final requestMessages = await _anthropicMessages(messages);
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': requestMessages,
              'system': systemInstruction,
              'max_tokens': 4096,
              'temperature': 0.7,
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List? ?? [];
      if (content.isEmpty) return '';
      final textBlock = content.firstWhere(
        (block) => block['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return '';
      final text = textBlock['text']?.toString() ?? '';
      final result = consumeThemeCommand(text);
      if (result.args != null) onThemeUpdate?.call(result.args!);
      return result.text;
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<void> generateStream({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required void Function(String content, String reasoning, bool thinking)
    onSnapshot,
    required Duration timeout,
    bool Function()? shouldCancel,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/messages');
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    var rawContent = '';
    try {
      final requestMessages = await _anthropicMessages(messages);
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'model': model,
          'messages': requestMessages,
          'system': systemInstruction,
          'max_tokens': 4096,
          'temperature': 0.7,
          'stream': true,
        });
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (shouldCancel?.call() == true) break;
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') break;

        final parsed = _parseStreamEvent(data);
        if (parsed == null) continue;
        if (parsed.type == 'content_block_delta') {
          rawContent += parsed.text;
          final split = splitReasoning(rawContent);
          onSnapshot(split.answer, split.reasoning, split.thinking);
        }
      }

      if (shouldCancel?.call() == true) return;
      final result = consumeThemeCommand(rawContent);
      if (result.args != null) onThemeUpdate(result.args!);
      final split = splitReasoning(result.text);
      onSnapshot(split.answer, split.reasoning, false);
    } finally {
      if (ownsClient) client.close();
    }
  }

  _StreamEvent? _parseStreamEvent(String data) {
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final type = decoded['type']?.toString() ?? '';
      if (type == 'content_block_delta') {
        final delta = decoded['delta'] as Map? ?? {};
        final text = delta['text']?.toString() ?? '';
        return _StreamEvent(type: type, text: text);
      }
      if (type == 'message_stop') {
        return _StreamEvent(type: type, text: '');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _anthropicMessages(
    List<ChatMessage> messages,
  ) async {
    final result = <Map<String, dynamic>>[];
    final latestUserIndex = messages.lastIndexWhere(
      (message) => message.role != 'model',
    );
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final content = await _anthropicMessageContent(
        message,
        requireAvailableAttachments: index == latestUserIndex,
      );
      result.add({
        'role': message.role == 'model' ? 'assistant' : 'user',
        'content': content,
      });
    }
    return result;
  }

  Future<Object> _anthropicMessageContent(
    ChatMessage message, {
    required bool requireAvailableAttachments,
  }) async {
    final imageAttachments = message.role == 'user'
        ? message.attachments.where((a) => a.isImage).toList()
        : const <MessageAttachment>[];
    if (imageAttachments.isEmpty) {
      return messageTextWithAttachments(
        message,
        requireAvailableAttachments: requireAvailableAttachments,
      );
    }

    final parts = <Map<String, dynamic>>[];
    final text = await messageTextWithAttachments(
      message,
      requireAvailableAttachments: requireAvailableAttachments,
    );
    if (text.trim().isNotEmpty) {
      parts.add({'type': 'text', 'text': text});
    }
    for (final attachment in imageAttachments) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final mimeType = attachment.resolvedImageMimeType(headerBytes: bytes);
      parts.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': base64Encode(bytes),
        },
      });
    }
    return parts.isEmpty ? text : parts;
  }

  static String _trimSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}

class _StreamEvent {
  const _StreamEvent({required this.type, required this.text});
  final String type;
  final String text;
}
