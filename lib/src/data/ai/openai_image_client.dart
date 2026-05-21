import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import 'openai_image_generation_parser.dart';

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

class OpenAiImageClient {
  const OpenAiImageClient();

  Future<GeneratedImageResult> generateImage({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    List<MessageAttachment> attachments = const [],
    required String responseModel,
    required String imageModel,
    required Duration timeout,
    String size = '1024x1024',
  }) async {
    final imageAttachments = attachments
        .where((attachment) => attachment.isImage)
        .toList();
    final primaryImageRoute = imageAttachments.isNotEmpty
        ? '/v1/images/edits'
        : '/v1/images/generations';
    final supportsResponsesImageTool = shouldUseResponsesImageTool(imageModel);

    final preferResponsesFirst =
        imageAttachments.isEmpty &&
        supportsResponsesImageTool &&
        _shouldPreferResponsesImageStream(imageModel);
    var triedResponsesFirst = false;
    Object? responsesError;
    if (preferResponsesFirst) {
      triedResponsesFirst = true;
      try {
        return await _generateImageWithResponses(
          apiKey: apiKey,
          baseUrl: baseUrl,
          prompt: prompt,
          imageAttachments: imageAttachments,
          responseModel: responseModel,
          imageModel: imageModel,
          timeout: timeout,
          size: size,
        );
      } catch (error) {
        responsesError = error;
      }
    }

    if (imageAttachments.isNotEmpty && supportsResponsesImageTool) {
      try {
        return await _generateImageWithResponses(
          apiKey: apiKey,
          baseUrl: baseUrl,
          prompt: prompt,
          imageAttachments: imageAttachments,
          responseModel: responseModel,
          imageModel: imageModel,
          timeout: timeout,
          size: size,
        );
      } catch (error) {
        responsesError = error;
      }

      try {
        return await _generateImageWithImageEditsRoute(
          apiKey: apiKey,
          baseUrl: baseUrl,
          prompt: prompt,
          imageModel: imageModel,
          imageAttachments: imageAttachments,
          timeout: timeout,
          size: size,
        );
      } catch (imagesError) {
        throw Exception(
          '生图失败。Responses API：${_compactError(responsesError)}；'
          '$primaryImageRoute：${_compactError(imagesError)}',
        );
      }
    }

    Object? imagesError;
    try {
      if (imageAttachments.isNotEmpty) {
        return await _generateImageWithImageEditsRoute(
          apiKey: apiKey,
          baseUrl: baseUrl,
          prompt: prompt,
          imageModel: imageModel,
          imageAttachments: imageAttachments,
          timeout: timeout,
          size: size,
        );
      } else {
        return await _generateImageWithImagesRoute(
          apiKey: apiKey,
          baseUrl: baseUrl,
          prompt: prompt,
          imageModel: imageModel,
          timeout: timeout,
          size: size,
        );
      }
    } catch (error) {
      imagesError = error;
      if (!supportsResponsesImageTool) {
        throw Exception(
          '生图失败。$primaryImageRoute：${_compactError(imagesError)}',
        );
      }
    }

    try {
      if (triedResponsesFirst) {
        throw responsesError ?? Exception('Responses API 生图失败。');
      }
      return await _generateImageWithResponses(
        apiKey: apiKey,
        baseUrl: baseUrl,
        prompt: prompt,
        imageAttachments: imageAttachments,
        responseModel: responseModel,
        imageModel: imageModel,
        timeout: timeout,
        size: size,
      );
    } catch (responsesError) {
      final imagesMessage = _compactError(imagesError);
      final responsesMessage = _compactError(responsesError);
      throw Exception(
        '生图失败。$primaryImageRoute：$imagesMessage；Responses API：$responsesMessage',
      );
    }
  }

  Future<String> testImageConnection({
    required String apiKey,
    required String baseUrl,
    required String imageModel,
    required String responseModel,
    required Duration timeout,
  }) async {
    final start = DateTime.now();
    final result = await generateImage(
      apiKey: apiKey,
      baseUrl: baseUrl,
      prompt: 'Generate a tiny clean app test image: one mint dot on white.',
      imageModel: imageModel,
      responseModel: responseModel,
      timeout: timeout,
      size: '1024x1024',
    );
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return '连接成功，生图接口响应正常：${result.route}（${elapsed}ms）';
  }

