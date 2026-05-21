import '../../data/skills/skill_runner_client.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../weaview_preferences.dart';

class SkillService {
  SkillService({SkillRunnerClient client = const SkillRunnerClient()})
    : _client = client;

  final SkillRunnerClient _client;
  List<SkillConfig> skills = [];
  String activeSkillId = '';
  String runnerBaseUrl = 'http://127.0.0.1:8765';

  void load(WeaviewPreferences prefs) {
    skills = prefs.loadSkills();
    runnerBaseUrl = prefs.skillRunnerBaseUrl;
    final savedActive = prefs.activeSkillId;
    activeSkillId = skills.any((skill) => skill.id == savedActive)
        ? savedActive
        : '';
  }

  SkillConfig? get activeSkill =>
      skills.firstWhereOrNull((skill) => skill.id == activeSkillId);

  void saveRunnerBaseUrl(String value, WeaviewPreferences? prefs) {
    runnerBaseUrl = value.trim().isEmpty
        ? 'http://127.0.0.1:8765'
        : value.trim();
    prefs?.saveSkillRunnerBaseUrl(runnerBaseUrl);
  }

  void setActiveSkill(String skillId, WeaviewPreferences? prefs) {
    activeSkillId = activeSkillId == skillId ? '' : skillId;
    prefs?.saveActiveSkillId(activeSkillId);
  }

  void clearActiveSkill(WeaviewPreferences? prefs) {
    activeSkillId = '';
    prefs?.saveActiveSkillId('');
  }

  void upsertSkill(SkillConfig skill, WeaviewPreferences? prefs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final index = skills.indexWhere((item) => item.id == skill.id);
    final next = skill.copyWith(updatedAt: now);
    if (index >= 0) {
      skills = [
        for (var i = 0; i < skills.length; i++)
          if (i == index) next else skills[i],
      ];
    } else {
      skills = [...skills, next];
    }
    _persist(prefs);
  }

  void updateSkillEnabled(
    String skillId,
    bool enabled,
    WeaviewPreferences? prefs,
  ) {
    skills = [
      for (final skill in skills)
        if (skill.id == skillId)
          skill.copyWith(
            enabled: enabled,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        else
          skill,
    ];
    if (!enabled && activeSkillId == skillId) {
      activeSkillId = '';
      prefs?.saveActiveSkillId('');
    }
    _persist(prefs);
  }

  void updateSkillTriggers(
    String skillId,
    List<String> triggers,
    WeaviewPreferences? prefs,
  ) {
    skills = [
      for (final skill in skills)
        if (skill.id == skillId)
          skill.copyWith(
            triggers: _normalizeTriggers(triggers),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        else
          skill,
    ];
    _persist(prefs);
  }

  void updateSkillPrompt(
    String skillId,
    String prompt,
    WeaviewPreferences? prefs,
  ) {
    skills = [
      for (final skill in skills)
        if (skill.id == skillId)
          skill.copyWith(
            systemPrompt: prompt.trim(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        else
          skill,
    ];
    _persist(prefs);
  }

  void deleteSkill(String skillId, WeaviewPreferences? prefs) {
    skills = skills.where((skill) => skill.id != skillId).toList();
    if (activeSkillId == skillId) {
      activeSkillId = '';
      prefs?.saveActiveSkillId('');
    }
    _persist(prefs);
  }

  SkillConfig? matchSkill(String input) {
    final active = activeSkill;
    if (active != null && active.enabled) return active;
    final text = input.toLowerCase();
    if (text.trim().isEmpty) return null;
    final enabled = skills.where((skill) => skill.enabled);
    for (final skill in enabled) {
      for (final trigger in skill.triggers) {
        if (trigger.trim().isNotEmpty && text.contains(trigger.toLowerCase())) {
          return skill;
        }
      }
    }
    final hasUrl = RegExp(r'https?://\S+').hasMatch(input);
    if (!hasUrl) return null;
    for (final skill in enabled) {
      final haystack = '${skill.name} ${skill.description} ${skill.sourceUrl}'
          .toLowerCase();
      if (_urlToolNeedles.any(haystack.contains)) return skill;
    }
    return null;
  }

  Future<bool> testRunner() {
    return _client.health(
      baseUrl: runnerBaseUrl,
      timeout: const Duration(seconds: 5),
    );
  }

  Future<SkillConfig> installFromUrl(String sourceUrl) async {
    final skill = await _client.install(
      baseUrl: runnerBaseUrl,
      sourceUrl: sourceUrl,
      timeout: const Duration(seconds: 90),
    );
    return skill;
  }

  Future<SkillRunResult> runSkill({
    required SkillConfig skill,
    required String input,
    required List<ChatMessage> messages,
  }) {
    return _client.run(
      baseUrl: runnerBaseUrl,
      skill: skill,
      input: input,
      messages: messages,
      timeout: const Duration(seconds: 120),
    );
  }

  void _persist(WeaviewPreferences? prefs) {
    prefs?.saveSkills(skills);
  }

  static List<String> _normalizeTriggers(List<String> triggers) {
    return triggers
        .map((trigger) => trigger.trim())
        .where((trigger) => trigger.isNotEmpty)
        .toSet()
        .toList();
  }
}

const _urlToolNeedles = [
  'tweet',
  'twitter',
  'x.com',
  'weibo',
  'bilibili',
  'csdn',
  'wechat',
  '推文',
  '微博',
];
