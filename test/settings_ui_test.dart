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

    expect(find.text('跟随'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('提供商'));
    await tester.pumpAndSettle();

    expect(find.text('模型提供商'), findsOneWidget);
    expect(find.textContaining('已配置'), findsOneWidget);
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

    await tester.tap(find.text('强调色'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accent_palette_sheet')), findsOneWidget);
    await tester.tap(find.text('紫罗兰'));
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

    await tester.scrollUntilVisible(
      find.text('助手头像'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('助手头像'));
    await tester.pump();
    expect(pickedAssistantAvatar, isTrue);

    expect(state.emotionEnabled, isTrue);
    await tester.tap(find.text('情绪化回应'));
    await tester.pump();
    expect(state.emotionEnabled, isFalse);
    expect(tester.takeException(), isNull);

    state.dispose();
  });
}
