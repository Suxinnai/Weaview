part of '../main.dart';

typedef AiStreamSnapshotHandler =
    void Function(String content, String reasoning, bool thinking);

const _searchRequestTimeout = Duration(seconds: 30);
const _chatRequestTimeout = Duration(seconds: 180);
const _roleRequestTimeout = Duration(seconds: 75);
const _modelFetchTimeout = Duration(seconds: 45);

class AiGateway {
  static Future<String> generate({
    required List<ChatMessage> messages,
    required String systemInstruction,
    required AiProvider provider,
    required ModelAssignment assignment,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
  }) async {
    final providerName = assignment.provider.isNotEmpty
        ? assignment.provider
        : provider.name;
    if (providerName.toLowerCase().contains('gemini')) {
      final key = provider.apiKey.isNotEmpty ? provider.apiKey : _geminiApiKey;
      if (key.isEmpty) {
        return '请先在「设置 > 提供商 > Gemini」中配置 Gemini API Key，或用 `--dart-define=GEMINI_API_KEY=...` 启动应用。';
      }
      return _generateGemini(
        apiKey: key,
        model: _geminiModelId(assignment, provider),
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
      );
    }

    final apiKey = provider.apiKey;
    if (apiKey.isEmpty) {
      return '请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。';
    }
    return _generateOpenAiCompatible(
      apiKey: apiKey,
      baseUrl: provider.baseUrl.isEmpty
          ? 'https://api.openai.com/v1'
          : provider.baseUrl,
      model: _providerModelId(assignment, provider),
      messages: messages,
      systemInstruction: systemInstruction,
      onThemeUpdate: onThemeUpdate,
    );
  }

