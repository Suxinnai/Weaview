import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';
import 'package:weaview_flutter/src/core/zip_writer.dart';

void main() {
  test('reads valid backup zip entries within configured limits', () {
    final archive = buildStoredZip([
      ZipEntryData(
        name: 'weaview-export.json',
        bytes: utf8.encode('{"ok":true}'),
      ),
    ]);

    final text = readZipUtf8Entry(
      archive,
      'weaview-export.json',
      maxCompressedBytes: 1024,
      maxUncompressedBytes: 1024,
    );

    expect(text, '{"ok":true}');
  });

  test('rejects oversized zip entry metadata before inflating', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    try {
      await state.load();
      final archive = _fakeZipHeader(
        name: 'weaview-export.json',
        compressedSize: 32,
        uncompressedSize: WeaviewState.maxBackupJsonBytes + 1,
      );

      await expectLater(
        () => state.importBackupBytes(archive, fileName: 'backup.zip'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('解压后体积超过 16 MB'),
          ),
        ),
      );
    } finally {
      state.dispose();
    }
  });

  test('rejects zip payloads whose real inflated bytes exceed the limit', () {
    final archive = _deflatedZipWithMismatchedSize(
      name: 'weaview-export.json',
      decodedBytes: List<int>.filled(1024, 0x61),
      declaredUncompressedSize: 64,
    );

    expect(
      () => readZipUtf8Entry(
        archive,
        'weaview-export.json',
        maxCompressedBytes: 1024,
        maxUncompressedBytes: 256,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('解压后体积超过'),
        ),
      ),
    );
  });

  test('rejects oversized raw backup json payloads', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    try {
      await state.load();
      final bytes = Uint8List(WeaviewState.maxBackupJsonBytes + 1);

      await expectLater(
        () => state.importBackupBytes(bytes, fileName: 'backup.json'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('备份 JSON 超过 16 MB'),
          ),
        ),
      );
    } finally {
      state.dispose();
    }
  });

  test('exports and restores persisted preference fields in backups', () async {
    SharedPreferences.setMockInitialValues({});
    final source = WeaviewState();
    final target = WeaviewState();

    try {
      await source.load();
      source.updateSystemPrompt('你是一个严格的审稿助手。');
      source.setEmotionEnabled(false);
      source.setGlobalMemoryEnabled(false);
      source.setReferenceHistoryEnabled(true);
      source.updateAssistantAvatar('/tmp/assistant.png');
      source.updateUserAvatar('/tmp/user.png');
      source.updateUserName('测试用户');
      source.updateAssistantName('测试助手');
      source.updateUserProfile('偏好简洁，关注交付质量。');
      source.themeMode = ThemeMode.dark;
      source.backgroundOverride = const Color(0xFF101820);
      source.textOverride = const Color(0xFFF3F6FA);
      source.assistantBubbleOverride = const Color(0xFF223344);
      source.userBubbleOverride = const Color(0xFF556677);
      source.fontMood = 'serif';
      source.fontStyleMood = 'italic';
      source.fontWeightMood = 'bold';
      source.bubbleStyle = 'glass';
      source.messageAlignment = 'center';
      source.assistantBubbleOpacity = 0.24;
      source.userBubbleOpacity = 0.31;

      final exported = source.exportJson();

      await target.load();
      await target.importBackupJson(exported);

      expect(target.systemPrompt, '你是一个严格的审稿助手。');
      expect(target.emotionEnabled, isFalse);
      expect(target.globalMemoryEnabled, isFalse);
      expect(target.referenceHistoryEnabled, isTrue);
      expect(target.assistantAvatar, '/tmp/assistant.png');
      expect(target.userAvatar, '/tmp/user.png');
      expect(target.userName, '测试用户');
      expect(target.assistantName, '测试助手');
      expect(target.userProfile, '偏好简洁，关注交付质量。');
      expect(target.themeMode, ThemeMode.dark);
      expect(colorToHex(target.backgroundOverride!), '#101820');
      expect(colorToHex(target.textOverride!), '#F3F6FA');
      expect(colorToHex(target.assistantBubbleOverride!), '#223344');
      expect(colorToHex(target.userBubbleOverride!), '#556677');
      expect(target.fontMood, 'serif');
      expect(target.fontStyleMood, 'italic');
      expect(target.fontWeightMood, 'bold');
      expect(target.bubbleStyle, 'glass');
      expect(target.messageAlignment, 'center');
      expect(target.assistantBubbleOpacity, 0.24);
      expect(target.userBubbleOpacity, 0.31);
    } finally {
      source.dispose();
      target.dispose();
    }
  });
}

Uint8List _fakeZipHeader({
  required String name,
  required int compressedSize,
  required int uncompressedSize,
}) {
  final nameBytes = utf8.encode(name);
  return Uint8List.fromList([
    ..._u32(0x04034B50),
    ..._u16(20),
    ..._u16(0x0800),
    ..._u16(0),
    ..._u16(0),
    ..._u16(0),
    ..._u32(0),
    ..._u32(compressedSize),
    ..._u32(uncompressedSize),
    ..._u16(nameBytes.length),
    ..._u16(0),
    ...nameBytes,
  ]);
}

Uint8List _deflatedZipWithMismatchedSize({
  required String name,
  required List<int> decodedBytes,
  required int declaredUncompressedSize,
}) {
  final nameBytes = utf8.encode(name);
  final compressed = ZLibCodec(raw: true).encode(decodedBytes);
  return Uint8List.fromList([
    ..._u32(0x04034B50),
    ..._u16(20),
    ..._u16(0x0800),
    ..._u16(8),
    ..._u16(0),
    ..._u16(0),
    ..._u32(0),
    ..._u32(compressed.length),
    ..._u32(declaredUncompressedSize),
    ..._u16(nameBytes.length),
    ..._u16(0),
    ...nameBytes,
    ...compressed,
  ]);
}

List<int> _u16(int value) => [value & 0xFF, (value >> 8) & 0xFF];

List<int> _u32(int value) => [
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
];
