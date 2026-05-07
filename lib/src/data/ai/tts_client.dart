import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

class TtsAudioResult {
  const TtsAudioResult({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

typedef Pcm16ChunkHandler = Future<void> Function(Uint8List chunk);

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

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      if (_isMimoTts(config)) {
        return _synthesizeMimo(
          client: client,
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          voice: voice,
          input: input,
          timeout: timeout,
        );
      }
      return _synthesizeOpenAiCompatible(
        client: client,
        config: config,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        voice: voice,
        input: input,
        timeout: timeout,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<void> streamPcm16({
    required TtsProviderConfig config,
    required String text,
    required Duration timeout,
    required Pcm16ChunkHandler onChunk,
  }) async {
    final input = text.trim();
    if (input.isEmpty) {
      throw Exception('没有可朗读的文本。');
    }
    if (!_isMimoTts(config)) {
      throw Exception('当前 TTS 服务不支持 PCM16 流式播放。');
    }
    final baseUrl = config.baseUrl.trim();
    final apiKey = config.apiKey.trim();
    final model = config.model.trim();
    final voice = config.voice.trim();
    if (baseUrl.isEmpty) throw Exception('请先配置 TTS Base URL。');
    if (apiKey.isEmpty) throw Exception('请先配置 TTS API Key。');
    if (model.isEmpty) throw Exception('请先配置 TTS 模型名称。');
    if (voice.isEmpty) throw Exception('请先配置 TTS 合成语音。');

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      await _streamMimoPcm16(
        client: client,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        voice: voice,
        input: input,
        timeout: timeout,
        onChunk: onChunk,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<TtsAudioResult> _synthesizeOpenAiCompatible({
    required http.Client client,
    required TtsProviderConfig config,
    required String baseUrl,
    required String apiKey,
    required String model,
    required String voice,
    required String input,
    required Duration timeout,
  }) async {
    final response = await client
        .post(
          Uri.parse(_speechEndpoint(baseUrl)),
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
      throw Exception('HTTP ${response.statusCode}: ${_compactBody(response)}');
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('TTS 服务没有返回音频数据。');
    }
    return TtsAudioResult(
      bytes: response.bodyBytes,
      mimeType: _mimeType(response),
    );
  }

  Future<TtsAudioResult> _synthesizeMimo({
    required http.Client client,
    required String baseUrl,
    required String apiKey,
    required String model,
    required String voice,
    required String input,
    required Duration timeout,
  }) async {
    final request =
        http.Request('POST', Uri.parse(_chatCompletionsEndpoint(baseUrl)))
          ..headers.addAll({
            'api-key': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream, application/json',
          })
          ..body = jsonEncode({
            'model': model,
            'messages': [
              {'role': 'assistant', 'content': input},
            ],
            'audio': {'format': 'pcm16', 'voice': voice},
            'stream': true,
          });

    final response = await client.send(request).timeout(timeout);
    final bodyBytes = await response.stream.toBytes().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode}: ${_compactBytesBody(response, bodyBytes)}',
      );
    }
    if (bodyBytes.isEmpty) {
      throw Exception('MiMo TTS 服务没有返回音频数据。');
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().startsWith('audio/')) {
      if (_isWaveBytes(bodyBytes)) {
        return TtsAudioResult(bytes: bodyBytes, mimeType: 'audio/wav');
      }
      return TtsAudioResult(
        bytes: _pcm16ToWav(bodyBytes),
        mimeType: 'audio/wav',
      );
    }

    final pcm = _extractMimoPcmBytes(bodyBytes);
    if (pcm.isEmpty) {
      throw Exception('MiMo TTS 没有返回可播放的音频分片。');
    }
    return TtsAudioResult(bytes: _pcm16ToWav(pcm), mimeType: 'audio/wav');
  }

  Future<void> _streamMimoPcm16({
    required http.Client client,
    required String baseUrl,
    required String apiKey,
    required String model,
    required String voice,
    required String input,
    required Duration timeout,
    required Pcm16ChunkHandler onChunk,
  }) async {
    final request =
        http.Request('POST', Uri.parse(_chatCompletionsEndpoint(baseUrl)))
          ..headers.addAll({
            'api-key': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream, application/json',
          })
          ..body = jsonEncode({
            'model': model,
            'messages': [
              {'role': 'assistant', 'content': input},
            ],
            'audio': {'format': 'pcm16', 'voice': voice},
            'stream': true,
          });

    final response = await client.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyBytes = await response.stream.toBytes().timeout(timeout);
      throw Exception(
        'HTTP ${response.statusCode}: ${_compactBytesBody(response, bodyBytes)}',
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().startsWith('audio/')) {
      final bytes = await response.stream.toBytes().timeout(timeout);
      if (bytes.isEmpty) throw Exception('MiMo TTS 服务没有返回音频数据。');
      await onChunk(_isWaveBytes(bytes) ? _stripWaveHeader(bytes) : bytes);
      return;
    }

    var receivedAudio = false;
    final pending = StringBuffer();
    await for (final chunk in response.stream.timeout(timeout)) {
      pending.write(utf8.decode(chunk, allowMalformed: true));
      final lines = pending.toString().split(RegExp(r'\r?\n'));
      pending
        ..clear()
        ..write(lines.removeLast());
      for (final line in lines) {
        final audio = _extractMimoPcmBytesFromLine(line);
        if (audio.isEmpty) continue;
        receivedAudio = true;
        await onChunk(audio);
      }
    }
    final tail = pending.toString();
    if (tail.trim().isNotEmpty) {
      final audio = _extractMimoPcmBytesFromLine(tail);
      if (audio.isNotEmpty) {
        receivedAudio = true;
        await onChunk(audio);
      }
    }
    if (!receivedAudio) {
      throw Exception('MiMo TTS 没有返回可播放的音频分片。');
    }
  }

  bool _isMimoTts(TtsProviderConfig config) {
    final lower = '${config.type} ${config.name} ${config.baseUrl}'
        .toLowerCase();
    return lower.contains('xiaomi') ||
        lower.contains('mimo') ||
        lower.contains('xiaomimimo');
  }

  String _speechEndpoint(String baseUrl) {
    final trimmed = _trimSlash(baseUrl);
    if (trimmed.endsWith('/audio/speech')) return trimmed;
    return '$trimmed/audio/speech';
  }

  String _chatCompletionsEndpoint(String baseUrl) {
    final trimmed = _trimSlash(baseUrl);
    if (trimmed.endsWith('/chat/completions')) return trimmed;
    return '$trimmed/chat/completions';
  }

  String _responseFormatFor(TtsProviderConfig config) {
    final lower = '${config.type} ${config.baseUrl}'.toLowerCase();
    if (lower.contains('wav')) return 'wav';
    return 'mp3';
  }

  Uint8List _extractMimoPcmBytes(Uint8List bodyBytes) {
    final text = utf8.decode(bodyBytes, allowMalformed: true);
    final audio = BytesBuilder(copy: false);
    var sawSse = false;
    for (final line in const LineSplitter().convert(text)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      sawSse = true;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      try {
        _collectAudioBytes(jsonDecode(data), audio);
      } catch (_) {
        _appendDecodedAudio(data, audio);
      }
    }
    if (!sawSse) {
      try {
        _collectAudioBytes(jsonDecode(text), audio);
      } catch (_) {
        _appendDecodedAudio(text, audio);
      }
    }
    return audio.takeBytes();
  }

  Uint8List _extractMimoPcmBytesFromLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('data:')) return Uint8List(0);
    final data = trimmed.substring(5).trim();
    if (data.isEmpty || data == '[DONE]') return Uint8List(0);
    final audio = BytesBuilder(copy: false);
    try {
      _collectAudioBytes(jsonDecode(data), audio);
    } catch (_) {
      _appendDecodedAudio(data, audio);
    }
    return audio.takeBytes();
  }

