// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../core/app_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../settings_sheet.dart';

extension SettingsDetailViews on SettingsSheetState {
  Widget systemPromptView() {
    final state = widget.state;
    return scrollContent([
      Text(
        '修改此提示词将改变AI在此环境中的表现形态与语言风格。如果您想恢复，请清空内容。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: TextField(
          controller: systemPromptController,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          style: state.textStyle(context, size: 14, height: 1.65),
          decoration: inputDecoration(
            state,
            hint: '在此输入全局系统提示词...',
          ).copyWith(contentPadding: const EdgeInsets.all(18)),
          onChanged: state.updateSystemPrompt,
        ),
      ),
      const SizedBox(height: 12),
      SoftButton(
        state: state,
        label: '恢复默认提示词',
        onTap: () {
          systemPromptController.text = defaultSystemInstruction;
          state.updateSystemPrompt(defaultSystemInstruction);
        },
      ),
    ]);
  }

  Widget memoryView() {
    final state = widget.state;
    return scrollContent([
      Text(
        'AI将会记住关于您的重要信息，以便提供更个性化的回应。',
        textAlign: TextAlign.center,
        style: state.textStyle(context, size: 13, opacity: 0.55),
      ),
      const SizedBox(height: 22),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '全局记忆',
              subtitle: '将记录的记忆应用于所有对话',
              trailing: WeaveSwitch(
                state: state,
                value: state.globalMemoryEnabled,
                onChanged: state.setGlobalMemoryEnabled,
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '参考历史记忆',
              subtitle: '将最近的历史聊天用于当前上下文',
              trailing: WeaveSwitch(
                state: state,
                value: state.referenceHistoryEnabled,
                onChanged: state.setReferenceHistoryEnabled,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '用户记忆'),
      if (state.memories.isEmpty)
        CardShell(
          state: state,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Center(
            child: Text(
              '暂无记忆',
              style: state.textStyle(context, size: 13, opacity: 0.42),
            ),
          ),
        )
      else
        for (var i = 0; i < state.memories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardShell(
              state: state,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: state.accents[0].withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: state.text(context).withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.memories[i],
                      style: state.textStyle(context, size: 14, height: 1.45),
                    ),
                  ),
                  TinyIcon(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: () => state.deleteMemory(i),
                  ),
                ],
              ),
            ),
          ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '手动添加记忆'),
      CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: memoryController,
                style: state.textStyle(context, size: 14),
                decoration: inputDecoration(state, hint: '输入需要记住的信息...'),
                onSubmitted: (_) => addMemory(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              child: SoftButton(
                state: state,
                label: '添加',
                icon: Icons.add_rounded,
                accent: true,
                onTap: addMemory,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      SoftButton(
        state: state,
        label: '清空所有记忆',
        icon: Icons.delete_sweep_outlined,
        danger: true,
        onTap: state.clearMemories,
      ),
    ]);
  }

  Widget providerConfigView() {
    final state = widget.state;
    final content = [
      SegmentedPills(
        state: state,
        value: providerTab,
        items: const {'config': '配置', 'models': '模型'},
        onChanged: (value) => updateSheet(() => providerTab = value),
      ),
      const SizedBox(height: 24),
      Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: state.text(context).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.cloud_outlined,
                size: 32,
                color: state.text(context).withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 14),
            if (editingProvider == null)
              SizedBox(
                width: 220,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: TextEditingController(text: providerName)
                    ..selection = TextSelection.collapsed(
                      offset: providerName.length,
                    ),
                  onChanged: (value) => providerName = value,
                  style: state.textStyle(
                    context,
                    size: 20,
                    weight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: '自定义提供商名称',
                    border: UnderlineInputBorder(),
                  ),
                ),
              )
            else
              Text(
                providerName,
                style: state.textStyle(
                  context,
                  size: 20,
                  weight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '配置此提供商的API凭据以启用相关模型',
              style: state.textStyle(context, size: 13, opacity: 0.52),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      if (providerTab == 'config') ...[
        Text(
          'API Key',
          style: state.textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: providerKey)
            ..selection = TextSelection.collapsed(offset: providerKey.length),
          obscureText: true,
          onChanged: (value) => providerKey = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(state, hint: '请输入 Provider API Key...'),
        ),
        const SizedBox(height: 18),
        Text(
          'Base URL (可选)',
          style: state.textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: providerBaseUrl)
            ..selection = TextSelection.collapsed(
              offset: providerBaseUrl.length,
            ),
          onChanged: (value) => providerBaseUrl = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(
            state,
            hint: 'https://api.example.com/v1',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'API Key 仅存储在本机 SharedPreferences 中，不会被发送给除所选模型服务外的第三方。',
          style: state.textStyle(
            context,
            size: 11,
            opacity: 0.42,
            height: 1.45,
          ),
        ),
      ] else ...[
        if (providerModels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              '暂无可用模型，请拉取或手动添加',
              textAlign: TextAlign.center,
              style: state.textStyle(context, size: 13, opacity: 0.42),
            ),
          )
        else
          for (final model in providerModels)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardShell(
                state: state,
                child: SettingsRow(
                  state: state,
                  title: model.name,
                  subtitle: model.id,
                  leading: Icon(
                    Icons.memory_rounded,
                    color: state.text(context).withValues(alpha: 0.55),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TinyIcon(
                        icon: Icons.edit_outlined,
                        color: state.text(context),
                        onTap: () => editModel(model),
                      ),
                      TinyIcon(
                        icon: Icons.close_rounded,
                        color: Colors.red,
                        onTap: () => updateSheet(
                          () => providerModels = providerModels
                              .where((m) => m.id != model.id)
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    ];

    return bottomActionPage(
      children: content,
      status: statusText,
      actions: providerTab == 'config'
          ? Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '保存配置',
                    accent: true,
                    onTap: () => saveProvider(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '启用',
                    onTap: () => saveProvider(true),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '添加模型',
                    icon: Icons.add_rounded,
                    accent: true,
                    onTap: addManualModel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '拉取',
                    onTap: pullModels,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '测试',
                    onTap: testProvider,
                  ),
                ),
              ],
            ),
    );
  }

  Widget modelRoleConfigView() {
    final state = widget.state;
    final providers = state.providers;
    final providerModels =
        providers
            .firstWhereOrNull((p) => p.name == roleDraft.provider)
            ?.models ??
        const <AiModel>[];
    return scrollContent([
      SectionLabel(state: state, label: '默认模型'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownField(
              state: state,
              label: '提供商',
              value: roleDraft.provider.isEmpty ? '未选择' : roleDraft.provider,
              items: ['未选择', ...providers.map((p) => p.name)],
              onChanged: (value) => updateSheet(() {
                roleDraft = roleDraft.copyWith(
                  provider: value == '未选择' ? '' : value,
                  model: '',
                );
              }),
            ),
            const SizedBox(height: 14),
            DropdownField(
              state: state,
              label: '模型',
              value: roleDraft.model.isEmpty ? '未选择' : roleDraft.model,
              items: ['未选择', ...providerModels.map((m) => m.name)],
              enabled: roleDraft.provider.isNotEmpty,
              onChanged: (value) => updateSheet(() {
                roleDraft = roleDraft.copyWith(
                  model: value == '未选择' ? '' : value,
                );
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '系统提示词 (System Prompt)'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: TextEditingController(text: roleDraft.prompt)
                ..selection = TextSelection.collapsed(
                  offset: roleDraft.prompt.length,
                ),
              maxLines: 7,
              style: state.textStyle(context, size: 14, height: 1.55),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '输入自定义提示词...',
              ),
              onChanged: (value) =>
                  roleDraft = roleDraft.copyWith(prompt: value),
            ),
            DividerLine(state: state),
            Row(
              children: [
                Text(
                  '${roleDraft.prompt.length} 字符',
                  style: state.textStyle(context, size: 11, opacity: 0.42),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => updateSheet(() {
                    roleDraft = roleDraft.copyWith(
                      prompt: ModelAssignment.defaults()[editingRole]!.prompt,
                    );
                  }),
                  child: const Text('恢复默认'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      SoftButton(
        state: state,
        label: '保存设置',
        accent: true,
        onTap: () {
          if (editingRole != null) {
            state.saveModelAssignment(editingRole!, roleDraft);
          }
          goBack();
        },
      ),
    ]);
  }

  Widget searchConfigView() {
    final state = widget.state;
    return scrollContent([
      Text(
        '配置默认的搜索引擎与对应的API Key。您可以自行注册并获取各个厂商的密钥。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 20),
      for (final engine in SettingsSheetState.settingsEngines)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CardShell(
            state: state,
            padding: const EdgeInsets.all(16),
            borderColor: state.searchConfig.active == engine.$1
                ? state.accents[0]
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => state.saveSearchConfig(
                    state.searchConfig.copyWith(active: engine.$1),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        RadioDot(
                          active: state.searchConfig.active == engine.$1,
                          color: state.accents[0],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          engine.$2,
                          style: state.textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.searchConfig.active == engine.$1) ...[
                  const SizedBox(height: 16),
                  DividerLine(state: state),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    controller: TextEditingController(
                      text: state.searchConfig.keys[engine.$1] ?? '',
                    ),
                    onChanged: (value) {
                      state.saveSearchConfig(
                        state.searchConfig.copyWith(
                          keys: {...state.searchConfig.keys, engine.$1: value},
                        ),
                      );
                    },
                    style: state.textStyle(context, size: 14),
                    decoration: inputDecoration(
                      state,
                      hint: '输入 ${engine.$2} 的 API Key',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    engine.$3,
                    style: state.textStyle(context, size: 12, opacity: 0.42),
                  ),
                ],
              ],
            ),
          ),
        ),
    ]);
  }

  Widget ttsConfigView() {
    final state = widget.state;
    var draft =
        editingTts ??
        TtsProviderConfig(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          type: 'openai',
          name: '自定义 TTS',
          apiKey: '',
          baseUrl: '',
          model: '',
          voice: '',
        );
    return StatefulBuilder(
      builder: (context, setLocal) {
        Widget field({
          required String label,
          required String value,
          required ValueChanged<String> onChanged,
          String hint = '',
          bool obscure = false,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: state.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                  opacity: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
                obscureText: obscure,
                onChanged: (value) => setLocal(() => onChanged(value)),
                style: state.textStyle(context, size: 15),
                decoration: inputDecoration(state, hint: hint),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        return scrollContent([
          Text(
            '提供商类型',
            style: state.textStyle(
              context,
              size: 14,
              weight: FontWeight.w600,
              opacity: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.type,
            decoration: inputDecoration(state),
            items: const [
              DropdownMenuItem(value: 'xiaomi', child: Text('Xiaomi MiMo TTS')),
              DropdownMenuItem(value: 'openai', child: Text('OpenAI TTS')),
              DropdownMenuItem(value: 'azure', child: Text('Azure TTS')),
              DropdownMenuItem(value: 'edge', child: Text('Edge TTS')),
              DropdownMenuItem(value: 'custom', child: Text('自定义 (Custom)')),
            ],
            onChanged: (value) => setLocal(() {
              draft = draft.copyWith(type: value ?? draft.type);
              editingTts = draft;
            }),
          ),
          const SizedBox(height: 16),
          field(
            label: '显示名称',
            value: draft.name,
            hint: '例如：OpenAI 语音',
            onChanged: (value) {
              draft = draft.copyWith(name: value);
              editingTts = draft;
            },
          ),
          if (draft.type != 'edge')
            field(
              label: 'API Key',
              value: draft.apiKey,
              hint: 'Bearer Token 或 API 密钥',
              obscure: true,
              onChanged: (value) {
                draft = draft.copyWith(apiKey: value);
                editingTts = draft;
              },
            ),
          field(
            label: 'Base URL',
            value: draft.baseUrl,
            hint: 'https://api.openai.com/v1',
            onChanged: (value) {
              draft = draft.copyWith(baseUrl: value);
              editingTts = draft;
            },
          ),
          field(
            label: '模型名称 (Model)',
            value: draft.model,
            hint: '例如: tts-1, tts-1-hd',
            onChanged: (value) {
              draft = draft.copyWith(model: value);
              editingTts = draft;
            },
          ),
          field(
            label: '合成语音 (Voice)',
            value: draft.voice,
            hint: '例如: alloy, echo, fable',
            onChanged: (value) {
              draft = draft.copyWith(voice: value);
              editingTts = draft;
            },
          ),
          if (draft.id != 'xiaomi')
            TextButton.icon(
              onPressed: () {
                final next = state.ttsProviders
                    .where((t) => t.id != draft.id)
                    .toList();
                state.saveTtsConfig(
                  next,
                  state.activeTtsId == draft.id ? 'system' : state.activeTtsId,
                );
                goBack();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除此提供商'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          const SizedBox(height: 12),
          SoftButton(
            state: state,
            label: '保存设置',
            accent: true,
            onTap: () {
              final next = [...state.ttsProviders];
              final index = next.indexWhere((t) => t.id == draft.id);
              if (index >= 0) {
                next[index] = draft;
              } else {
                next.add(draft);
              }
              state.saveTtsConfig(next, state.activeTtsId);
              goBack();
            },
          ),
        ]);
      },
    );
  }
}
