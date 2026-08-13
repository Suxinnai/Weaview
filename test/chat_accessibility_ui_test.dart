import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/message_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('message bubble reveals actions on tap without overflow toggle', (
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

    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);

    await tester.tap(find.text('请帮我总结这段内容'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    final actionBarSize = tester.getSize(
      find.byKey(const ValueKey('message-action-bar')),
    );
    expect(actionBarSize.width, lessThan(250));
    expect(actionBarSize.height, greaterThanOrEqualTo(44));

    state.dispose();
  });

  testWidgets('assistant action tap opens actions without double toggling', (
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

    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);

    await tester.tap(find.text('这是助手回复'));
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

    await tester.tap(find.text('技术详情'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 410'), findsOneWidget);

    await tester.tap(find.text('切换模型'));
    await tester.tap(find.text('重试'));
    expect(choseModel, isTrue);
    expect(retried, isTrue);

    state.dispose();
  });

  testWidgets('generated image gallery exposes a browsable multi-image stack', (
    WidgetTester tester,
  ) async {
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
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('已生成 3 张'), findsNothing);
    expect(find.text('保存所选'), findsNothing);
    expect(find.text('查看大图'), findsNothing);

    state.dispose();
  });

  testWidgets('single generated image has a finite visible result card', (
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
                message: ChatMessage(
                  role: 'model',
                  content: '',
                  activity: 'imageGeneration',
                  attachments: [
                    MessageAttachment(
                      path: 'missing-single-image.png',
                      name: 'single-image.png',
                      mimeType: 'image/png',
                      kind: 'image',
                      size: 4,
                      pixelWidth: 1600,
                      pixelHeight: 900,
                    ),
                  ],
                ),
                index: 0,
                assistantAvatar: '',
                userAvatar: '',
                onCopy: () {},
                onRetry: () {},
                onEdit: () {},
                onTranslate: () {},
                onBranch: () {},
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

    expect(tester.takeException(), isNull);
    final card = find.byKey(const ValueKey('generated-image-single'));
    expect(card, findsOneWidget);
    final size = tester.getSize(card);
    expect(size.width, greaterThan(200));
    expect(size.height, greaterThan(100));
    expect(size.width.isFinite && size.height.isFinite, isTrue);

    state.dispose();
  });

  testWidgets('multi-image stack follows the assistant-side alignment', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();

    const attachments = [
      MessageAttachment(
        path: 'missing-stack-1.png',
        name: 'stack-1.png',
        mimeType: 'image/png',
        kind: 'image',
      ),
      MessageAttachment(
        path: 'missing-stack-2.png',
        name: 'stack-2.png',
        mimeType: 'image/png',
        kind: 'image',
      ),
      MessageAttachment(
        path: 'missing-stack-3.png',
        name: 'stack-3.png',
        mimeType: 'image/png',
        kind: 'image',
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
                  content: '',
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

    final stage = find.byKey(const ValueKey('generated-image-stack-stage'));
    expect(stage, findsOneWidget);
    final stageRect = tester.getRect(stage);
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(stageRect.center.dx, lessThan(screenWidth / 2 - 20));

    state.dispose();
  });
}
