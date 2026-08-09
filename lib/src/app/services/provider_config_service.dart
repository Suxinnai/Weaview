import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../weaview_preferences.dart';

class ProviderConfigService {
  List<AiProvider> providers = AiProvider.defaults();
  Map<String, ModelAssignment> modelAssignments = ModelAssignment.defaults();
  SearchConfig searchConfig = const SearchConfig(active: 'tavily', keys: {});
  String activeTtsId = '';
  List<TtsProviderConfig> ttsProviders = TtsProviderConfig.defaults();

  void load(WeaviewPreferences prefs) {
    final savedProviders = prefs.loadProviders();
    if (savedProviders.isNotEmpty) {
      final savedNames = savedProviders
          .map((p) => p.name.toLowerCase())
          .toSet();
      providers = [
        ...savedProviders,
        for (final preset in AiProvider.defaults())
          if (!savedNames.contains(preset.name.toLowerCase())) preset,
      ];
    }
    final defaultProvidersByName = {
      for (final provider in AiProvider.defaults())
        provider.name.toLowerCase(): provider,
    };
    providers = providers.map((provider) {
      var normalized = provider.copyWith(models: provider.models);
      final preset = defaultProvidersByName[normalized.name.toLowerCase()];
      if (normalized.baseUrl.isEmpty && preset?.baseUrl.isNotEmpty == true) {
        normalized = normalized.copyWith(baseUrl: preset!.baseUrl);
      }
      if (preset != null) {
        normalized = normalized.copyWith(
          models: withPresetModels(normalized.models, preset.models),
          imageApi: preset.imageApi,
          status: normalized.apiKey.isEmpty ? '未配置' : normalized.status,
        );
      }
      return normalized;
    }).toList();
    if (!providers.any((p) => p.enabled && p.current) &&
        providers.any((p) => p.enabled)) {
      final preferred = providers.indexWhere(
        (p) => p.enabled && p.apiKey.isNotEmpty,
      );
      final fallback = preferred >= 0 ? preferred : -1;
      providers = [
        for (var i = 0; i < providers.length; i++)
          providers[i].copyWith(
            current: i == fallback,
            status: !providers[i].enabled
                ? '已禁用'
                : i == fallback
                ? '使用中'
                : providers[i].apiKey.isEmpty
                ? '未配置'
                : '已连接',
          ),
      ];
    }
    _persistProviders(prefs);

    final savedAssignments = prefs.loadModelAssignments();
    if (savedAssignments != null) {
      modelAssignments = {...ModelAssignment.defaults(), ...savedAssignments};
    }
    final chatAssignment = modelAssignments['chat'];
    if (chatAssignment != null &&
        chatAssignment.provider.toLowerCase().contains('gemini') &&
        providers
                .firstWhereOrNull(
                  (p) => p.name.toLowerCase().contains('gemini'),
                )
                ?.models
                .isEmpty !=
            false) {
      modelAssignments = {
        ...modelAssignments,
        'chat': chatAssignment.copyWith(provider: '', model: ''),
      };
    }

    searchConfig = prefs.loadSearchConfig() ?? searchConfig;

    final savedTts = prefs.loadTtsProviders();
    ttsProviders = _mergeTtsProviders(savedTts);
    activeTtsId = _safeActiveTtsId(prefs.activeTtsId, ttsProviders);
  }

  void saveProviders(List<AiProvider> next, WeaviewPreferences? prefs) {
    providers = next.map((p) => p.copyWith(models: p.models)).toList();
    _normalizeCurrentProvider();
    _persistProviders(prefs);
  }

  void reorderProvider(int oldIndex, int newIndex, WeaviewPreferences? prefs) {
    if (oldIndex < 0 || oldIndex >= providers.length) return;
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;
    targetIndex = targetIndex.clamp(0, providers.length - 1);
    final next = [...providers];
    final item = next.removeAt(oldIndex);
    next.insert(targetIndex, item);
    saveProviders(next, prefs);
  }

