import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/weaview_preferences.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('WeaviewPreferences', () {
    test('loads existing raw preference keys through typed getters', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'theme_background': '#000000',
        'theme_font_style': 'unexpected',
        'theme_assistant_bubble_opacity': 0.33,
        'user_name': 'Tester',
      });

      final prefs = await WeaviewPreferences.open();

      expect(prefs.themeMode, ThemeMode.dark);
      expect(prefs.themeBackground, Colors.black);
      expect(prefs.fontStyle, 'normal');
      expect(prefs.assistantBubbleOpacity, 0.33);
      expect(prefs.userName, 'Tester');
    });

    test(
      'round-trips providers and model assignments without changing shapes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await WeaviewPreferences.open();
        final providers = [
          AiProvider.defaults().first.copyWith(apiKey: 'secret', current: true),
        ];
        final assignments = {
          'chat': const ModelAssignment(
            provider: 'OpenAI',
            model: 'gpt-4o-mini',
            prompt: 'chat prompt',
          ),
        };

        prefs.saveProviders(providers);
        prefs.saveModelAssignments(assignments);
        prefs.saveSearchConfig(
          const SearchConfig(
            active: 'tavily',
            keys: {'tavily': 'search-secret'},
          ),
        );
        prefs.saveTtsConfig(const [
          TtsProviderConfig(
            id: 'custom',
            type: 'openai',
            name: 'Custom',
            apiKey: 'tts-secret',
            baseUrl: 'https://tts.example.com/v1',
            model: 'tts-model',
            voice: 'voice',
          ),
        ], 'custom');

        final loadedProvider = prefs.loadProviders().single;
        final loadedAssignment = prefs.loadModelAssignments()!['chat']!;

        expect(loadedProvider.name, providers.single.name);
        expect(loadedProvider.apiKey, 'secret');
        expect(loadedProvider.current, isTrue);
        expect(loadedAssignment.provider, 'OpenAI');
        expect(loadedAssignment.model, 'gpt-4o-mini');
        expect(loadedAssignment.prompt, 'chat prompt');
        expect(prefs.loadSearchConfig()!.keys['tavily'], 'search-secret');
        expect(prefs.loadTtsProviders().single.apiKey, 'tts-secret');

        final raw = await SharedPreferences.getInstance();
        expect(raw.getString('ai_providers'), isNot(contains('secret')));
        expect(
          raw.getString('ai_search_config'),
          isNot(contains('search-secret')),
        );
        expect(
          raw.getString('ai_tts_providers'),
          isNot(contains('tts-secret')),
        );

        await Future<void>.delayed(Duration.zero);
        final reopened = await WeaviewPreferences.open();
        expect(reopened.loadProviders().single.apiKey, 'secret');
        expect(reopened.loadSearchConfig()!.keys['tavily'], 'search-secret');
        expect(reopened.loadTtsProviders().single.apiKey, 'tts-secret');
      },
    );

    test('migrates legacy provider keys out of the provider JSON', () async {
      final provider = AiProvider.defaults().first.copyWith(
        apiKey: 'legacy-key',
      );
      SharedPreferences.setMockInitialValues({
        'ai_providers': jsonEncode([provider.toJson()]),
      });

      final prefs = await WeaviewPreferences.open();

      expect(prefs.loadProviders().single.apiKey, 'legacy-key');
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('ai_providers'), isNot(contains('legacy-key')));
    });

    test('clear waits for queued secret writes and removes them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await WeaviewPreferences.open();
      prefs.saveProviders([
        AiProvider.defaults().first.copyWith(apiKey: 'queued-secret'),
      ]);

      await prefs.clear();
      final reopened = await WeaviewPreferences.open();

      expect(reopened.loadProviders(), isEmpty);
      final raw = await SharedPreferences.getInstance();
      expect(raw.getKeys(), isEmpty);
    });

    test(
      'reset theme controls clears color overrides but preserves defaults',
      () async {
        SharedPreferences.setMockInitialValues({
          'theme_background': '#000000',
          'theme_text': '#FFFFFF',
          'theme_assistant_bubble': '#111111',
          'theme_user_bubble': '#222222',
        });
        final prefs = await WeaviewPreferences.open();

        prefs.resetThemeControls(
          fontFamily: 'sans',
          fontStyle: 'normal',
          fontWeight: 'normal',
          bubbleStyle: 'minimal',
          messageAlignment: 'left',
          assistantBubbleOpacity: 0.08,
          userBubbleOpacity: 0.12,
          themeMode: ThemeMode.system,
        );

        expect(prefs.themeBackground, isNull);
        expect(prefs.themeText, isNull);
        expect(prefs.assistantBubble, isNull);
        expect(prefs.userBubble, isNull);
        expect(prefs.fontFamily, 'sans');
        expect(prefs.bubbleStyle, 'minimal');
        expect(prefs.themeMode, ThemeMode.system);
      },
    );
  });
}
