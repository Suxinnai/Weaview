import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/skills/skill_runner_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('SkillRunnerClient parses health, install, and run responses', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final serving = server.listen((request) async {
      requests.add(request.uri.path);
      if (request.uri.path == '/health') {
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true,"version":"0.1.0"}');
      } else if (request.uri.path == '/skills/install') {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'id': 'x-tweet-fetcher',
              'name': 'X Tweet Fetcher',
              'description': 'Fetch tweets',
              'sourceUrl': body['url'],
              'entrypoints': [
                {'id': 'fetch_tweet', 'label': '抓取推文'},
              ],
            }),
          );
      } else if (request.uri.path == '/skills/run') {
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true,"text":"tweet result","json":{"id":"1"}}');
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    try {
      const client = SkillRunnerClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      expect(
        await client.health(
          baseUrl: baseUrl,
          timeout: const Duration(seconds: 5),
        ),
        isTrue,
      );
      final skill = await client.install(
        baseUrl: baseUrl,
        sourceUrl: 'https://github.com/ythx-101/x-tweet-fetcher',
        timeout: const Duration(seconds: 5),
      );
      expect(skill.id, 'x-tweet-fetcher');
      expect(skill.triggers, contains('x.com'));

      final result = await client.run(
        baseUrl: baseUrl,
        skill: skill,
        input: 'https://x.com/example/status/123',
        messages: [ChatMessage.user('hello')],
        timeout: const Duration(seconds: 5),
      );
      expect(result.ok, isTrue);
      expect(result.text, 'tweet result');
      expect(requests, ['/health', '/skills/install', '/skills/run']);
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });

  test('SkillRunnerClient returns structured run errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write('{"ok":false,"error":"No URL found"}');
      await request.response.close();
    });

    try {
      const client = SkillRunnerClient();
      final result = await client.run(
        baseUrl: 'http://127.0.0.1:${server.port}',
        skill: const SkillConfig(
          id: 'x-tweet-fetcher',
          name: 'X Tweet Fetcher',
          description: '',
          sourceUrl: '',
          createdAt: 1,
          updatedAt: 1,
        ),
        input: 'no url',
        messages: const [],
        timeout: const Duration(seconds: 5),
      );

      expect(result.ok, isFalse);
      expect(result.error, 'No URL found');
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });
}
