import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import 'openai_image_generation_parser.dart';
import 'ai_response_parsers.dart';
import 'chat_message_payloads.dart';
import 'openai_stream_parser.dart';

class GeneratedImageResult {
  const GeneratedImageResult({
    required this.bytes,
    required this.mimeType,
    required this.route,
    this.revisedPrompt,
  });

  final Uint8List bytes;
  final String mimeType;
  final String route;
  final String? revisedPrompt;
}

class OpenAiCompatibleClient {
  const OpenAiCompatibleClient();

  Future<String> generate({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required Duration timeout,
    ValueChanged<Map<String, dynamic>>? onThemeUpdate,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemInstruction},
              for (final message in messages)
                {
                  'role': message.role == 'model' ? 'assistant' : 'user',
                  'content': messageTextWithAttachments(message),
                },
            ],
            'temperature': 0.7,
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List? ?? [];
    if (choices.isEmpty) return '';
    final message = (choices.first as Map)['message'] as Map? ?? {};
    final reasoning =
        message['reasoning_content']?.toString() ??
        message['reasoning']?.toString() ??
        '';
    final content = message['content']?.toString() ?? '';
    final result = consumeThemeCommand(
      reasoning.isEmpty ? content : '<think>$reasoning</think>\n$content',
    );
    if (result.args != null) onThemeUpdate?.call(result.args!);
    return result.text;
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
    final uri = Uri.parse('${_trimSlash(baseUrl)}/chat/completions');
    final client = http.Client();
    var rawContent = '';
    var rawReasoning = '';
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemInstruction},
            for (final message in messages)
              {
                'role': message.role == 'model' ? 'assistant' : 'user',
                'content': messageTextWithAttachments(message),
              },
          ],
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
        final parsedChunk = parseOpenAiStreamData(data);
        final contentDelta = parsedChunk.contentDelta;
        final reasoningDelta = parsedChunk.reasoningDelta;
        if (contentDelta.isEmpty && reasoningDelta.isEmpty) continue;
        rawContent += contentDelta;
        rawReasoning += reasoningDelta;
        final parsed = splitReasoning(rawContent);
        final reasoning = [
          if (rawReasoning.trim().isNotEmpty) rawReasoning.trim(),
          if (parsed.reasoning.trim().isNotEmpty) parsed.reasoning.trim(),
        ].join('\n\n');
        onSnapshot(parsed.answer, reasoning, parsed.thinking);
      }
      if (shouldCancel?.call() == true) return;
      final parsed = splitReasoning(rawContent);
      final reasoning = [
        if (rawReasoning.trim().isNotEmpty) rawReasoning.trim(),
        if (parsed.reasoning.trim().isNotEmpty) parsed.reasoning.trim(),
      ].join('\n\n');
      final result = consumeThemeCommand(parsed.answer);
      if (result.args != null) onThemeUpdate(result.args!);
      onSnapshot(result.text, reasoning, false);
    } finally {
      client.close();
    }
  }

  Future<GeneratedImageResult> generateImage({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required String responseModel,
    required String imageModel,
    required Duration timeout,
    String size = '1024x1024',
  }) async {
    Object? imagesError;
    try {
      return await _generateImageWithImagesRoute(
        apiKey: apiKey,
        baseUrl: baseUrl,
        prompt: prompt,
        imageModel: imageModel,
        timeout: timeout,
        size: size,
      );
    } catch (error) {
      imagesError = error;
      if (!shouldUseResponsesImageTool(imageModel)) {
        throw Exception(
          '生图失败。/v1/images/generations：${_compactError(imagesError)}',
        );
      }
    }

    try {
      return await _generateImageWithResponses(
        apiKey: apiKey,
        baseUrl: baseUrl,
        prompt: prompt,
        responseModel: responseModel,
        imageModel: imageModel,
        timeout: timeout,
        size: size,
      );
    } catch (responsesError) {
      final imagesMessage = _compactError(imagesError);
      final responsesMessage = _compactError(responsesError);
      throw Exception(
        '生图失败。/v1/images/generations：$imagesMessage；Responses API：$responsesMessage',
      );
    }
  }

  Future<GeneratedImageResult> _generateImageWithResponses({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required String responseModel,
    required String imageModel,
    required Duration timeout,
    required String size,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/responses');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'model': responseModel,
            'input': prompt,
            'tools': [
              {
                'type': 'image_generation',
                'model': imageModel,
                'size': size,
                'output_format': 'png',
              },
            ],
            'tool_choice': {'type': 'image_generation'},
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final payload = parseResponsesImageGeneration(jsonDecode(response.body));
    if (!payload.hasImage) {
      throw Exception('Responses API 未返回 image_generation_call 结果。');
    }
    return _imageResultFromPayload(payload, route: '/v1/responses');
  }

  Future<GeneratedImageResult> _generateImageWithImagesRoute({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required String imageModel,
    required Duration timeout,
    required String size,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/images/generations');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'model': imageModel,
            'prompt': prompt,
            'size': size,
            'output_format': 'png',
            'response_format': 'b64_json',
            'n': 1,
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final payload = parseImagesGeneration(jsonDecode(response.body));
    if (!payload.hasImage) {
      throw Exception('/v1/images/generations 未返回图片数据。');
    }
    return _imageResultFromPayload(payload, route: '/v1/images/generations');
  }

  Future<GeneratedImageResult> _imageResultFromPayload(
    ParsedImageGenerationResult payload, {
    required String route,
  }) async {
    final base64Data = payload.base64Data;
    if (base64Data != null && base64Data.trim().isNotEmpty) {
      return GeneratedImageResult(
        bytes: Uint8List.fromList(
          base64Decode(base64Data.replaceAll(RegExp(r'\s+'), '')),
        ),
        mimeType: payload.mimeType,
        route: route,
        revisedPrompt: payload.revisedPrompt,
      );
    }
    final url = payload.url;
    if (url == null || url.trim().isEmpty) {
      throw Exception('图片结果为空。');
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('下载图片失败：HTTP ${response.statusCode}');
    }
    return GeneratedImageResult(
      bytes: response.bodyBytes,
      mimeType:
          response.headers['content-type']?.split(';').first.trim() ??
          payload.mimeType,
      route: route,
      revisedPrompt: payload.revisedPrompt,
    );
  }

  Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/models');
    final response = await http
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    if (response.body.trim().isEmpty) {
      throw Exception('模型接口返回为空，请确认 Base URL 指向兼容 OpenAI 的 /v1 服务。');
    }
    final decoded = jsonDecode(response.body);
    final records = decoded is List
        ? decoded
        : decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is Map && decoded['models'] is List
        ? decoded['models'] as List
        : const [];
    final models = records.map((item) {
      final id = item is Map
          ? (item['id'] ?? item['name'] ?? item).toString()
          : item.toString();
      final name = item is Map ? (item['name'] ?? id).toString() : id;
      return AiModel(
        id: id,
        name: name,
        capabilities: guessModelCapabilities(id, name: name),
      );
    }).toList();
    if (models.isEmpty) {
      throw Exception('模型接口返回为空，请确认 Base URL 指向兼容 OpenAI 的 /v1 服务。');
    }
    return dedupeModels(models);
  }

  Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
    required Duration timeout,
  }) async {
    final start = DateTime.now();
    final text = await generate(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      messages: [ChatMessage.user('hello')],
      systemInstruction: 'Reply with one short word.',
      timeout: timeout,
    );
    final answer = splitReasoning(text).answer;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return '连接成功，模型响应正常：${answer.trim().isEmpty ? 'OK' : answer.trim()}（${elapsed}ms）';
  }

  static String _trimSlash(String value) => app_utils.normalizeBaseUrl(value);

  static String _compactError(Object? error) {
    if (error == null) return '未返回具体错误';
    final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    return text.length > 360 ? '${text.substring(0, 360)}...' : text;
  }
}
