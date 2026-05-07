import 'package:flutter_test/flutter_test.dart';
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
}