  // ── Responses API ──────────────────────────────────────────────

  Future<GeneratedImageResult> _generateImageWithResponses({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required List<MessageAttachment> imageAttachments,
    required String responseModel,
    required String imageModel,
    required Duration timeout,
    required String size,
  }) async {
    final uri = Uri.parse('${app_utils.normalizeBaseUrl(baseUrl)}/responses');
    final inputImages = await _responsesInputImages(imageAttachments);

    Object? streamError;
    try {
      final payload = await _postResponsesImageGenerationStream(
        uri: uri,
        apiKey: apiKey,
        responseModel: responseModel,
        imageModel: imageModel,
        prompt: prompt,
        inputImages: inputImages,
        size: size,
        timeout: timeout,
        requireToolChoice: true,
      );
      return _imageResultFromPayload(
        payload,
        route: '/v1/responses?stream=true',
        timeout: timeout,
      );
    } on _ResponsesToolChoiceCompatibilityException {
      try {
        final payload = await _postResponsesImageGenerationStream(
          uri: uri,
          apiKey: apiKey,
          responseModel: responseModel,
          imageModel: imageModel,
          prompt: prompt,
          inputImages: inputImages,
          size: size,
          timeout: timeout,
          requireToolChoice: false,
        );
        return _imageResultFromPayload(
          payload,
          route: '/v1/responses?stream=true',
          timeout: timeout,
        );
      } catch (error) {
        streamError = error;
      }
    } catch (error) {
      streamError = error;
    }

    try {
      var response = await _postResponsesImageGeneration(
        uri: uri,
        apiKey: apiKey,
        responseModel: responseModel,
        imageModel: imageModel,
        prompt: prompt,
        inputImages: inputImages,
        size: size,
        timeout: timeout,
        requireToolChoice: true,
      );
      if (_isResponsesToolChoiceCompatibilityError(response) ||
          (response.statusCode >= 200 &&
              response.statusCode < 300 &&
              !parseResponsesImageGeneration(
                jsonDecode(response.body),
              ).hasImage)) {
        response = await _postResponsesImageGeneration(
          uri: uri,
          apiKey: apiKey,
          responseModel: responseModel,
          imageModel: imageModel,
          prompt: prompt,
          inputImages: inputImages,
          size: size,
          timeout: timeout,
          requireToolChoice: false,
        );
      }
      _throwIfRetryableImageStatus(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final payload = parseResponsesImageGeneration(jsonDecode(response.body));
      if (!payload.hasImage) {
        throw Exception('Responses API 未返回 image_generation_call 结果。');
      }
      return _imageResultFromPayload(
        payload,
        route: '/v1/responses',
        timeout: timeout,
      );
    } catch (error) {
      throw Exception(
        'Responses API stream：${_compactError(streamError)}；'
        'Responses API：${_compactError(error)}',
      );
    }
  }

  Future<http.Response> _postResponsesImageGeneration({
    required Uri uri,
    required String apiKey,
    required String responseModel,
    required String imageModel,
    required String prompt,
    required List<Map<String, dynamic>> inputImages,
    required String size,
    required Duration timeout,
    required bool requireToolChoice,
  }) {
    final effectivePrompt =
        '''
Use the following text as the complete prompt. Do not rewrite it:
$prompt
'''
            .trim();
    final input = inputImages.isEmpty
        ? effectivePrompt
        : [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': effectivePrompt},
                ...inputImages,
              ],
            },
          ];
    final body = <String, dynamic>{
      'model': responseModel,
      'input': input,
      'tools': [
        {
          'type': 'image_generation',
          'model': imageModel,
          'action': inputImages.isEmpty ? 'generate' : 'edit',
          'size': size,
          'output_format': 'png',
        },
      ],
    };
    if (requireToolChoice) {
      body['tool_choice'] = {'type': 'image_generation'};
    }
    return http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  Future<ParsedImageGenerationResult> _postResponsesImageGenerationStream({
    required Uri uri,
    required String apiKey,
    required String responseModel,
    required String imageModel,
    required String prompt,
    required List<Map<String, dynamic>> inputImages,
    required String size,
    required Duration timeout,
    required bool requireToolChoice,
  }) async {
    final effectivePrompt =
        '''
Use the following text as the complete prompt. Do not rewrite it:
$prompt
'''
            .trim();
    final input = inputImages.isEmpty
        ? effectivePrompt
        : [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': effectivePrompt},
                ...inputImages,
              ],
            },
          ];
    final body = <String, dynamic>{
      'model': responseModel,
      'input': input,
      'stream': true,
      'tools': [
        {
          'type': 'image_generation',
          'model': imageModel,
          'action': inputImages.isEmpty ? 'generate' : 'edit',
          'size': size,
          'output_format': 'png',
          'partial_images': 3,
        },
      ],
    };
    if (requireToolChoice) {
      body['tool_choice'] = {'type': 'image_generation'};
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream, application/json',
        })
        ..body = jsonEncode(body);
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final responseBody = await response.stream.bytesToString().timeout(
          timeout,
        );
        final buffered = http.Response(responseBody, response.statusCode);
        if (_isResponsesToolChoiceCompatibilityError(buffered)) {
          throw _ResponsesToolChoiceCompatibilityException(responseBody);
        }
        _throwIfRetryableImageStatus(buffered);
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('text/event-stream')) {
        final responseBody = await response.stream.bytesToString().timeout(
          timeout,
        );
        final payload = parseResponsesImageGeneration(jsonDecode(responseBody));
        if (!payload.hasImage) {
          throw Exception('Responses API stream 未返回 image_generation_call 结果。');
        }
        return payload;
      }

      return await _readResponsesImageGenerationStream(response, timeout);
    } finally {
      client.close();
    }
  }

  Future<ParsedImageGenerationResult> _readResponsesImageGenerationStream(
    http.StreamedResponse response,
    Duration timeout,
  ) async {
    var eventName = '';
    final dataLines = <String>[];
    ParsedImageGenerationResult? lastPartial;

    ParsedImageGenerationResult? processEvent() {
      if (dataLines.isEmpty) return null;
      final data = dataLines.join('\n').trim();
      dataLines.clear();
      if (data.isEmpty || data == '[DONE]') return null;

      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['error'] != null) {
        final error = decoded['error'];
        final message = error is Map ? error['message'] : error;
        throw Exception(message?.toString() ?? 'Responses API stream 返回错误。');
      }

      final type = decoded is Map ? decoded['type']?.toString() ?? '' : '';
      final event = eventName;
      eventName = '';
      if (type.contains('partial_image') || event.contains('partial_image')) {
        if (decoded is Map) {
          final partial = decoded['partial_image_b64']?.toString().trim();
          if (partial != null && partial.isNotEmpty) {
            lastPartial = ParsedImageGenerationResult(
              base64Data: partial,
              mimeType: _mimeTypeFromOutputFormat(
                decoded['output_format']?.toString(),
              ),
            );
          }
        }
        return null;
      }
      if (type == 'response.completed' || event == 'response.completed') {
        final responseNode = decoded is Map && decoded['response'] != null
            ? decoded['response']
            : decoded;
        final payload = parseResponsesImageGeneration(responseNode);
        if (payload.hasImage) return payload;
      }
      if (type == 'response.failed' || event == 'response.failed') {
        final responseNode = decoded is Map ? decoded['response'] : null;
        final error = responseNode is Map ? responseNode['error'] : null;
        final message = error is Map ? error['message'] : error;
        throw Exception(message?.toString() ?? 'Responses API stream 失败。');
      }
      return null;
    }

    try {
      await for (final line
          in response.stream
              .timeout(timeout)
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          final payload = processEvent();
          if (payload != null) return payload;
          continue;
        }
        if (line.startsWith('event:')) {
          eventName = line.substring('event:'.length).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring('data:'.length).trimLeft());
        }
      }

      final payload = processEvent();
      if (payload != null) return payload;
      if (lastPartial != null && lastPartial!.hasImage) return lastPartial!;
      throw Exception('Responses API stream 未返回 image_generation_call 结果。');
    } catch (error) {
      if (lastPartial != null && lastPartial!.hasImage) return lastPartial!;
      rethrow;
    }
  }

  // ── /v1/images/generations ─────────────────────────────────────

  Future<GeneratedImageResult> _generateImageWithImagesRoute({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required String imageModel,
    required Duration timeout,
    required String size,
  }) async {
    final uri = Uri.parse(
      '${app_utils.normalizeBaseUrl(baseUrl)}/images/generations',
    );
    Object? directError;
    try {
      final payload = await _postImagesGeneration(
        uri: uri,
        apiKey: apiKey,
        prompt: prompt,
        imageModel: imageModel,
        timeout: timeout,
        size: size,
        retryTransient: false,
      );
      return _imageResultFromPayload(
        payload,
        route: '/v1/images/generations',
        timeout: timeout,
      );
    } catch (error) {
      directError = error;
      if (!_isTransientImageError(error, retryTimeouts: true)) {
        rethrow;
      }
    }

    try {
      final payload = await _postImagesGenerationStream(
        uri: uri,
        apiKey: apiKey,
        prompt: prompt,
        imageModel: imageModel,
        timeout: timeout,
        size: size,
      );
      return _imageResultFromPayload(
        payload,
        route: '/v1/images/generations?stream=true',
        timeout: timeout,
      );
    } catch (streamError) {
      throw Exception(
        '非流式请求：${_compactError(directError)}；'
        '流式请求：${_compactError(streamError)}',
      );
    }
  }

  Future<ParsedImageGenerationResult> _postImagesGeneration({
    required Uri uri,
    required String apiKey,
    required String prompt,
    required String imageModel,
    required Duration timeout,
    required String size,
    bool retryTransient = true,
  }) {
    Future<ParsedImageGenerationResult> operation() async {
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
      _throwIfRetryableImageStatus(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final payload = parseImagesGeneration(jsonDecode(response.body));
      if (!payload.hasImage) {
        throw Exception('/v1/images/generations 未返回图片数据。');
      }
      return payload;
    }

    return retryTransient ? _withTransientImageRetry(operation) : operation();
  }

  Future<ParsedImageGenerationResult> _postImagesGenerationStream({
    required Uri uri,
    required String apiKey,
    required String prompt,
    required String imageModel,
    required Duration timeout,
    required String size,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream, application/json',
        })
        ..body = jsonEncode({
          'model': imageModel,
          'prompt': prompt,
          'size': size,
          'output_format': 'png',
          'response_format': 'b64_json',
          'n': 1,
          'stream': true,
        });
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString().timeout(timeout);
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('text/event-stream')) {
        final body = await response.stream.bytesToString().timeout(timeout);
        final payload = parseImagesGeneration(jsonDecode(body));
        if (!payload.hasImage) {
          throw Exception('/v1/images/generations stream 未返回图片数据。');
        }
        return payload;
      }

      return await _readImagesGenerationStream(response, timeout);
    } finally {
      client.close();
    }
  }

  Future<ParsedImageGenerationResult> _readImagesGenerationStream(
    http.StreamedResponse response,
    Duration timeout,
  ) async {
    var eventName = '';
    final dataLines = <String>[];

    ParsedImageGenerationResult? processEvent() {
      if (dataLines.isEmpty) return null;
      final data = dataLines.join('\n').trim();
      dataLines.clear();
      if (data.isEmpty || data == '[DONE]') return null;

      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['error'] != null) {
        final error = decoded['error'];
        final message = error is Map ? error['message'] : error;
        throw Exception(message?.toString() ?? '流式生图返回错误。');
      }

      final type = decoded is Map ? decoded['type']?.toString() ?? '' : '';
      final event = eventName;
      eventName = '';
      if (type.contains('partial_image') || event.contains('partial_image')) {
        return null;
      }
      if (type.contains('completed') || event.contains('completed')) {
        final payload = parseImagesGeneration(decoded);
        if (payload.hasImage) return payload;
      }
      return null;
    }

    await for (final line
        in response.stream
            .timeout(timeout)
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        final payload = processEvent();
        if (payload != null) return payload;
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }

    final payload = processEvent();
    if (payload != null) return payload;
    throw Exception('/v1/images/generations stream 未返回完成图片。');
  }

  // ── /v1/images/edits ──────────────────────────────────────────

  Future<GeneratedImageResult> _generateImageWithImageEditsRoute({
    required String apiKey,
    required String baseUrl,
    required String prompt,
    required String imageModel,
    required List<MessageAttachment> imageAttachments,
    required Duration timeout,
    required String size,
  }) async {
    final payload = await _withTransientImageRetry(() async {
      final uri = Uri.parse(
        '${app_utils.normalizeBaseUrl(baseUrl)}/images/edits',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        })
        ..fields.addAll({
          'model': imageModel,
          'prompt': prompt,
          'size': size,
          'output_format': 'png',
          'response_format': 'b64_json',
          'n': '1',
        });

      var attachedCount = 0;
      for (final attachment in imageAttachments) {
        final file = File(attachment.path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final mimeType = attachment.resolvedImageMimeType(headerBytes: bytes);
        request.files.add(
          http.MultipartFile.fromBytes(
            'image[]',
            bytes,
            filename: attachment.name,
            contentType: MediaType.parse(mimeType),
          ),
        );
        attachedCount += 1;
      }
      if (attachedCount == 0) {
        throw Exception('没有可读取的参考图片。');
      }

      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      _throwIfRetryableImageStatus(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final payload = parseImagesGeneration(jsonDecode(response.body));
      if (!payload.hasImage) {
        throw Exception('/v1/images/edits 未返回图片数据。');
      }
      return payload;
    });
    return _imageResultFromPayload(
      payload,
      route: '/v1/images/edits',
      timeout: timeout,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _responsesInputImages(
    List<MessageAttachment> imageAttachments,
  ) async {
    final parts = <Map<String, dynamic>>[];
    for (final attachment in imageAttachments) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final mimeType = attachment.resolvedImageMimeType(headerBytes: bytes);
      parts.add({
        'type': 'input_image',
        'image_url': 'data:$mimeType;base64,${base64Encode(bytes)}',
      });
    }
    return parts;
  }

  Future<GeneratedImageResult> _imageResultFromPayload(
    ParsedImageGenerationResult payload, {
    required String route,
    required Duration timeout,
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
    final response = await _withTransientImageRetry(() async {
      final response = await http.get(Uri.parse(url)).timeout(timeout);
      _throwIfRetryableImageStatus(response);
      return response;
    }, retryTimeouts: true);
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

  static String _mimeTypeFromOutputFormat(String? outputFormat) {
    switch (outputFormat?.trim().toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  static Future<T> _withTransientImageRetry<T>(
    Future<T> Function() operation, {
    bool retryTimeouts = false,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        if (attempt == 1 ||
            !_isTransientImageError(error, retryTimeouts: retryTimeouts)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
    }
    throw lastError ?? Exception('生图请求失败。');
  }

  static void _throwIfRetryableImageStatus(http.Response response) {
    if (response.statusCode == 408 ||
        response.statusCode == 500 ||
        response.statusCode == 502 ||
        response.statusCode == 503 ||
        response.statusCode == 504) {
      throw _RetryableImageException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }

  static bool _isResponsesToolChoiceCompatibilityError(http.Response response) {
    if (response.statusCode < 400) return false;
    final text = response.body.toLowerCase();
    final mentionsToolChoice =
        text.contains('tool_choice') || text.contains('tool choice');
    return mentionsToolChoice &&
        (text.contains('not found') ||
            text.contains('must be specified') ||
            text.contains('not supported') ||
            text.contains('unsupported') ||
            text.contains('invalid'));
  }

  static bool _isTransientImageError(
    Object error, {
    required bool retryTimeouts,
  }) {
    if (error is _RetryableImageException ||
        error is SocketException ||
        error is HandshakeException ||
        error is HttpException ||
        error is http.ClientException) {
      return true;
    }
    if (retryTimeouts && error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('connection closed') ||
        text.contains('connection reset') ||
        text.contains('context canceled') ||
        text.contains('failed host lookup') ||
        text.contains('request timeout') ||
        text.contains('network is unreachable') ||
        text.contains('temporarily unavailable') ||
        text.contains('upstream_error') ||
        text.contains('http 408') ||
        text.contains('http 500') ||
        text.contains('http 502') ||
        text.contains('http 503') ||
        text.contains('http 504');
  }

  static String _compactError(Object? error) {
    if (error == null) return '未返回具体错误';
    final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    return text.length > 1200 ? '${text.substring(0, 1200)}...' : text;
  }

  static bool _shouldPreferResponsesImageStream(String imageModel) {
    final text = imageModel.toLowerCase().trim();
    return text == 'gpt-image-2';
  }
}

class _RetryableImageException implements Exception {
  const _RetryableImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ResponsesToolChoiceCompatibilityException implements Exception {
  const _ResponsesToolChoiceCompatibilityException(this.message);

  final String message;

  @override
  String toString() => message;
}