  void _collectAudioBytes(
    dynamic value,
    BytesBuilder output, {
    bool inAudio = false,
  }) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final entryValue = entry.value;
        if (key == 'audio') {
          _appendAudioValue(entryValue, output);
          _collectAudioBytes(entryValue, output, inAudio: true);
          continue;
        }
        if (inAudio &&
            const {'data', 'b64_json', 'base64', 'chunk'}.contains(key)) {
          _appendAudioValue(entryValue, output);
          continue;
        }
        _collectAudioBytes(entryValue, output, inAudio: inAudio);
      }
      return;
    }
    if (value is List) {
      if (inAudio && value.every((item) => item is int)) {
        output.add(Uint8List.fromList(value.cast<int>()));
        return;
      }
      for (final item in value) {
        _collectAudioBytes(item, output, inAudio: inAudio);
      }
    }
  }

  void _appendAudioValue(dynamic value, BytesBuilder output) {
    if (value is String) {
      _appendDecodedAudio(value, output);
      return;
    }
    if (value is List && value.every((item) => item is int)) {
      output.add(Uint8List.fromList(value.cast<int>()));
    }
  }

  void _appendDecodedAudio(String value, BytesBuilder output) {
    final decoded = _decodeBase64Audio(value);
    if (decoded != null && decoded.isNotEmpty) output.add(decoded);
  }

  Uint8List? _decodeBase64Audio(String value) {
    var cleaned = value.trim();
    if (cleaned.startsWith('data:audio')) {
      final comma = cleaned.indexOf(',');
      if (comma >= 0) cleaned = cleaned.substring(comma + 1);
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    final missingPadding = cleaned.length % 4;
    if (missingPadding > 0) {
      cleaned = cleaned.padRight(cleaned.length + 4 - missingPadding, '=');
    }
    try {
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  Uint8List _pcm16ToWav(Uint8List pcm) {
    if (_isWaveBytes(pcm)) return pcm;
    const sampleRate = 24000;
    const channels = 1;
    const bitsPerSample = 16;
    const headerSize = 44;
    final result = Uint8List(headerSize + pcm.length);
    final view = ByteData.sublistView(result);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i += 1) {
        result[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    view.setUint32(4, 36 + pcm.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    view.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    view.setUint32(40, pcm.length, Endian.little);
    result.setRange(headerSize, result.length, pcm);
    return result;
  }

  bool _isWaveBytes(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  Uint8List _stripWaveHeader(Uint8List bytes) {
    if (!_isWaveBytes(bytes) || bytes.length <= 44) return bytes;
    return Uint8List.sublistView(bytes, 44);
  }

  String _mimeType(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final mime = contentType.split(';').first.trim();
    return mime.isEmpty ? 'audio/mpeg' : mime;
  }

  String _compactBody(http.Response response) {
    return _compactBytesBody(
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        response.statusCode,
        headers: response.headers,
      ),
      response.bodyBytes,
    );
  }

  String _compactBytesBody(http.StreamedResponse response, Uint8List bytes) {
    final body = utf8.decode(bytes, allowMalformed: true);
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('json')) {
      try {
        return jsonEncode(jsonDecode(body));
      } catch (_) {
        return body;
      }
    }
    return body.trim().isEmpty
        ? '请求失败'
        : body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _trimSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
