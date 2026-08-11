import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/message_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('message bubble exposes explicit action toggle', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MessageBubble(
                state: state,
                message: ChatMessage.user('请帮我总结这段内容'),
                index: 0,
                assistantAvatar: '',
                userAvatar: '',
                onCopy: () {},
                onRetry: () {},
                onEdit: () {},
                onTranslate: () {},
                onBranch: () {},
                onSaveCard: () {},
                onDelete: () {},
                onSpeak: () {},
                onDownloadAttachment: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('message-action-toggle-user-0')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('message-action-toggle-user-0')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    final toggleSize = tester.getSize(
      find.byKey(const ValueKey('message-action-toggle-user-0')),
    );
    final actionBarSize = tester.getSize(
      find.byKey(const ValueKey('message-action-bar')),
    );
    expect(toggleSize.width, lessThanOrEqualTo(40));
    expect(actionBarSize.width, lessThan(220));
    expect(actionBarSize.height, lessThanOrEqualTo(44));

    state.dispose();
  });

  testWidgets('assistant action toggle opens actions without double toggling', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MessageBubble(
                state: state,
                message: ChatMessage.model('这是助手回复'),
                index: 0,
                assistantAvatar: '',
                userAvatar: '',
                onCopy: () {},
                onRetry: () {},
                onEdit: () {},
                onTranslate: () {},
                onBranch: () {},
                onSaveCard: () {},
                onDelete: () {},
                onSpeak: () {},
                onDownloadAttachment: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(
      const ValueKey('message-action-toggle-assistant-0'),
    );
    expect(toggle, findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    state.dispose();
  });

  testWidgets('request errors use a compact actionable card', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();
    var retried = false;
    var choseModel = false;
    const rawError =
        '连接织线时出现了问题：HTTP 410: {"title":"Gone",'
        '"detail":"The model \'deepseek-v4-flash\' has reached its end of life '
        'and is no longer available."}\n\n请检查网络、API Key 或模型配置后重试。';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MessageBubble(
                state: state,
                message: ChatMessage.model(rawError, activity: 'requestError'),
                index: 0,
                assistantAvatar: '',
                userAvatar: '',
                onCopy: () {},
                onRetry: () => retried = true,
                onEdit: () {},
                onTranslate: () {},
                onBranch: () {},
                onSaveCard: () {},
                onDelete: () {},
                onSpeak: () {},
                onChooseModel: () => choseModel = true,
                onDownloadAttachment: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('模型已停止服务'), findsOneWidget);
    expect(find.textContaining('deepseek-v4-flash'), findsOneWidget);
    expect(find.textContaining('HTTP 410'), findsNothing);
    expect(
      find.byKey(const ValueKey('message-action-toggle-assistant-0')),
      findsNothing,
    );

    await tester.tap(find.text('技术详情'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 410'), findsOneWidget);

    await tester.tap(find.text('切换模型'));
    await tester.tap(find.text('重试'));
    expect(choseModel, isTrue);
    expect(retried, isTrue);

    state.dispose();
  });

  testWidgets(
    'generated image gallery exposes multi-select and preview controls',
    (WidgetTester tester) async {
      final state = WeaviewState();
      await state.load();

      const attachments = [
        MessageAttachment(
          path: 'missing-assistant-1.png',
          name: 'assistant-1.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 4,
        ),
        MessageAttachment(
          path: 'missing-assistant-2.png',
          name: 'assistant-2.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 4,
        ),
        MessageAttachment(
          path: 'missing-assistant-3.png',
          name: 'assistant-3.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 4,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                MessageBubble(
                  state: state,
                  message: ChatMessage(
                    role: 'model',
                    content: '已生成 3 张图像',
                    activity: 'imageGeneration',
                    attachments: attachments,
                  ),
                  index: 0,
                  assistantAvatar: '',
                  userAvatar: '',
                  onCopy: () {},
                  onRetry: () {},
                  onEdit: () {},
                  onTranslate: () {},
                  onBranch: () {},
                  onSaveCard: () {},
                  onDelete: () {},
                  onSpeak: () {},
                  onDownloadAttachment: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const ValueKey('generated-image-gallery')),
        findsOneWidget,
      );
      expect(find.text('已生成 3 张'), findsOneWidget);
      expect(find.text('已选 1 张'), findsOneWidget);
      expect(find.text('保存所选'), findsOneWidget);
      expect(find.text('查看大图'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('选择图片 2，共 3 张'));
      await tester.pumpAndSettle();

      expect(find.text('已选 2 张'), findsOneWidget);

      state.dispose();
    },
  );
}
