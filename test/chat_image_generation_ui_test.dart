import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/message_widgets.dart';
import 'package:weaview_flutter/src/features/chat/sections/chat_input_dock.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('image generation dock exposes selectable output count', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    final controller = TextEditingController(text: '生成一组海报');
    final focusNode = FocusNode();
    var selectedCount = 1;

    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: ChatInputDock(
                state: state,
                inputController: controller,
                inputFocusNode: focusNode,
                webSearchEnabled: false,
                imageGenerationMode: true,
                comparisonMode: false,
                dockExpanded: false,
                pendingAttachments: const [],
                onToggleExpanded: () {},
                onToggleWebSearch: () {},
                onToggleComparison: () {},
                onConfigureComparison: () {},
                onSubmit: () async {},
                onPickChatImages: () async {},
                onPickChatFiles: () async {},
                onRemoveAttachment: (_) {},
                onTextChanged: () {},
                onHeightChanged: (_) {},
                imageCount: selectedCount,
                onImageCountChanged: (value) {
                  setState(() => selectedCount = value);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('image-count-selector')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('image-generation-controls')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('image-count-selector'))).height,
      42,
    );

    await tester.tap(find.byKey(const ValueKey('image-count-option-4')));
    await tester.pumpAndSettle();

    expect(selectedCount, 4);

    focusNode.dispose();
    controller.dispose();
    state.dispose();
  });

  testWidgets('assistant image generation messages use grouped gallery only', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();
    const userAttachment = MessageAttachment(
      path: 'missing-note.txt',
      name: 'note.txt',
      mimeType: 'text/plain',
      kind: 'file',
      size: 4,
    );
    const assistantAttachments = [
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
                message: ChatMessage.user(
                  '这是用户附件',
                  attachments: [userAttachment],
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
              MessageBubble(
                state: state,
                message: ChatMessage(
                  role: 'model',
                  content: '已生成 3 张图像',
                  activity: 'imageGeneration',
                  attachments: assistantAttachments,
                ),
                index: 1,
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
    // The gallery intentionally owns entrance animations. A bounded pump keeps
    // this structural assertion independent from animation settling behavior.
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('generated-image-gallery')),
      findsOneWidget,
    );
    expect(find.text('已生成 3 张'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-attachment-grid')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    state.dispose();
  });
}
