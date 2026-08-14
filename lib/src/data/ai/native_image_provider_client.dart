import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import 'openai_image_client.dart';

class NativeImageProviderClient {
  const NativeImageProviderClient();

  Future<List<GeneratedImageResult>> generate({
    required ImageApiKind kind,
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required Duration timeout,
    required int outputCount,
    List<MessageAttachment> attachments = const [],
    String? aspectRatio,
    String size = '1024x1024',
  }) async {
    final count = clampImageGenerationCount(outputCount);
    return Future.wait([
      for (var index = 0; index < count; index++)
        switch (kind) {
          ImageApiKind.ark => _generateArk(
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
            prompt: prompt,
            attachments: attachments,
            size: size,
            timeout: timeout,
          ),
          ImageApiKind.stability => _generateStability(
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
            prompt: prompt,
            attachments: attachments,
            aspectRatio: aspectRatio,
            timeout: timeout,
          ),
          ImageApiKind.bfl => _generateBfl(
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
            prompt: prompt,
            attachments: attachments,
            size: size,
            aspectRatio: aspectRatio,
            timeout: timeout,
          ),
          ImageApiKind.ideogram => _generateIdeogram(
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
            prompt: prompt,
            attachments: attachments,
            aspectRatio: aspectRatio,
            size: size,
            timeout: timeout,
          ),
          ImageApiKind.replicate => _generateReplicate(
            apiKey: apiKey,
            baseUrl: baseUrl,
            model: model,
            prompt: prompt,
            attachments: attachments,
            aspectRatio: aspectRatio,
            timeout: timeout,
          ),
          _ => throw ArgumentError('Unsupported native image API: $kind'),
        },
    ]);
  }

