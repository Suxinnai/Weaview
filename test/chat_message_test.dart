import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/chat_message_payloads.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('chat message persists image generation activity state', () {
    final message = ChatMessage.model(
      '',
      isThinking: true,
      activity: 'imageGeneration',
      imageCount: 6,
    );

    final decoded = ChatMessage.fromJson(message.toJson());

    expect(message.isImageGenerating, isTrue);
    expect(decoded.isThinking, isFalse);
    expect(decoded.activity, 'imageGeneration');
    expect(decoded.imageCount, 6);
    expect(decoded.isImageGenerating, isFalse);
  });

  test('chat message clamps legacy image counts to the supported range', () {
    final decoded = ChatMessage.fromJson({
      'role': 'model',
      'content': '',
      'imageCount': 99,
    });

    expect(decoded.imageCount, maxImageGenerationCount);
  });

  test('image attachment persists pixel dimensions without touching bytes', () {
    const attachment = MessageAttachment(
      path: '/images/generated.png',
      name: 'generated.png',
      mimeType: 'image/png',
      kind: 'image',
      size: 4096,
      pixelWidth: 2048,
      pixelHeight: 1152,
    );

    final restored = MessageAttachment.fromJson(attachment.toJson());

    expect(restored.hasPixelSize, isTrue);
    expect(restored.pixelWidth, 2048);
    expect(restored.pixelHeight, 1152);
  });

  test('OpenAI payload carries user image attachments as image parts', () async {
    final image = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}weaview_payload_test.png',
    );
    await image.writeAsBytes(base64Decode('iVBORw0KGgo='));
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });

    final payload = await openAiMessagesWithAttachments(
      systemInstruction: 'system',
      messages: [
        ChatMessage.user(
          '看这张图',
          attachments: [
            MessageAttachment(
              path: image.path,
              name: 'test.png',
              mimeType: 'application/octet-stream',
              kind: 'image',
              size: image.lengthSync(),
            ),
          ],
        ),
      ],
    );

    final content = payload.last['content'];
    expect(content, isA<List<Map<String, dynamic>>>());
    final parts = content as List<Map<String, dynamic>>;
    expect(parts.first['type'], 'text');
    expect(parts.last['type'], 'image_url');
    expect(
      (parts.last['image_url'] as Map<String, dynamic>)['url'],
      startsWith('data:image/png;base64,'),
    );
  });
}
