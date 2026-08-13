import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/features/settings/settings_sheet.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings general and provider pages fit a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.byKey(const ValueKey('theme_choice_system')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('提供商'));
    await tester.pumpAndSettle();

    expect(find.text('模型提供商'), findsOneWidget);
    expect(find.textContaining('已配置'), findsOneWidget);
    expect(find.text('自定义提供商'), findsNothing);
    expect(find.text('搜索提供商'), findsNothing);
    expect(find.textContaining('查看全部'), findsNothing);
    expect(find.byKey(const ValueKey('provider_menu_OpenAI')), findsNothing);

    final openAi = tester.getTopLeft(
      find.byKey(const ValueKey('provider_OpenAI')),
    );
    final gemini = tester.getTopLeft(
      find.byKey(const ValueKey('provider_Gemini')),
    );
    expect(openAi.dx, lessThan(gemini.dx));
    expect((openAi.dy - gemini.dy).abs(), lessThan(2));
    expect(tester.takeException(), isNull);

    state.dispose();
  });

  testWidgets('about page keeps one concise identity and action group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于织境'));
    await tester.pumpAndSettle();

    expect(find.text('织境 Weaview'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('反馈与建议'), findsOneWidget);
    expect(find.text('GitHub 仓库'), findsOneWidget);
    expect(find.text('发布日志'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('当前版本'), findsNothing);
    expect(find.text('发布源 GitHub'), findsNothing);
    expect(find.text('报告问题'), findsNothing);
    expect(find.text('功能建议'), findsNothing);
    expect(find.text('GitHub Issues'), findsNothing);
    expect(tester.takeException(), isNull);

    state.dispose();
  });

  testWidgets('theme, accent and nickname controls are editable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(state.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('accent_紫罗兰')));
    await tester.pumpAndSettle();
    expect(state.accents.first, const Color(0xFF7C6CF2));

    await tester.tap(find.text('昵称'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('nickname_editor_field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '新昵称');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(state.userName, '新昵称');

    expect(find.text('更多'), findsNothing);
    expect(find.text('默认模型'), findsOneWidget);
    expect(find.text('扩展服务'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('关于织境'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('assistant avatar and emotional response remain editable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var pickedAssistantAvatar = false;
    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (userAvatar) async {
            if (!userAvatar) pickedAssistantAvatar = true;
          },
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('助手头像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('助手头像'));
    await tester.pump();
    expect(pickedAssistantAvatar, isTrue);

    expect(state.emotionEnabled, isTrue);
    await tester.ensureVisible(find.text('情绪化回应'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('情绪化回应'));
    await tester.pump();
    expect(state.emotionEnabled, isFalse);
    expect(tester.takeException(), isNull);

    state.dispose();
  });

  testWidgets('role prompt keeps its editing selection across rebuilds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('默认模型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主对话模型'));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('role-prompt-field'));
    await tester.tap(field);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ABCDE',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, 'ABCDE');
    expect(editable.controller.selection.baseOffset, 2);
    expect(tester.takeException(), isNull);

    state.dispose();
  });

  testWidgets('default models expose translation and title generation roles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WeaviewState();
    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('默认模型'));
    await tester.pumpAndSettle();

    expect(find.text('核心模型'), findsOneWidget);
    expect(find.text('辅助任务'), findsOneWidget);
    expect(find.text('翻译模型'), findsOneWidget);
    expect(find.text('标题生成模型'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model_assignment_translate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('model_assignment_title')),
      findsOneWidget,
    );

    await tester.tap(find.text('翻译模型'));
    await tester.pumpAndSettle();
    expect(find.text('提供商'), findsOneWidget);
    expect(find.text('模型'), findsOneWidget);
    expect(find.byKey(const ValueKey('role-prompt-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    state.dispose();
  });
}
