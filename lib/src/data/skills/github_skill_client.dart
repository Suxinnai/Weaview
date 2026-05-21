import 'package:http/http.dart' as http;

import '../../domain/models.dart';

class GithubSkillClient {
  const GithubSkillClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<SkillConfig> install({
    required String sourceUrl,
    required Duration timeout,
  }) async {
    final locator = _GithubSkillLocator.parse(sourceUrl);
    final client = _client ?? http.Client();
    try {
      final resolved = await _fetchSkillMarkdown(
        client: client,
        locator: locator,
        timeout: timeout,
      );
      final parsed = _parseSkillMarkdown(resolved.markdown);
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = _skillIdFrom(parsed.name, locator);
      final description = parsed.description.isNotEmpty
          ? parsed.description
          : _firstBodyLine(parsed.body);
      return SkillConfig(
        id: id,
        name: parsed.name.isNotEmpty ? parsed.name : id,
        description: description,
        sourceUrl: sourceUrl.trim(),
        localPath: resolved.relativePath.isEmpty
            ? locator.repo
            : '${locator.repo}/${resolved.relativePath}',
        enabled: true,
        triggers: _defaultTriggersFor(
          '$id ${parsed.name} $description ${sourceUrl.trim()}',
        ),
        systemPrompt: parsed.body.trim(),
        entrypoints: _entrypointsFor('$id ${parsed.name} $description'),
        createdAt: now,
        updatedAt: now,
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<_ResolvedSkillMarkdown> _fetchSkillMarkdown({
    required http.Client client,
    required _GithubSkillLocator locator,
    required Duration timeout,
  }) async {
    final candidates = locator.candidates();
    for (final candidate in candidates) {
      final uri = Uri.https(
        'raw.githubusercontent.com',
        [
          locator.owner,
          locator.repo,
          candidate.branch,
          if (candidate.path.isNotEmpty) candidate.path,
          'SKILL.md',
        ].join('/'),
      );
      final response = await client.get(uri).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _ResolvedSkillMarkdown(
          markdown: response.body,
          branch: candidate.branch,
          relativePath: candidate.path,
        );
      }
    }
    throw Exception('未在 GitHub 仓库中找到 SKILL.md。');
  }

  static _ParsedSkillMarkdown _parseSkillMarkdown(String content) {
    final (frontmatter, body) = _splitFrontmatter(content);
    final bodyLines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .toList();
    final title =
        frontmatter['name'] ??
        bodyLines
            .firstWhere((line) => line.startsWith('#'), orElse: () => '')
            .replaceFirst(RegExp(r'^#+\s*'), '')
            .trim();
    final description =
        frontmatter['description'] ??
        bodyLines.firstWhere(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('```'),
          orElse: () => '',
        );
    return _ParsedSkillMarkdown(
      name: title.trim(),
      description: description.trim(),
      body: body.trim(),
    );
  }

  static (Map<String, String>, String) _splitFrontmatter(String content) {
    if (!content.startsWith('---')) return (const {}, content);
    final match = RegExp(
      r'\r?\n---(?:\r?\n|$)',
    ).firstMatch(content.substring(3));
    if (match == null) return (const {}, content);
    final endStart = 3 + match.start;
    final endEnd = 3 + match.end;
    final yaml = content.substring(3, endStart).trim();
    final meta = <String, String>{};
    for (final line in yaml.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim().replaceAll('"', '');
      if (key.isNotEmpty && value.isNotEmpty) meta[key] = value;
    }
    return (meta, content.substring(endEnd).trimLeft());
  }

  static String _firstBodyLine(String body) {
    return body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('```'),
          orElse: () => '',
        );
  }

  static String _skillIdFrom(String name, _GithubSkillLocator locator) {
    final source = name.trim().isEmpty ? locator.repo : name.trim();
    final slug = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? locator.repo : slug;
  }

  static List<SkillEntrypoint> _entrypointsFor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('tweet') ||
        lower.contains('twitter') ||
        lower.contains('x-tweet')) {
      return const [SkillEntrypoint(id: 'fetch_tweet', label: '抓取推文')];
    }
    return const [SkillEntrypoint(id: 'default', label: '默认入口')];
  }

  static List<String> _defaultTriggersFor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('tweet') ||
        lower.contains('twitter') ||
        lower.contains('x.com') ||
        lower.contains('x-tweet') ||
        lower.contains('weibo') ||
        lower.contains('bilibili') ||
        lower.contains('wechat')) {
      return const ['tweet', 'twitter', 'x.com', '推文', '微博'];
    }
    return const [];
  }
}

class _GithubSkillLocator {
  const _GithubSkillLocator({
    required this.owner,
    required this.repo,
    this.treeSegments = const [],
  });

  final String owner;
  final String repo;
  final List<String> treeSegments;

  static _GithubSkillLocator parse(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(
      input.startsWith('http') ? input : 'https://$input',
    );
    if (uri == null || uri.host.toLowerCase() != 'github.com') {
      throw Exception('请输入 GitHub 仓库 URL。');
    }
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) throw Exception('GitHub URL 缺少 owner/repo。');
    final repo = segments[1].replaceFirst(RegExp(r'\.git$'), '');
    final treeIndex = segments.indexOf('tree');
    return _GithubSkillLocator(
      owner: segments[0],
      repo: repo,
      treeSegments: treeIndex >= 0 && treeIndex + 1 < segments.length
          ? segments.sublist(treeIndex + 1)
          : const [],
    );
  }

  List<_GithubRawCandidate> candidates() {
    if (treeSegments.isEmpty) {
      return const [
        _GithubRawCandidate(branch: 'main', path: ''),
        _GithubRawCandidate(branch: 'master', path: ''),
      ];
    }
    return [
      for (var branchEnd = 1; branchEnd <= treeSegments.length; branchEnd++)
        _GithubRawCandidate(
          branch: treeSegments.take(branchEnd).join('/'),
          path: treeSegments.skip(branchEnd).join('/'),
        ),
    ];
  }
}

class _GithubRawCandidate {
  const _GithubRawCandidate({required this.branch, required this.path});

  final String branch;
  final String path;
}

class _ResolvedSkillMarkdown {
  const _ResolvedSkillMarkdown({
    required this.markdown,
    required this.branch,
    required this.relativePath,
  });

  final String markdown;
  final String branch;
  final String relativePath;
}

class _ParsedSkillMarkdown {
  const _ParsedSkillMarkdown({
    required this.name,
    required this.description,
    required this.body,
  });

  final String name;
  final String description;
  final String body;
}
