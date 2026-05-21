import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/services/skill_service.dart';
import 'package:weaview_flutter/src/app/weaview_preferences.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('SkillService matches enabled trigger before URL heuristic', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await WeaviewPreferences.open();
    final service = SkillService()..load(prefs);

    service.upsertSkill(
      const SkillConfig(
        id: 'tweet',
        name: 'Tweet Skill',
        description: 'Fetch tweets',
        sourceUrl: 'https://github.com/ythx-101/x-tweet-fetcher',
        triggers: ['推文'],
        createdAt: 1,
        updatedAt: 1,
      ),
      prefs,
    );

    expect(service.matchSkill('帮我抓取这条推文')?.id, 'tweet');
  });

  test('SkillService uses URL heuristic for tweet-like skills', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await WeaviewPreferences.open();
    final service = SkillService()..load(prefs);

    service.upsertSkill(
      const SkillConfig(
        id: 'x-tweet-fetcher',
        name: 'X Tweet Fetcher',
        description: 'Fetch tweets from X',
        sourceUrl: 'https://github.com/ythx-101/x-tweet-fetcher',
        triggers: [],
        createdAt: 1,
        updatedAt: 1,
      ),
      prefs,
    );

    expect(
      service.matchSkill('https://x.com/example/status/123')?.id,
      'x-tweet-fetcher',
    );
  });

  test('SkillService active skill overrides automatic matching', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await WeaviewPreferences.open();
    final service = SkillService()..load(prefs);

    service
      ..upsertSkill(
        const SkillConfig(
          id: 'manual',
          name: 'Manual',
          description: '',
          sourceUrl: '',
          triggers: [],
          createdAt: 1,
          updatedAt: 1,
        ),
        prefs,
      )
      ..setActiveSkill('manual', prefs);

    expect(service.matchSkill('普通消息')?.id, 'manual');
  });
}
