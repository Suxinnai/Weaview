import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/services/provider_config_service.dart';
import 'package:weaview_flutter/src/app/weaview_preferences.dart';

void main() {
  test(
    'normalizes search and unsupported TTS providers during startup',
    () async {
      SharedPreferences.setMockInitialValues({
        'ai_search_config': jsonEncode({
          'active': 'brave',
          'keys': {'brave': 'legacy-search-key'},
        }),
        'ai_tts_providers': jsonEncode([
          {
            'id': 'legacy',
            'type': 'azure',
            'name': 'Legacy gateway',
            'apiKey': 'legacy-tts-key',
            'baseUrl': 'https://tts.example.com/v1',
            'model': 'tts-model',
            'voice': 'voice',
          },
        ]),
        'ai_active_tts_id': 'missing-provider',
      });
      final prefs = await WeaviewPreferences.open();
      final service = ProviderConfigService()..load(prefs);

      expect(service.searchConfig.active, 'tavily');
      expect(service.ttsProviders.first.type, 'custom');
      expect(service.activeTtsId, isEmpty);
      expect(prefs.loadSearchConfig()!.active, 'tavily');
      expect(prefs.loadTtsProviders().first.type, 'custom');
      expect(prefs.activeTtsId, isEmpty);
    },
  );
}