  void upsertProvider(
    AiProvider provider, {
    bool makeCurrent = false,
    WeaviewPreferences? prefs,
  }) {
    final next = [...providers];
    final index = next.indexWhere((p) => p.name == provider.name);
    var updated = provider;
    if (makeCurrent) {
      updated = provider.copyWith(enabled: true, current: true, status: '使用中');
      for (var i = 0; i < next.length; i++) {
        next[i] = next[i].copyWith(
          current: false,
          status: !next[i].enabled
              ? '已禁用'
              : next[i].apiKey.isEmpty
              ? '未配置'
              : '已连接',
        );
      }
    }
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.add(updated);
    }
    if (!updated.enabled) {
      _clearAssignmentsForProvider(updated.name, prefs);
    }
    saveProviders(next, prefs);
  }

  void setProviderEnabled(
    String name,
    bool enabled,
    WeaviewPreferences? prefs,
  ) {
    providers = [
      for (final provider in providers)
        if (provider.name == name)
          provider.copyWith(
            enabled: enabled,
            current: enabled ? provider.current : false,
            status: !enabled
                ? '已禁用'
                : provider.current
                ? '使用中'
                : provider.apiKey.isEmpty
                ? '未配置'
                : '已连接',
          )
        else
          provider,
    ];
    _normalizeCurrentProvider();
    if (!enabled) _clearAssignmentsForProvider(name, prefs);
    _persistProviders(prefs);
  }

  void deleteProvider(String name, WeaviewPreferences? prefs) {
    final next = providers.where((p) => p.name != name).toList();
    _clearAssignmentsForProvider(name, prefs);
    saveProviders(next, prefs);
  }

  void saveModelAssignment(
    String role,
    ModelAssignment assignment,
    WeaviewPreferences? prefs,
  ) {
    modelAssignments = {...modelAssignments, role: assignment};
    prefs?.saveModelAssignments(modelAssignments);
  }

  void saveSearchConfig(SearchConfig next, WeaviewPreferences? prefs) {
    searchConfig = next;
    prefs?.saveSearchConfig(next);
  }

  void saveTtsConfig(
    List<TtsProviderConfig> providers,
    String activeId,
    WeaviewPreferences? prefs,
  ) {
    final next = _mergeTtsProviders(providers);
    final nextActiveId = _safeActiveTtsId(activeId, next);
    ttsProviders = next;
    activeTtsId = nextActiveId;
    prefs?.saveTtsConfig(next, nextActiveId);
  }

  AiProvider get activeChatProvider {
    final chatAssignment = modelAssignments['chat'];
    if (chatAssignment != null) {
      final provider = providers.firstWhereOrNull(
        (p) => p.enabled && p.name == chatAssignment.provider,
      );
      if (provider != null) return provider;
    }
    return providers.firstWhereOrNull((p) => p.enabled && p.current) ??
        providers.firstWhereOrNull((p) => p.enabled && p.apiKey.isNotEmpty) ??
        providers.firstWhereOrNull((p) => p.enabled) ??
        providers.first;
  }

  List<AiProvider> get enabledModelProviders => providers
      .where(
        (p) => p.enabled && p.apiKey.trim().isNotEmpty && p.models.isNotEmpty,
      )
      .toList();

  bool get hasActiveSearchKey =>
      (searchConfig.keys[searchConfig.active]?.trim().isNotEmpty ?? false);

  bool get ttsEnabled => activeTtsId.trim().isNotEmpty;

  TtsProviderConfig? get activeTtsProvider =>
      ttsProviders.firstWhereOrNull((p) => p.id == activeTtsId);

  void _persistProviders(WeaviewPreferences? prefs) {
    prefs?.saveProviders(providers);
  }

  void _normalizeCurrentProvider() {
    final enabledCurrentIndex = providers.indexWhere(
      (provider) => provider.enabled && provider.current,
    );
    final nextCurrentIndex = enabledCurrentIndex >= 0
        ? enabledCurrentIndex
        : providers.indexWhere(
            (provider) => provider.enabled && provider.apiKey.isNotEmpty,
          );
    final fallbackIndex = nextCurrentIndex;
    providers = [
      for (var i = 0; i < providers.length; i++)
        providers[i].copyWith(
          current: fallbackIndex >= 0 && i == fallbackIndex,
          status: !providers[i].enabled
              ? '已禁用'
              : fallbackIndex >= 0 && i == fallbackIndex
              ? '使用中'
              : providers[i].apiKey.isEmpty
              ? '未配置'
              : '已连接',
        ),
    ];
  }

  void _clearAssignmentsForProvider(String name, WeaviewPreferences? prefs) {
    var changed = false;
    modelAssignments = modelAssignments.map((role, assignment) {
      if (assignment.provider != name) return MapEntry(role, assignment);
      changed = true;
      return MapEntry(role, assignment.copyWith(provider: '', model: ''));
    });
    if (changed) prefs?.saveModelAssignments(modelAssignments);
  }

  List<TtsProviderConfig> _mergeTtsProviders(List<TtsProviderConfig> saved) {
    final defaults = TtsProviderConfig.defaults();
    if (saved.isEmpty) return defaults;
    final defaultsById = {for (final p in defaults) p.id: p};
    final merged = saved.map((provider) {
      final preset = defaultsById[provider.id];
      if (preset == null) return provider;
      return provider.copyWith(
        type: provider.id == 'xiaomi' || provider.type.isEmpty
            ? preset.type
            : provider.type,
        name: provider.name.isEmpty ? preset.name : provider.name,
        baseUrl: provider.baseUrl.isEmpty ? preset.baseUrl : provider.baseUrl,
        model: provider.model.isEmpty ? preset.model : provider.model,
        voice: provider.voice.isEmpty ? preset.voice : provider.voice,
      );
    }).toList();
    final savedIds = merged.map((p) => p.id).toSet();
    merged.addAll(defaults.where((p) => !savedIds.contains(p.id)));
    return merged;
  }

  String _safeActiveTtsId(String activeId, List<TtsProviderConfig> providers) {
    final trimmed = activeId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed == 'system') return 'system';
    return providers.any((p) => p.id == trimmed) ? trimmed : '';
  }
}
