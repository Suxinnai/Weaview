import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:weaview_flutter/src/data/skills/github_skill_client.dart';

void main() {
  test('GithubSkillClient downloads and parses root SKILL.md', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      if (request.uri.path.endsWith('/owner/repo/main/SKILL.md')) {
        request.response
          ..headers.contentType = ContentType.text
          ..write(
            '---\nname: x-tweet-fetcher\ndescription: Fetch tweets\n---\n\nUse this skill.',
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    try {
      final client = GithubSkillClient(client: _HostRewriteClient(server.port));
      final skill = await client.install(
        sourceUrl: 'https://github.com/owner/repo',
        timeout: const Duration(seconds: 5),
      );

      expect(skill.id, 'x-tweet-fetcher');
      expect(skill.name, 'x-tweet-fetcher');
      expect(skill.description, 'Fetch tweets');
      expect(skill.systemPrompt, 'Use this skill.');
      expect(skill.triggers, contains('x.com'));
      expect(skill.executionMode, 'context');
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });

  test(
    'GithubSkillClient supports tree branch and subdirectory paths',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final serving = server.listen((request) async {
        paths.add(request.uri.path);
        if (request.uri.path.endsWith('/owner/repo/dev/skills/foo/SKILL.md')) {
          request.response
            ..headers.contentType = ContentType.text
            ..write('# Foo Skill\n\nUseful helper');
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      try {
        final client = GithubSkillClient(
          client: _HostRewriteClient(server.port),
        );
        final skill = await client.install(
          sourceUrl: 'https://github.com/owner/repo/tree/dev/skills/foo',
          timeout: const Duration(seconds: 5),
        );

        expect(skill.name, 'Foo Skill');
        expect(skill.description, 'Useful helper');
        expect(skill.localPath, 'repo/skills/foo');
        expect(paths, contains('/owner/repo/dev/skills/foo/SKILL.md'));
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    },
  );
}

class _HostRewriteClient extends http.BaseClient {
  _HostRewriteClient(this.port);

  final int port;

  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final rewritten = request.url.replace(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
    );
    final next = http.Request(request.method, rewritten)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    if (request is http.Request) {
      next.bodyBytes = request.bodyBytes;
    }
    return _inner.send(next);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
