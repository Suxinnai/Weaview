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
