import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import 'chat_message_payloads.dart';
import 'openai_compatible_client.dart';

class GeminiClient {
  const GeminiClient();

  Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
    required Duration timeout,
  }) async {
    final uri = _nativeGeminiUri(baseUrl: baseUrl, resourcePath: '/models');
    final response = await http
        .get(
          uri,
          headers: {'Accept': 'application/json', 'x-goog-api-key': apiKey},
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini models HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final remote = <AiModel>[];
    for (final record in decoded['models'] as List? ?? const []) {
      if (record is! Map) continue;
      final rawName = record['name']?.toString() ?? '';
      final id = _normalizeGeminiModel(rawName);
      if (id.isEmpty) continue;
      remote.add(
        AiModel(
          id: id,
          name: record['displayName']?.toString().trim().isNotEmpty == true
              ? record['displayName'].toString()
              : id,
          capabilities: modelCapabilitiesFromRecord({
            ...record.cast<String, dynamic>(),
            'id': id,
          }),
        ),
      );
    }
    return dedupeModels(withGeminiImageModels(remote));
  }

  Future<String> testImageConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
    required Duration timeout,
  }) async {
    final started = DateTime.now();
    final result = await generateImage(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      prompt: 'Generate a tiny clean app test image: one mint dot on white.',
      timeout: timeout,
    );
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    return '连接成功，Gemini 原生生图接口响应正常：${result.route}（${elapsed}ms）';
  }

  Future<String> generate({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required Duration timeout,
  }) async {
    final contents = await geminiContents(messages);
    final first = await _callGemini(
      apiKey: apiKey,
      model: model,
      contents: contents,
      systemInstruction: systemInstruction,
      includeTools: true,
      timeout: timeout,
    );
    for (final call in first.functionCalls) {
      if (call['name'] == 'modify_ui_state') {
        final args = (call['args'] as Map?)?.cast<String, dynamic>() ?? {};
        onThemeUpdate(args);
      }
    }

    if (first.functionCalls.isEmpty) return first.text;

    final secondContents = [
      ...contents,
      {
        'role': 'model',
        'parts': [
          for (final call in first.functionCalls) {'functionCall': call},
        ],
      },
      {
        'role': 'user',
        'parts': [
          for (final call in first.functionCalls)
            {
              'functionResponse': {
                'name': call['name'],
                'response': {'success': true},
              },
            },
        ],
      },
    ];
    final second = await _callGemini(
      apiKey: apiKey,
      model: model,
      contents: secondContents,
      systemInstruction: systemInstruction,
      includeTools: false,
      timeout: timeout,
    );
    return second.text.isNotEmpty ? second.text : first.text;
  }

  Future<_GeminiResult> _callGemini({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    required bool includeTools,
    required Duration timeout,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${_normalizeGeminiModel(model)}:generateContent',
      {'key': apiKey},
    );
    final payload = <String, dynamic>{
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'generationConfig': {'temperature': 0.7},
      if (includeTools) 'tools': [_themeTool()],
    };
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? [];
    final parts = candidates.isEmpty
        ? const []
        : ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ??
              const [];
    final text = StringBuffer();
    final functionCalls = <Map<String, dynamic>>[];
    for (final part in parts) {
      final map = part as Map;
      if (map['text'] != null) {
        text.write(map['text']);
      }
      if (map['functionCall'] != null) {
        functionCalls.add((map['functionCall'] as Map).cast<String, dynamic>());
      }
    }
    return _GeminiResult(text: text.toString(), functionCalls: functionCalls);
  }

  Future<GeneratedImageResult> generateImage({
    required String apiKey,
    required String model,
    required String prompt,
    required Duration timeout,
    List<MessageAttachment> attachments = const [],
    String baseUrl = '',
    String? aspectRatio,
    String? imageSize,
  }) async {
    final results = await generateImages(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeout: timeout,
      attachments: attachments,
      baseUrl: baseUrl,
      aspectRatio: aspectRatio,
      imageSize: imageSize,
    );
    return results.first;
  }

  Future<List<GeneratedImageResult>> generateImages({
    required String apiKey,
    required String model,
    required String prompt,
    required Duration timeout,
    List<MessageAttachment> attachments = const [],
    String baseUrl = '',
    int outputCount = 1,
    String? aspectRatio,
    String? imageSize,
  }) async {
    final requestedCount = outputCount.clamp(1, 4).toInt();
    final first = await _requestImages(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeout: timeout,
      attachments: attachments,
      baseUrl: baseUrl,
      aspectRatio: aspectRatio,
      imageSize: imageSize,
    );
    if (first.length >= requestedCount) {
      return first.take(requestedCount).toList();
    }

    final remaining = requestedCount - first.length;
    final attempts = await Future.wait([
      for (var index = 0; index < remaining; index++)
        _requestImages(
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          timeout: timeout,
          attachments: attachments,
          baseUrl: baseUrl,
          aspectRatio: aspectRatio,
          imageSize: imageSize,
        ).then(
          (images) => _GeminiImageAttempt(images: images),
          onError: (Object error, StackTrace _) => const _GeminiImageAttempt(),
        ),
    ]);
    final images = [
      ...first,
      for (final attempt in attempts) ...attempt.images,
    ];
    return images.take(requestedCount).toList();
  }

  Future<List<GeneratedImageResult>> _requestImages({
    required String apiKey,
    required String model,
    required String prompt,
    required Duration timeout,
    required List<MessageAttachment> attachments,
    required String baseUrl,
    String? aspectRatio,
    String? imageSize,
  }) async {
    final uri = _generateContentUri(baseUrl: baseUrl, model: model);
    final imageParts = <Map<String, dynamic>>[];
    for (final attachment in attachments.where((item) => item.isImage)) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      imageParts.add({
        'inlineData': {
          'mimeType': attachment.resolvedImageMimeType(headerBytes: bytes),
          'data': base64Encode(bytes),
        },
      });
    }
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                  ...imageParts,
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['TEXT', 'IMAGE'],
              if (aspectRatio != null || imageSize != null)
                'responseFormat': {
                  'image': {
                    'aspectRatio': ?aspectRatio,
                    'imageSize': ?imageSize,
                  },
                },
            },
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini image HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final parsed = _parseGeminiImageResponse(jsonDecode(response.body));
    if (parsed.isEmpty) {
      throw Exception(
        'Gemini image response did not include inline image data.',
      );
    }
    return [
      for (final image in parsed)
        GeneratedImageResult(
          bytes: image.bytes,
          mimeType: image.mimeType,
          route:
              '/v1beta/models/${_normalizeGeminiModel(model)}:generateContent',
          revisedPrompt: image.text.trim().isEmpty ? null : image.text.trim(),
        ),
    ];
  }

  static Uri _generateContentUri({
    required String baseUrl,
    required String model,
  }) {
    return _nativeGeminiUri(
      baseUrl: baseUrl,
      resourcePath: '/models/${_normalizeGeminiModel(model)}:generateContent',
    );
  }

  static Uri _nativeGeminiUri({
    required String baseUrl,
    required String resourcePath,
  }) {
    final base = Uri.parse(
      baseUrl.trim().isEmpty
          ? 'https://generativelanguage.googleapis.com'
          : baseUrl.trim(),
    );
    var apiPath = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (apiPath.endsWith('/openai')) {
      apiPath = apiPath.substring(0, apiPath.length - '/openai'.length);
    }
    if (!RegExp(r'/v\d').hasMatch(apiPath)) {
      apiPath = '$apiPath/v1beta';
    }
    return base.replace(
      path: '$apiPath$resourcePath',
      queryParameters: base.queryParameters.isEmpty
          ? null
          : base.queryParameters,
    );
  }

  static List<_GeminiImagePayload> _parseGeminiImageResponse(dynamic decoded) {
    final map = decoded as Map<String, dynamic>;
    final candidates = map['candidates'] as List? ?? [];
    final images = <_GeminiImagePayload>[];
    final text = StringBuffer();
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final parts =
          (candidate['content'] as Map?)?['parts'] as List? ?? const [];
      for (final part in parts) {
        if (part is! Map || part['thought'] == true) continue;
        final textPart = part['text']?.toString();
        if (textPart != null) text.write(textPart);
        final inlineData = part['inlineData'] ?? part['inline_data'];
        if (inlineData is! Map) continue;
        final data = inlineData['data']?.toString();
        if (data == null || data.trim().isEmpty) continue;
        final mimeType =
            inlineData['mimeType']?.toString() ??
            inlineData['mime_type']?.toString() ??
            'image/png';
        images.add(
          _GeminiImagePayload(
            bytes: Uint8List.fromList(
              base64Decode(data.replaceAll(RegExp(r'\s+'), '')),
            ),
            mimeType: mimeType,
            text: text.toString(),
          ),
        );
      }
    }
    return images;
  }

  static String _normalizeGeminiModel(String model) {
    return model.startsWith('models/') ? model.substring(7) : model;
  }

  static Map<String, dynamic> _themeTool() {
    return {
      'functionDeclarations': [
        {
          'name': 'modify_ui_state',
          'description':
              'Safely modifies supported chat appearance controls only. Keep groups independent: backgroundColor/isDark for background style, textColor/fontFamily/fontStyle/fontWeight for font and text style, bubbleStyle/bubble colors/bubble opacity for message bubble style, and messageAlignment for alignment. Do not use this for unsupported app layout, settings pages, navigation, spacing systems, or arbitrary CSS.',
          'parameters': {
            'type': 'object',
            'properties': {
              'resetTheme': {
                'type': 'boolean',
                'description':
                    'Set true only when the user asks to restore, reset, or return to the default theme.',
              },
              'backgroundColor': {
                'type': 'string',
                'description':
                    'CSS hex color for the chat background/canvas only. Do not set this for bubble-only or font-only requests. For open-ended background requests, choose quiet, poetic, low-saturation colors that fit Weaview; avoid pure red, neon, high-saturation, or aggressively bright backgrounds unless explicitly requested.',
              },
              'textColor': {
                'type': 'string',
                'description':
                    'CSS hex color for readable message text only. Do not set this for bubble-only or background-only requests unless the user asks for text color too.',
              },
              'fontFamily': {
                'type': 'string',
                'enum': ['sans', 'serif'],
                'description': 'Font family for message text only.',
              },
              'fontStyle': {
                'type': 'string',
                'enum': ['normal', 'italic'],
                'description': 'Font style for message text only.',
              },
              'fontWeight': {
                'type': 'string',
                'enum': ['normal', 'medium', 'bold'],
                'description': 'Font weight for message text only.',
              },
              'messageAlignment': {
                'type': 'string',
                'enum': ['left', 'center', 'right'],
                'description': 'Message alignment only.',
              },
              'bubbleStyle': {
                'type': 'string',
                'enum': ['minimal', 'none', 'glass', 'solid', 'outline'],
                'description':
                    'Message bubble container style only. Use none to remove visible message bubbles, glass for transparent bubbles, solid for stronger filled bubbles, outline for border-only bubbles. Never change the background when removing bubbles.',
              },
              'bubbleColor': {
                'type': 'string',
                'description':
                    'CSS hex color applied to both assistant and user bubble containers only.',
              },
              'assistantBubbleColor': {
                'type': 'string',
                'description':
                    'CSS hex color for assistant bubble containers only.',
              },
              'userBubbleColor': {
                'type': 'string',
                'description': 'CSS hex color for user bubble containers only.',
              },
              'bubbleOpacity': {
                'type': 'number',
                'description':
                    'Opacity from 0 to 1 applied to both assistant and user bubbles.',
              },
              'assistantBubbleOpacity': {
                'type': 'number',
                'description': 'Assistant bubble opacity from 0 to 1.',
              },
              'userBubbleOpacity': {
                'type': 'number',
                'description': 'User bubble opacity from 0 to 1.',
              },
              'isDark': {'type': 'boolean'},
            },
          },
        },
      ],
    };
  }
}

class _GeminiImagePayload {
  const _GeminiImagePayload({
    required this.bytes,
    required this.mimeType,
    required this.text,
  });

  final Uint8List bytes;
  final String mimeType;
  final String text;
}

class _GeminiImageAttempt {
  const _GeminiImageAttempt({this.images = const []});

  final List<GeneratedImageResult> images;
}

class _GeminiResult {
  const _GeminiResult({required this.text, required this.functionCalls});

  final String text;
  final List<Map<String, dynamic>> functionCalls;
}
