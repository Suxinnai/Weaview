import 'package:flutter/foundation.dart';

import '../../domain/models.dart';
import 'openai_chat_client.dart';
import 'openai_image_client.dart';

export 'openai_image_client.dart' show GeneratedImageResult;

class OpenAiCompatibleClient {
  const OpenAiCompatibleClient();

  static const _chat = OpenAiChatClient();
  static const _image = OpenAiImageClient();

  Future<String> generate({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required Duration timeout,
    ValueChanged<Map<String, dynamic>>? onThemeUpdate,
  }) => _chat.generate(
    apiKey: apiKey,
    baseUrl: baseUrl,
    model: model,
    messages: messages,
    systemInstruction: systemInstruction,
    timeout: timeout,
    onThemeUpdate: onThemeUpdate,
  );

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
  }) => _chat.generateStream(
    apiKey: apiKey,
    baseUrl: baseUrl,
    model: model,
    messages: messages,
    systemInstruction: systemInstruction,
    onThemeUpdate: onThemeUpdate,
    onSnapshot: onSnapshot,
    timeout: timeout,
    shouldCancel: shouldCancel,
  );

  Future<GeneratedImageResult> generateImage({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    List<MessageAttachment> attachments = const [],
    required String responseModel,
    required String imageModel,
    required Duration timeout,
    String size = '1024x1024',
    Map<String, dynamic> imageRequestExtraBody = const {},
    bool includeImageSize = true,
  }) => _image.generateImage(
    apiKey: apiKey,
    baseUrl: baseUrl,
    prompt: prompt,
    attachments: attachments,
    responseModel: responseModel,
    imageModel: imageModel,
    timeout: timeout,
    size: size,
    imageRequestExtraBody: imageRequestExtraBody,
    includeImageSize: includeImageSize,
  );

  Future<List<GeneratedImageResult>> generateChatImages({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    List<MessageAttachment> attachments = const [],
    required Duration timeout,
    int outputCount = 1,
    String? aspectRatio,
    String? imageSize,
  }) => _image.generateChatImages(
    apiKey: apiKey,
    baseUrl: baseUrl,
    model: model,
    prompt: prompt,
    attachments: attachments,
    timeout: timeout,
    outputCount: outputCount,
    aspectRatio: aspectRatio,
    imageSize: imageSize,
  );

  Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
    required Duration timeout,
  }) => _chat.fetchModels(apiKey: apiKey, baseUrl: baseUrl, timeout: timeout);

  Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
    required Duration timeout,
  }) => _chat.testConnection(
    apiKey: apiKey,
    baseUrl: baseUrl,
    model: model,
    timeout: timeout,
  );

  Future<String> testImageConnection({
    required String apiKey,
    required String baseUrl,
    required String imageModel,
    required String responseModel,
    required Duration timeout,
  }) => _image.testImageConnection(
    apiKey: apiKey,
    baseUrl: baseUrl,
    imageModel: imageModel,
    responseModel: responseModel,
    timeout: timeout,
  );

  Future<String> testChatImageConnection({
    required String apiKey,
    required String baseUrl,
    required String imageModel,
    required Duration timeout,
  }) => _image.testChatImageConnection(
    apiKey: apiKey,
    baseUrl: baseUrl,
    imageModel: imageModel,
    timeout: timeout,
  );
}
