import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('SkillConfig persists fields through json', () {
    const skill = SkillConfig(
      id: 'x-tweet-fetcher',
      name: 'X Tweet Fetcher',
      description: 'Fetch tweets',
      sourceUrl: 'https://github.com/ythx-101/x-tweet-fetcher',
      localPath: '/tmp/skill',
      triggers: ['tweet', '推文'],
      systemPrompt: 'Use concise output.',
      entrypoints: [SkillEntrypoint(id: 'fetch_tweet', label: '抓取推文')],
      createdAt: 1,
      updatedAt: 2,
    );

    final decoded = SkillConfig.fromJson(skill.toJson());

    expect(decoded.id, 'x-tweet-fetcher');
    expect(decoded.name, 'X Tweet Fetcher');
    expect(decoded.triggers, ['tweet', '推文']);
    expect(decoded.primaryEntrypoint, 'fetch_tweet');
    expect(decoded.systemPrompt, 'Use concise output.');
    expect(decoded.executionMode, 'runner');
  });

  test('SkillConfig defaults legacy records to context execution mode', () {
    final skill = SkillConfig.fromJson({
      'id': 'legacy',
      'name': 'Legacy Skill',
      'description': '',
      'sourceUrl': '',
      'createdAt': 1,
      'updatedAt': 1,
    });

    expect(skill.executionMode, 'context');
    expect(skill.runsOnRunner, isFalse);
  });

  test('SkillConfig preserves runner execution mode', () {
    final skill = SkillConfig.fromJson({
      'id': 'runner',
      'name': 'Runner Skill',
      'description': '',
      'sourceUrl': '',
      'executionMode': 'runner',
      'createdAt': 1,
      'updatedAt': 1,
    });

    expect(skill.executionMode, 'runner');
    expect(skill.runsOnRunner, isTrue);
    expect(skill.toJson()['executionMode'], 'runner');
  });

  test('SkillConfig rejects invalid records without crashing callers', () {
    expect(
      () => SkillConfig.fromJson({'name': 'Missing id'}),
      throwsFormatException,
    );
  });
}
