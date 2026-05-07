import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

class TavilySearchClient {
  const TavilySearchClient();

  Future<String> search({
    required SearchConfig config,
    required String query,
    required Duration timeout,
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
        .timeout(timeout);
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
}