  Future<GeneratedImageResult> _generateArk({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required List<MessageAttachment> attachments,
    required String size,
    required Duration timeout,
  }) async {
    final base = _trimBase(baseUrl, 'https://ark.cn-beijing.volces.com/api/v3');
    final images = <String>[];
    for (final attachment in attachments.where((item) => item.isImage)) {
      final bytes = await File(attachment.path).readAsBytes();
      final mimeType = attachment.resolvedImageMimeType(headerBytes: bytes);
      images.add('data:$mimeType;base64,${base64Encode(bytes)}');
    }
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'size': size,
      'response_format': 'b64_json',
      'sequential_image_generation': 'disabled',
      'watermark': false,
      if (images.isNotEmpty) 'image': images,
    };
    final response = await http
        .post(
          Uri.parse('$base/images/generations'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    _ensureSuccess(response, '火山方舟');
    final payload = _jsonMap(response.body, '火山方舟');
    final data = payload['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    if (first is! Map) throw Exception('火山方舟未返回图片数据。');
    final encoded = first['b64_json']?.toString().trim() ?? '';
    if (encoded.isNotEmpty) {
      return GeneratedImageResult(
        bytes: Uint8List.fromList(base64Decode(encoded)),
        mimeType: 'image/png',
        route: '/images/generations',
      );
    }
    final url = first['url']?.toString().trim() ?? '';
    if (url.isEmpty) throw Exception('火山方舟未返回图片地址。');
    return _download(url, route: '/images/generations', timeout: timeout);
  }

  Future<GeneratedImageResult> _generateStability({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required List<MessageAttachment> attachments,
    required String? aspectRatio,
    required Duration timeout,
  }) async {
    final endpoint = switch (model.toLowerCase()) {
      'stable-image-ultra' => 'ultra',
      'stable-image-core' => 'core',
      _ => 'sd3',
    };
    final image = attachments.where((item) => item.isImage).firstOrNull;
    if (image != null && endpoint == 'core') {
      throw Exception('Stable Image Core 不接受参考图，请改用 Ultra、SD 3.5 或 FLUX.2。');
    }
    final uri = Uri.parse(
      '${_trimBase(baseUrl, 'https://api.stability.ai')}'
      '/v2beta/stable-image/generate/$endpoint',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] = 'Bearer $apiKey'
      ..headers['accept'] = 'application/json'
      ..fields['prompt'] = prompt
      ..fields['output_format'] = 'png';
    if (image == null && aspectRatio?.trim().isNotEmpty == true) {
      request.fields['aspect_ratio'] = _nearestAspectRatio(aspectRatio, const [
        '1:1',
        '16:9',
        '21:9',
        '2:3',
        '3:2',
        '4:5',
        '5:4',
        '9:16',
        '9:21',
      ]);
    }
    if (endpoint == 'sd3') request.fields['model'] = model;
    if (image == null) {
      request.files.add(http.MultipartFile.fromBytes('none', const []));
    } else {
      final bytes = await File(image.path).readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.path.split(Platform.pathSeparator).last,
        ),
      );
      request.fields['strength'] = '0.72';
      if (endpoint == 'sd3') request.fields['mode'] = 'image-to-image';
    }
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response, 'Stability AI');
    final payload = _jsonMap(response.body, 'Stability AI');
    final encoded = payload['image']?.toString() ?? '';
    if (encoded.isEmpty) throw Exception('Stability AI 未返回图片数据。');
    return GeneratedImageResult(
      bytes: Uint8List.fromList(base64Decode(encoded)),
      mimeType: 'image/png',
      route: '/v2beta/stable-image/generate/$endpoint',
    );
  }

  Future<GeneratedImageResult> _generateBfl({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required List<MessageAttachment> attachments,
    required String size,
    required String? aspectRatio,
    required Duration timeout,
  }) async {
    final base = _trimBase(baseUrl, 'https://api.bfl.ai/v1');
    final dimensions = _dimensions(size);
    final isKontext = model.toLowerCase().contains('kontext');
    final isFlux2 = model.toLowerCase().startsWith('flux-2');
    final body = <String, dynamic>{'prompt': prompt, 'output_format': 'png'};
    if (isKontext) {
      if (aspectRatio?.trim().isNotEmpty == true) {
        body['aspect_ratio'] = aspectRatio!.trim();
      }
    } else {
      body['width'] = dimensions.$1;
      body['height'] = dimensions.$2;
    }
    final images = attachments.where((item) => item.isImage).take(8).toList();
    for (var index = 0; index < images.length; index += 1) {
      final encoded = base64Encode(
        await File(images[index].path).readAsBytes(),
      );
      if (isFlux2 || isKontext) {
        body[index == 0 ? 'input_image' : 'input_image_${index + 1}'] = encoded;
      } else if (index == 0) {
        body['image_prompt'] = encoded;
      }
    }
    final response = await http
        .post(
          Uri.parse('$base/$model'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
            'x-key': apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    _ensureSuccess(response, 'Black Forest Labs');
    final payload = _jsonMap(response.body, 'Black Forest Labs');
    final pollingUrl = payload['polling_url']?.toString().trim() ?? '';
    if (pollingUrl.isEmpty) throw Exception('Black Forest Labs 未返回任务查询地址。');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final poll = await http.get(
        Uri.parse(pollingUrl),
        headers: {'accept': 'application/json', 'x-key': apiKey},
      );
      _ensureSuccess(poll, 'Black Forest Labs');
      final result = _jsonMap(poll.body, 'Black Forest Labs');
      final status = result['status']?.toString().toLowerCase() ?? '';
      if (status == 'ready' || status == 'succeeded') {
        final node = result['result'];
        final url = node is Map ? node['sample']?.toString() : null;
        if (url?.trim().isEmpty != false) {
          throw Exception('Black Forest Labs 任务完成但未返回图片地址。');
        }
        return _download(url!, route: '/$model', timeout: timeout);
      }
      if (status == 'error' || status == 'failed') {
        throw Exception(
          result['error']?.toString() ?? 'Black Forest Labs 生图失败。',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    throw TimeoutException('Black Forest Labs 生图超时。', timeout);
  }

  Future<GeneratedImageResult> _generateIdeogram({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required List<MessageAttachment> attachments,
    required String? aspectRatio,
    required String size,
    required Duration timeout,
  }) async {
    final base = _trimBase(baseUrl, 'https://api.ideogram.ai');
    final isV4 = model.toLowerCase().contains('v4');
    final image = attachments.where((item) => item.isImage).firstOrNull;
    final action = image == null ? 'generate' : 'remix';
    final route = '/v1/$model/$action';
    final request = http.MultipartRequest('POST', Uri.parse('$base$route'))
      ..headers['Api-Key'] = apiKey
      ..fields[isV4 ? 'text_prompt' : 'prompt'] = prompt;
    if (!isV4 && aspectRatio?.trim().isNotEmpty == true) {
      request.fields['aspect_ratio'] = _nearestAspectRatio(aspectRatio, const [
        '1x1',
        '1x3',
        '3x1',
        '1x2',
        '2x1',
        '9x16',
        '16x9',
        '10x16',
        '16x10',
        '2x3',
        '3x2',
        '3x4',
        '4x3',
        '4x5',
        '5x4',
      ], separator: 'x');
    }
    if (isV4 && image == null) {
      request.fields['resolution'] = _ideogramV4Resolution(size);
    }
    if (image != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await File(image.path).readAsBytes(),
          filename: image.path.split(Platform.pathSeparator).last,
        ),
      );
    }
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response, 'Ideogram');
    final payload = _jsonMap(response.body, 'Ideogram');
    final data = payload['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    if (first is! Map) throw Exception('Ideogram 未返回图片数据。');
    final encoded = first['b64_json']?.toString().trim() ?? '';
    if (encoded.isNotEmpty) {
      return GeneratedImageResult(
        bytes: Uint8List.fromList(base64Decode(encoded)),
        mimeType: 'image/png',
        route: route,
      );
    }
    final url = first['url']?.toString().trim() ?? '';
    if (url.isEmpty) throw Exception('Ideogram 未返回图片地址。');
    return _download(url, route: route, timeout: timeout);
  }

  Future<GeneratedImageResult> _generateReplicate({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required List<MessageAttachment> attachments,
    required String? aspectRatio,
    required Duration timeout,
  }) async {
    final parts = model.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length != 2) throw Exception('Replicate 模型 ID 必须为 owner/model。');
    final input = <String, dynamic>{'prompt': prompt};
    if (aspectRatio?.trim().isNotEmpty == true) {
      input['aspect_ratio'] = aspectRatio!.trim();
    }
    final image = attachments.where((item) => item.isImage).firstOrNull;
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final mimeType = image.resolvedImageMimeType(headerBytes: bytes);
      input['image'] = 'data:$mimeType;base64,${base64Encode(bytes)}';
    }
    final base = _trimBase(baseUrl, 'https://api.replicate.com/v1');
    final uri = Uri.parse('$base/models/${parts[0]}/${parts[1]}/predictions');
    var response = await _postReplicate(uri, apiKey, input, timeout);
    if (response.statusCode == 422 && input.containsKey('aspect_ratio')) {
      input.remove('aspect_ratio');
      response = await _postReplicate(uri, apiKey, input, timeout);
    }
    _ensureSuccess(response, 'Replicate');
    var payload = _jsonMap(response.body, 'Replicate');
    final deadline = DateTime.now().add(timeout);
    while (!_replicateFinished(payload) && DateTime.now().isBefore(deadline)) {
      final urls = payload['urls'];
      final getUrl = urls is Map ? urls['get']?.toString().trim() ?? '' : '';
      if (getUrl.isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final poll = await http
          .get(Uri.parse(getUrl), headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(timeout);
      _ensureSuccess(poll, 'Replicate');
      payload = _jsonMap(poll.body, 'Replicate');
    }
    final status = payload['status']?.toString().toLowerCase() ?? '';
    if (status == 'failed' || status == 'canceled') {
      throw Exception(payload['error']?.toString() ?? 'Replicate 生图失败。');
    }
    final urls = _collectUrls(payload['output']);
    if (urls.isEmpty) throw Exception('Replicate 未返回图片地址。');
    return _download(
      urls.first,
      route: '/models/$model/predictions',
      timeout: timeout,
    );
  }

  Future<http.Response> _postReplicate(
    Uri uri,
    String apiKey,
    Map<String, dynamic> input,
    Duration timeout,
  ) {
    return http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Prefer': 'wait=60',
          },
          body: jsonEncode({'input': input}),
        )
        .timeout(timeout);
  }

  Future<GeneratedImageResult> _download(
    String url, {
    required String route,
    required Duration timeout,
  }) async {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    _ensureSuccess(response, '图片下载');
    final contentType = response.headers['content-type']?.split(';').first;
    return GeneratedImageResult(
      bytes: Uint8List.fromList(response.bodyBytes),
      mimeType: contentType?.startsWith('image/') == true
          ? contentType!
          : 'image/png',
      route: route,
    );
  }

  static bool _replicateFinished(Map<String, dynamic> payload) {
    if (_collectUrls(payload['output']).isNotEmpty) return true;
    final status = payload['status']?.toString().toLowerCase() ?? '';
    return status == 'succeeded' || status == 'failed' || status == 'canceled';
  }

  static List<String> _collectUrls(Object? value) {
    final urls = <String>[];
    void visit(Object? node) {
      if (node is String && Uri.tryParse(node)?.hasScheme == true) {
        urls.add(node);
      } else if (node is Iterable) {
        for (final item in node) {
          visit(item);
        }
      } else if (node is Map) {
        visit(node['url']);
        visit(node['urls']);
        visit(node['output']);
      }
    }

    visit(value);
    return urls;
  }

  static (int, int) _dimensions(String size) {
    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(size.trim());
    final width = int.tryParse(match?.group(1) ?? '') ?? 1024;
    final height = int.tryParse(match?.group(2) ?? '') ?? 1024;
    return (width.clamp(256, 2048), height.clamp(256, 2048));
  }

  static String _ideogramV4Resolution(String size) {
    final dimensions = _dimensions(size);
    if (dimensions.$1 > dimensions.$2) return '1536x1024';
    if (dimensions.$1 < dimensions.$2) return '1024x1536';
    return '1024x1024';
  }

  static String _nearestAspectRatio(
    String? value,
    List<String> supported, {
    String separator = ':',
  }) {
    double parse(String ratio) {
      final parts = ratio.split(RegExp(r'[:x×/]'));
      if (parts.length != 2) return 1;
      final width = double.tryParse(parts.first) ?? 1;
      final height = double.tryParse(parts.last) ?? 1;
      return height <= 0 ? 1 : width / height;
    }

    final target = parse(value ?? '1:1');
    var best = supported.first;
    var distance = (parse(best) - target).abs();
    for (final candidate in supported.skip(1)) {
      final candidateDistance = (parse(candidate) - target).abs();
      if (candidateDistance < distance) {
        best = candidate;
        distance = candidateDistance;
      }
    }
    return best.replaceAll(RegExp(r'[:x×/]'), separator);
  }

  static String _trimBase(String value, String fallback) {
    final normalized = app_utils.normalizeBaseUrl(
      value.trim().isEmpty ? fallback : value,
    );
    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }

  static Map<String, dynamic> _jsonMap(String body, String label) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    throw Exception('$label 返回了无法解析的响应。');
  }

  static void _ensureSuccess(http.Response response, String label) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final compact = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    throw Exception(
      '$label 请求失败（${response.statusCode}）'
      '${compact.isEmpty ? '' : '：${compact.length > 260 ? compact.substring(0, 260) : compact}'}',
    );
  }
}
