import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/chat_message.dart';
import 'package:weaview_flutter/src/domain/chat_session.dart';
import 'package:weaview_flutter/src/features/history/sidebar_overlay.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('branch sessions render under their parent with 分支 label', (
    tester,
  ) async {
    final state = await _buildStateWithSessions([
      _session(id: 'main', title: '主会话', hour: 10),
      _session(id: 'branch-1', title: '分支一', parentId: 'main', hour: 9),
      _session(id: 'branch-2', title: '分支二', parentId: 'branch-1', hour: 8),
    ], currentSessionId: 'main');

    await tester.pumpWidget(_testApp(state: state));
    await tester.pumpAndSettle();

    final mainTile = find.text('主会话');
    final branchTile = find.text('分支一');
    final nestedBranchTile = find.text('分支二');

    expect(mainTile, findsOneWidget);
    expect(branchTile, findsOneWidget);
    expect(nestedBranchTile, findsOneWidget);
    expect(find.text('分支'), findsNWidgets(2));

    expect(
      tester.getTopLeft(branchTile).dy,
      greaterThan(tester.getTopLeft(mainTile).dy),
    );
    expect(
      tester.getTopLeft(branchTile).dx,
      greaterThan(tester.getTopLeft(mainTile).dx),
    );
    expect(
      tester.getTopLeft(nestedBranchTile).dx,
      greaterThan(tester.getTopLeft(branchTile).dx),
    );

    state.dispose();
  });

  testWidgets('branch hierarchy does not duplicate or drop sessions', (
    tester,
  ) async {
    final state = await _buildStateWithSessions([
      _session(id: 'main', title: '主会话', hour: 10),
      _session(id: 'branch', title: '分支会话', parentId: 'main', hour: 9),
      _session(id: 'orphan', title: '孤立分支', parentId: 'missing', hour: 8),
      _session(id: 'cycle-a', title: '循环A', parentId: 'cycle-b', hour: 7),
      _session(id: 'cycle-b', title: '循环B', parentId: 'cycle-a', hour: 6),
    ], currentSessionId: 'main');

    await tester.pumpWidget(_testApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('主会话'), findsOneWidget);
    expect(find.text('分支会话'), findsOneWidget);
    expect(find.text('孤立分支'), findsOneWidget);
    expect(find.text('循环A'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('循环B'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('循环B'), findsOneWidget);
    expect(tester.takeException(), isNull);

    state.dispose();
  });

  testWidgets('tapping a branch selects that session', (tester) async {
    final state = await _buildStateWithSessions([
      _session(id: 'main', title: '主会话', hour: 10),
      _session(id: 'branch', title: '可点击分支', parentId: 'main', hour: 9),
    ], currentSessionId: 'main');
    var closeCount = 0;

    await tester.pumpWidget(
      _testApp(state: state, onClose: () => closeCount++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('可点击分支'));
    await tester.pumpAndSettle();

    expect(state.currentSessionId, 'branch');
    expect(closeCount, 1);

    state.dispose();
  });

  testWidgets('branch groups collapse at root and nested levels', (
    tester,
  ) async {
    final state = await _buildStateWithSessions([
      _session(id: 'main', title: '可折叠主会话', hour: 10),
      _session(
        id: 'branch-1',
        title: '一级分支',
        parentId: 'main',
        hour: 9,
      ),
      _session(
        id: 'branch-2',
        title: '二级分支',
        parentId: 'branch-1',
        hour: 8,
      ),
    ], currentSessionId: 'main');

    await tester.pumpWidget(_testApp(state: state));
    await tester.pumpAndSettle();

    final rootToggle = find.byKey(const ValueKey('toggle-branches-main'));
    final nestedToggle = find.byKey(
      const ValueKey('toggle-branches-branch-1'),
    );
    expect(rootToggle, findsOneWidget);
    expect(nestedToggle, findsOneWidget);

    await tester.tap(rootToggle);
    await tester.pumpAndSettle();
    expect(find.text('一级分支'), findsNothing);
    expect(find.text('二级分支'), findsNothing);
    expect(find.byTooltip('展开分支'), findsOneWidget);

    await tester.tap(rootToggle);
    await tester.pumpAndSettle();
    expect(find.text('一级分支'), findsOneWidget);
    expect(find.text('二级分支'), findsOneWidget);

    await tester.tap(nestedToggle);
    await tester.pumpAndSettle();
    expect(find.text('一级分支'), findsOneWidget);
    expect(find.text('二级分支'), findsNothing);
    expect(find.byTooltip('展开分支'), findsOneWidget);
    expect(tester.takeException(), isNull);

    state.dispose();
  });
}

Future<WeaviewState> _buildStateWithSessions(
  List<ChatSession> sessions, {
  required String currentSessionId,
}) async {
  final state = WeaviewState();
  await state.load();
  state.chatSessions
    ..clear()
    ..addAll(sessions);
  state.currentSessionId = currentSessionId;
  return state;
}

Widget _testApp({required WeaviewState state, VoidCallback? onClose}) {
  return MaterialApp(
    home: Scaffold(
      body: SidebarOverlay(
        state: state,
        open: true,
        onClose: onClose ?? () {},
        onSettings: () {},
        onUsageStats: () {},
      ),
    ),
  );
}

ChatSession _session({
  required String id,
  required String title,
  required int hour,
  String parentId = '',
}) {
  final now = DateTime.now();
  final updated = DateTime(now.year, now.month, now.day, hour);
  return ChatSession(
    id: id,
    title: title,
    updatedAt: updated.millisecondsSinceEpoch,
    messages: [ChatMessage(role: 'user', content: 'hello')],
    parentId: parentId,
  );
}
