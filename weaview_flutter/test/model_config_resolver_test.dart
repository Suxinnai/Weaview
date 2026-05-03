import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/app/model_config_resolver.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('ModelConfigResolver', () {
    test('reports missing role assignments before provider lookup', () {
      final issue = ModelConfigResolver.modelConfigIssue(
        assignment: const ModelAssignment(provider: '', model: '', prompt: ''),
        provider: null,
        roleLabel: '主对话模型',
      );

      expect(issue, contains('默认模型'));
      expect(issue, contains('主对话模型'));
    });

    test('requires Gemini to use an explicitly configured API key', () {
      final provider = AiProvider.defaults().firstWhere(
        (item) => item.name == 'Gemini',
      );
      final issue = ModelConfigResolver.modelConfigIssue(
        assignment: const ModelAssignment(
          provider: 'Gemini',
          model: 'gemini-2.0-flash',
          prompt: '',
        ),
        provider: provider,
        roleLabel: '主对话模型',
      );

      expect(issue, contains('Gemini'));
      expect(issue, contains('API Key'));
    });

    test('prefers explicitly assigned chat provider over current flag', () {
      final providers = AiProvider.defaults()
          .map(
            (provider) => provider.name == 'OpenAI'
                ? provider.copyWith(current: true)
                : provider,
          )
          .toList();
      final active = ModelConfigResolver.activeChatProvider(
        providers: providers,
        assignments: {
          'chat': const ModelAssignment(
            provider: 'DeepSeek',
            model: 'deepseek-chat',
            prompt: '',
          ),
        },
      );

      expect(active.name, 'DeepSeek');
    });

    test('formats common network errors for users', () {
      final text = ModelConfigResolver.friendlyAiError(
        Exception('SocketException: failed host lookup'),
        chatRequestTimeout: const Duration(seconds: 45),
      );

      expect(text, contains('网络连接失败'));
    });
  });
}
