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
    );

    final decoded = ChatMessage.fromJson(message.toJson());

    expect(message.isImageGenerating, isTrue);
    expect(decoded.isThinking, isFalse);
    expect(decoded.activity, 'imageGeneration');
    expect(decoded.isImageGenerating, isFalse);
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
              mimeType: 'image/png',
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
