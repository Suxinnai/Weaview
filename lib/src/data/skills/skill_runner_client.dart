import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';

class SkillRunResult {
  const SkillRunResult({required this.ok, this.text = '', this.error = ''});

  final bool ok;
  final String text;
  final String error;
}

class SkillRunnerClient {
  const SkillRunnerClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<bool> health({
    required String baseUrl,
    required Duration timeout,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('${_normalizeRunnerUrl(baseUrl)}/health'))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['ok'] == true;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<SkillConfig> install({
    required String baseUrl,
    required String sourceUrl,
    required Duration timeout,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${_normalizeRunnerUrl(baseUrl)}/skills/install'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': sourceUrl}),
          )
          .timeout(timeout);
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? decoded['error'] : response.body;
        throw Exception(message?.toString() ?? '技能安装失败。');
      }
      if (decoded is! Map) throw Exception('技能安装接口返回格式无效。');
      final now = DateTime.now().millisecondsSinceEpoch;
      return SkillConfig.fromJson({
        ...decoded.cast<String, dynamic>(),
        'enabled': true,
        'triggers': _defaultTriggersFor(decoded),
        'systemPrompt': decoded['systemPrompt']?.toString() ?? '',
        'executionMode': 'runner',
        'createdAt': now,
        'updatedAt': now,
      });
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<SkillRunResult> run({
    required String baseUrl,
    required SkillConfig skill,
    required String input,
    required List<ChatMessage> messages,
    String? entrypoint,
    required Duration timeout,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${_normalizeRunnerUrl(baseUrl)}/skills/run'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'skillId': skill.id,
              'input': input,
              'entrypoint': entrypoint ?? skill.primaryEntrypoint,
              'context': {
                'skillPrompt': skill.systemPrompt,
                'messages': messages
                    .map(
                      (message) => {
                        'role': message.role,
                        'content': message.content,
                      },
                    )
                    .toList(),
              },
            }),
          )
          .timeout(timeout);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const SkillRunResult(ok: false, error: '技能执行接口返回格式无效。');
      }
      final ok =
          decoded['ok'] == true &&
          response.statusCode >= 200 &&
          response.statusCode < 300;
      return SkillRunResult(
        ok: ok,
        text: decoded['text']?.toString() ?? '',
        error: decoded['error']?.toString() ?? (ok ? '' : '技能执行失败。'),
      );
    } catch (error) {
      return SkillRunResult(
        ok: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  static String _normalizeRunnerUrl(String value) {
    return app_utils.normalizeBaseUrl(value).replaceFirst(RegExp(r'/+$'), '');
  }

  static List<String> _defaultTriggersFor(Map decoded) {
    final text = [
      decoded['id'],
      decoded['name'],
      decoded['description'],
      decoded['sourceUrl'],
    ].join(' ').toLowerCase();
    if (text.contains('tweet') ||
        text.contains('twitter') ||
        text.contains('x-') ||
        text.contains('x_') ||
        text.contains('weibo') ||
        text.contains('bilibili') ||
        text.contains('wechat')) {
      return const ['tweet', 'twitter', 'x.com', '推文', '微博'];
    }
    return const [];
  }
}
