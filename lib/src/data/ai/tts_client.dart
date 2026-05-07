import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

class TtsAudioResult {
  const TtsAudioResult({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class TtsClient {
  const TtsClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<TtsAudioResult> synthesize({
    required TtsProviderConfig config,
    required String text,
    required Duration timeout,
  }) async {
    final input = text.trim();
    if (input.isEmpty) {
      throw Exception('没有可朗读的文本。');
    }
    final baseUrl = config.baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw Exception('请先配置 TTS Base URL。');
    }
    final apiKey = config.apiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('请先配置 TTS API Key。');
    }
    final model = config.model.trim();
    if (model.isEmpty) {
      throw Exception('请先配置 TTS 模型名称。');
    }
    final voice = config.voice.trim();
    if (voice.isEmpty) {
      throw Exception('请先配置 TTS 合成语音。');
    }

    final uri = Uri.parse(_speechEndpoint(baseUrl));
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg, audio/wav, application/octet-stream',
            },
            body: jsonEncode({
              'model': model,
              'input': input,
              'voice': voice,
              'response_format': _responseFormatFor(config),
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}: ${_compactBody(response)}',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw Exception('TTS 服务没有返回音频数据。');
      }
      return TtsAudioResult(
        bytes: response.bodyBytes,
        mimeType: _mimeType(response),
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  String _speechEndpoint(String baseUrl) {
    final trimmed = _trimSlash(baseUrl);
    if (trimmed.endsWith('/audio/speech')) return trimmed;
    return '$trimmed/audio/speech';
  }

  String _responseFormatFor(TtsProviderConfig config) {
    final lower = '${config.type} ${config.baseUrl}'.toLowerCase();
    if (lower.contains('wav')) return 'wav';
    return 'mp3';
  }

  String _mimeType(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final mime = contentType.split(';').first.trim();
    return mime.isEmpty ? 'audio/mpeg' : mime;
  }

  String _compactBody(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('json')) {
      try {
        return jsonEncode(jsonDecode(response.body));
      } catch (_) {
        return response.body;
      }
    }
    return response.body.trim().isEmpty
        ? '请求失败'
        : response.body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _trimSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
