import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/app/model_config_resolver.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('ModelConfigResolver', () {
    test('reports missing role assignments before provider lookup', () {
      final issue = ModelConfigResolver.modelConfigIssue(
        assignment: const ModelAssignment(provider: '', model: '', prompt: ''),
        provider: null,
        role: 'chat',
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
        role: 'chat',
        roleLabel: '主对话模型',
      );

      expect(issue, contains('Gemini'));
      expect(issue, contains('API Key'));
    });

    test('rejects assignments whose model is no longer in the provider', () {
      final provider = AiProvider.defaults().first.copyWith(
        apiKey: 'secret',
        models: const [AiModel(id: 'gpt-current', name: 'GPT Current')],
      );

      final issue = ModelConfigResolver.modelConfigIssue(
        assignment: const ModelAssignment(
          provider: 'OpenAI',
          model: 'gpt-removed',
          prompt: '',
        ),
        provider: provider,
        role: 'chat',
        roleLabel: '主对话模型',
      );

      expect(issue, contains('已不在'));
    });

    test('rejects a pure image model assigned to the chat role', () {
      final provider = AiProvider.defaults().first.copyWith(
        apiKey: 'secret',
        models: const [
          AiModel(
            id: 'image-only',
            name: 'Image Only',
            capabilities: ['image'],
          ),
        ],
      );

      final issue = ModelConfigResolver.modelConfigIssue(
        assignment: const ModelAssignment(
          provider: 'OpenAI',
          model: 'image-only',
          prompt: '',
        ),
        provider: provider,
        role: 'chat',
        roleLabel: '主对话模型',
      );

      expect(issue, contains('不支持'));
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