  static Future<void> generateStream({
    required List<ChatMessage> messages,
    required String systemInstruction,
    required AiProvider provider,
    required ModelAssignment assignment,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required AiStreamSnapshotHandler onSnapshot,
  }) async {
    final providerName = assignment.provider.isNotEmpty
        ? assignment.provider
        : provider.name;
    if (providerName.toLowerCase().contains('gemini')) {
      final text = await generate(
        messages: messages,
        systemInstruction: systemInstruction,
        provider: provider,
        assignment: assignment,
        onThemeUpdate: onThemeUpdate,
      );
      final parsed = _splitReasoning(text);
      onSnapshot(parsed.answer, parsed.reasoning, false);
      return;
    }

    final apiKey = provider.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。');
    }
    await _generateOpenAiCompatibleStream(
      apiKey: apiKey,
      baseUrl: provider.baseUrl.isEmpty
          ? 'https://api.openai.com/v1'
          : provider.baseUrl,
      model: _providerModelId(assignment, provider),
      messages: messages,
      systemInstruction: systemInstruction,
      onThemeUpdate: onThemeUpdate,
      onSnapshot: onSnapshot,
    );
  }

  static Future<String> searchWeb({
    required SearchConfig config,
    required String query,
  }) async {
    final key = config.keys[config.active]?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception('请先配置 ${config.active} 搜索服务的 API Key。');
    }
    if (config.active != 'tavily') {
      throw Exception('当前版本已接入 Tavily 搜索，请切换到 Tavily 后使用联网搜索。');
    }
    final response = await http
        .post(
          Uri.parse('https://api.tavily.com/search'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': key,
            'query': query,
            'search_depth': 'advanced',
            'include_answer': true,
            'include_raw_content': false,
            'max_results': 5,
          }),
        )
        .timeout(_searchRequestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Tavily HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final buffer = StringBuffer();
    final answer = decoded['answer']?.toString().trim() ?? '';
    if (answer.isNotEmpty) {
      buffer.writeln('Summary: $answer');
      buffer.writeln();
    }
    final results = decoded['results'] as List? ?? const [];
    for (final result in results.take(5)) {
      if (result is! Map) continue;
      final title = result['title']?.toString().trim() ?? 'Untitled';
      final url = result['url']?.toString().trim() ?? '';
      final content = result['content']?.toString().trim() ?? '';
      buffer.writeln('- $title');
      if (url.isNotEmpty) buffer.writeln('  URL: $url');
      if (content.isNotEmpty) buffer.writeln('  Snippet: $content');
    }
    return buffer.toString().trim();
  }

  static Future<String> generateRoleText({
    required AiProvider provider,
    required ModelAssignment assignment,
    required String input,
  }) async {
    final text = await generate(
      messages: [ChatMessage.user(input)],
      systemInstruction: assignment.prompt,
      provider: provider,
      assignment: assignment,
      onThemeUpdate: (_) {},
    );
    return _splitReasoning(text).answer.trim();
  }

  static Future<String> _generateGemini({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
  }) async {
    final contents = await _geminiContents(messages);
    final first = await _callGemini(
      apiKey: apiKey,
      model: model,
      contents: contents,
      systemInstruction: systemInstruction,
      includeTools: true,
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
    );
    return second.text.isNotEmpty ? second.text : first.text;
  }

  static Future<_GeminiResult> _callGemini({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    required bool includeTools,
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
        .timeout(_chatRequestTimeout);
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

  static Future<String> _generateOpenAiCompatible({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
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
                  'content': _messageTextWithAttachments(message),
                },
            ],
            'temperature': 0.7,
          }),
        )
        .timeout(_chatRequestTimeout);
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
    final result = _consumeThemeCommand(
      reasoning.isEmpty ? content : '<think>$reasoning</think>\n$content',
    );
    if (result.args != null) onThemeUpdate?.call(result.args!);
    return result.text;
  }

  static Future<void> _generateOpenAiCompatibleStream({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required AiStreamSnapshotHandler onSnapshot,
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
                'content': _messageTextWithAttachments(message),
              },
          ],
          'temperature': 0.7,
          'stream': true,
        });
      final response = await client.send(request).timeout(_chatRequestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
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
        final parsed = _splitReasoning(rawContent);
        final reasoning = [
          if (rawReasoning.trim().isNotEmpty) rawReasoning.trim(),
          if (parsed.reasoning.trim().isNotEmpty) parsed.reasoning.trim(),
        ].join('\n\n');
        onSnapshot(parsed.answer, reasoning, parsed.thinking);
      }
      final parsed = _splitReasoning(rawContent);
      final reasoning = [
        if (rawReasoning.trim().isNotEmpty) rawReasoning.trim(),
        if (parsed.reasoning.trim().isNotEmpty) parsed.reasoning.trim(),
      ].join('\n\n');
      final result = _consumeThemeCommand(parsed.answer);
      if (result.args != null) onThemeUpdate(result.args!);
      onSnapshot(result.text, reasoning, false);
    } finally {
      client.close();
    }
  }

  static Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
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
        .timeout(_modelFetchTimeout);
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
      return AiModel(id: id, name: name, capabilities: _guessCaps(id));
    }).toList();
    if (models.isEmpty) {
      throw Exception('模型接口返回为空，请确认 Base URL 指向兼容 OpenAI 的 /v1 服务。');
    }
    return models;
  }

  static Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    final start = DateTime.now();
    final text = await _generateOpenAiCompatible(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      messages: [ChatMessage.user('hello')],
      systemInstruction: 'Reply with one short word.',
    );
    final answer = _splitReasoning(text).answer;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return '连接成功，模型响应正常：${answer.trim().isEmpty ? 'OK' : answer.trim()}（${elapsed}ms）';
  }

  static String _geminiModelId(
    ModelAssignment assignment,
    AiProvider provider,
  ) {
    if (assignment.model.isNotEmpty) {
      final matched = provider.models.firstWhereOrNull(
        (m) => m.name == assignment.model || m.id == assignment.model,
      );
      if (matched != null) return matched.id;
    }
    return 'gemini-2.5-pro';
  }

  static String _providerModelId(
    ModelAssignment assignment,
    AiProvider provider,
  ) {
    if (assignment.model.isNotEmpty) {
      final matched = provider.models.firstWhereOrNull(
        (m) => m.name == assignment.model || m.id == assignment.model,
      );
      return matched?.id ?? assignment.model;
    }
    return provider.models.isNotEmpty
        ? provider.models.first.id
        : 'gpt-4o-mini';
  }

  static ({String contentDelta, String reasoningDelta}) parseOpenAiStreamData(
    String data,
  ) {
    final decoded = jsonDecode(data);
    if (decoded is! Map) return (contentDelta: '', reasoningDelta: '');
    final choices = decoded['choices'] as List? ?? const [];
    if (choices.isEmpty) return (contentDelta: '', reasoningDelta: '');
    final first = choices.first;
    if (first is! Map) return (contentDelta: '', reasoningDelta: '');
    final delta = first['delta'] as Map? ?? const {};
    return (
      contentDelta: delta['content']?.toString() ?? '',
      reasoningDelta:
          delta['reasoning_content']?.toString() ??
          delta['reasoning']?.toString() ??
          '',
    );
  }

  static ({String text, Map<String, dynamic>? args}) _consumeThemeCommand(
    String text,
  ) {
    final match = RegExp(
      r'<modify_ui_state>(.*?)</modify_ui_state>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (match == null) return (text: text, args: null);
    final command = match.group(1)?.trim() ?? '';
    Map<String, dynamic>? args;
    try {
      final decoded = jsonDecode(command);
      if (decoded is Map) args = decoded.cast<String, dynamic>();
    } catch (_) {}
    final cleaned = text.replaceRange(match.start, match.end, '').trim();
    return (text: cleaned, args: args);
  }

  static String _normalizeGeminiModel(String model) {
    return model.startsWith('models/') ? model.substring(7) : model;
  }

  static Future<List<Map<String, dynamic>>> _geminiContents(
    List<ChatMessage> messages,
  ) async {
    final contents = <Map<String, dynamic>>[];
    for (final message in messages) {
      final parts = <Map<String, dynamic>>[];
      final text = _messageTextWithAttachments(message);
      if (text.trim().isNotEmpty) {
        parts.add({'text': text});
      }
      for (final attachment in message.attachments) {
        if (!attachment.isImage) continue;
        final file = File(attachment.path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        parts.add({
          'inlineData': {
            'mimeType': attachment.mimeType,
            'data': base64Encode(bytes),
          },
        });
      }
      contents.add({
        'role': message.role == 'model' ? 'model' : 'user',
        'parts': parts.isEmpty
            ? [
                {'text': message.content},
              ]
            : parts,
      });
    }
    return contents;
  }

  static String _messageTextWithAttachments(ChatMessage message) {
    if (message.attachments.isEmpty) return message.content;
    final buffer = StringBuffer(message.content);
    if (buffer.isNotEmpty) buffer.write('\n\n');
    buffer.writeln('[用户上传的附件]');
    for (final attachment in message.attachments) {
      buffer.writeln(
        '- ${attachment.name} (${attachment.mimeType}, ${_formatBytes(attachment.size ?? 0)})',
      );
      if (!attachment.isImage) {
        final file = File(attachment.path);
        if (file.existsSync() && (attachment.size ?? 0) <= 128 * 1024) {
          final text = _tryReadTextFile(file);
          if (text != null && text.trim().isNotEmpty) {
            buffer.writeln('```');
            buffer.writeln(text.length > 6000 ? text.substring(0, 6000) : text);
            buffer.writeln('```');
          }
        }
      }
    }
    return buffer.toString();
  }

  static String? _tryReadTextFile(File file) {
    try {
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  static _ReasoningSplit _splitReasoning(String raw) {
    final answer = StringBuffer();
    final reasoning = StringBuffer();
    var index = 0;
    var thinking = false;

    while (index < raw.length) {
      final start = raw.indexOf('<think>', index);
      if (start < 0) {
        answer.write(raw.substring(index));
        break;
      }
      answer.write(raw.substring(index, start));
      final contentStart = start + '<think>'.length;
      final end = raw.indexOf('</think>', contentStart);
      if (end < 0) {
        reasoning.write(raw.substring(contentStart));
        thinking = true;
        break;
      }
      reasoning.write(raw.substring(contentStart, end));
      reasoning.write('\n\n');
      index = end + '</think>'.length;
    }

    return _ReasoningSplit(
      answer: answer.toString().trimLeft(),
      reasoning: reasoning.toString().trim(),
      thinking: thinking,
    );
  }

  static Map<String, dynamic> _themeTool() {
    return {
      'functionDeclarations': [
        {
          'name': 'modify_ui_state',
          'description':
              'Modifies the visual theme of the chat interface based on the conversation context or user request.',
          'parameters': {
            'type': 'object',
            'properties': {
              'backgroundColor': {
                'type': 'string',
                'description': 'A CSS hex color string for the background.',
              },
              'textColor': {
                'type': 'string',
                'description': 'A CSS hex color string for readable text.',
              },
              'fontFamily': {
                'type': 'string',
                'enum': ['sans', 'serif'],
              },
              'isDark': {'type': 'boolean'},
            },
          },
        },
      ],
    };
  }

  static List<String> _guessCaps(String id) {
    final lower = id.toLowerCase();
    final caps = <String>[];
    if (lower.contains('vision') ||
        lower.contains('vl') ||
        lower.contains('omni')) {
      caps.add('vision');
    }
    if (lower.contains('image')) caps.add('image');
    if (lower.contains('tool') || lower.contains('function')) caps.add('tool');
    if (lower.contains('reason') || lower.contains('think')) caps.add('reason');
    return caps.isEmpty ? ['chat'] : caps;
  }

  static String normalizeBaseUrl(String value) {
    var base = value.trim();
    final schemeMatch = RegExp(
      r'^(https?):/*',
      caseSensitive: false,
    ).firstMatch(base);
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      base = '$scheme://${base.substring(schemeMatch.end)}';
    } else if (!base.toLowerCase().startsWith('http')) {
      base = 'https://$base';
    }
    base = base.replaceFirstMapped(
      RegExp(r'^(https?)://+', caseSensitive: false),
      (match) {
        return '${match.group(1)!.toLowerCase()}://';
      },
    );
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  static String _trimSlash(String value) => normalizeBaseUrl(value);
}

class _GeminiResult {
  const _GeminiResult({required this.text, required this.functionCalls});

  final String text;
  final List<Map<String, dynamic>> functionCalls;
}

class _ReasoningSplit {
  const _ReasoningSplit({
    required this.answer,
    required this.reasoning,
    required this.thinking,
  });

  final String answer;
  final String reasoning;
  final bool thinking;
}
