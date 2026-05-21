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
      final savedNames =
          savedProviders.map((p) => p.name.toLowerCase()).toSet();
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
      if (normalized.name.toLowerCase().contains('gemini') &&
          normalized.apiKey.isEmpty) {
        return normalized.copyWith(models: const [], status: '未配置');
      }
      return normalized;
    }).toList();
    if (!providers.any((p) => p.current) && providers.isNotEmpty) {
      final preferred = providers.indexWhere((p) => p.apiKey.isNotEmpty);
      providers = [
        for (var i = 0; i < providers.length; i++)
          providers[i].copyWith(
            current: preferred >= 0 && i == preferred,
            status: preferred >= 0 && i == preferred
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
    providers = next
        .map((p) => p.copyWith(models: p.models))
        .toList();
    _persistProviders(prefs);
  }

  void reorderProvider(
    int oldIndex,
    int newIndex,
    WeaviewPreferences? prefs,
  ) {
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
      updated = provider.copyWith(current: true, status: '使用中');
      for (var i = 0; i < next.length; i++) {
        next[i] = next[i].copyWith(
          current: false,
          status: next[i].apiKey.isEmpty ? '未配置' : '已连接',
        );
      }
    }
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.add(updated);
    }
    saveProviders(next, prefs);
  }

  void deleteProvider(String name, WeaviewPreferences? prefs) {
    final next = providers.where((p) => p.name != name).toList();
    if (!next.any((p) => p.current) && next.isNotEmpty) {
      next[0] = next[0].copyWith(current: true, status: '使用中');
    }
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
        (p) => p.name == chatAssignment.provider,
      );
      if (provider != null) return provider;
    }
    return providers.firstWhereOrNull((p) => p.apiKey.isNotEmpty) ??
        providers.first;
  }

  List<AiProvider> get enabledModelProviders => providers
      .where((p) => p.apiKey.trim().isNotEmpty && p.models.isNotEmpty)
      .toList();

  bool get hasActiveSearchKey =>
      (searchConfig.keys[searchConfig.active]?.trim().isNotEmpty ?? false);

  bool get ttsEnabled => activeTtsId.trim().isNotEmpty;

  TtsProviderConfig? get activeTtsProvider =>
      ttsProviders.firstWhereOrNull((p) => p.id == activeTtsId);

  void _persistProviders(WeaviewPreferences? prefs) {
    prefs?.saveProviders(providers);
  }

  List<TtsProviderConfig> _mergeTtsProviders(List<TtsProviderConfig> saved) {
    final defaults = TtsProviderConfig.defaults();
    if (saved.isEmpty) return defaults;
    final defaultsById = {
      for (final p in defaults) p.id: p,
    };
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

  String _safeActiveTtsId(
    String activeId,
    List<TtsProviderConfig> providers,
  ) {
    final trimmed = activeId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed == 'system') return 'system';
    return providers.any((p) => p.id == trimmed) ? trimmed : '';
  }
}
