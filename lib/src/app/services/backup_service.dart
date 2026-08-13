import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/zip_writer.dart';
import '../../domain/models.dart';

class PreparedBackup {
  const PreparedBackup({
    required this.sessions,
    required this.attachmentEntries,
    required this.omittedAttachments,
  });

  final List<ChatSession> sessions;
  final List<ZipEntryData> attachmentEntries;
  final int omittedAttachments;
}

class DecodedBackup {
  const DecodedBackup({required this.json, required this.entries});

  final String json;
  final Map<String, Uint8List> entries;
}

class BackupService {
  const BackupService();

  static const int maxArchiveBytes = 32 * 1024 * 1024;
  static const int maxJsonBytes = 16 * 1024 * 1024;
  static const int maxAttachmentBytes = 16 * 1024 * 1024;
  static const int maxEntryBytes = 8 * 1024 * 1024;
  static const String attachmentScheme = 'weaview-backup://';

  PreparedBackup prepareSessions(List<ChatSession> sessions) {
    final attachmentEntries = <ZipEntryData>[];
    final backupPathBySource = <String, String>{};
    var attachmentBytes = 0;
    var omittedAttachments = 0;
    var attachmentIndex = 0;
    final backupSessions = <ChatSession>[];

    for (final session in sessions) {
      final backupMessages = <ChatMessage>[];
      for (final message in session.messages) {
        final backupAttachments = <MessageAttachment>[];
        for (final attachment in message.attachments) {
          try {
            final source = File(attachment.path);
            if (!source.existsSync()) {
              omittedAttachments++;
              continue;
            }
            var backupPath = backupPathBySource[source.absolute.path];
            if (backupPath == null) {
              final length = source.lengthSync();
              if (length > maxEntryBytes ||
                  attachmentBytes + length > maxAttachmentBytes) {
                omittedAttachments++;
                continue;
              }
              final bytes = source.readAsBytesSync();
              if (bytes.length > maxEntryBytes ||
                  attachmentBytes + bytes.length > maxAttachmentBytes) {
                omittedAttachments++;
                continue;
              }
              final safeName = safeAttachmentName(attachment.name);
              final entryName =
                  'attachments/${attachmentIndex.toString().padLeft(4, '0')}_$safeName';
              backupPath = '$attachmentScheme$entryName';
              backupPathBySource[source.absolute.path] = backupPath;
              attachmentEntries.add(
                ZipEntryData(name: entryName, bytes: bytes),
              );
              attachmentBytes += bytes.length;
              attachmentIndex++;
            }
            backupAttachments.add(attachment.copyWith(path: backupPath));
          } on FileSystemException {
            omittedAttachments++;
          } on ArgumentError {
            omittedAttachments++;
          }
        }
        backupMessages.add(message.copy()..attachments = backupAttachments);
      }
      backupSessions.add(session.copyWith(messages: backupMessages));
    }

    return PreparedBackup(
      sessions: backupSessions,
      attachmentEntries: attachmentEntries,
      omittedAttachments: omittedAttachments,
    );
  }

  Uint8List buildArchive({
    required String json,
    required PreparedBackup prepared,
    DateTime? exportedAt,
  }) {
    ensureJsonWithinLimit(json);
    final archive = buildStoredZip([
      ZipEntryData(name: 'weaview-export.json', bytes: utf8.encode(json)),
      ZipEntryData(
        name: 'README.txt',
        bytes: utf8.encode(
          'Weaview local data export\n'
          'Exported at: ${(exportedAt ?? DateTime.now()).toIso8601String()}\n'
          'Format: UTF-8 JSON + attachment files\n'
          'Included attachments: ${prepared.attachmentEntries.length}\n'
          'Omitted missing or oversized attachments: ${prepared.omittedAttachments}\n',
        ),
      ),
      ...prepared.attachmentEntries,
    ]);
    if (archive.length > maxArchiveBytes) {
      throw FormatException('备份文件超过 ${formatLimit(maxArchiveBytes)} 限制。');
    }
    return archive;
  }

  DecodedBackup decode(Uint8List bytes, {String fileName = ''}) {
    if (bytes.length > maxArchiveBytes) {
      throw FormatException('备份文件超过 ${formatLimit(maxArchiveBytes)} 限制。');
    }
    final lowerName = fileName.toLowerCase();
    final isZip =
        lowerName.endsWith('.zip') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4B &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04);
    final entries = isZip
        ? readZipEntries(
            bytes,
            maxEntries: 512,
            maxEntryCompressedBytes: maxJsonBytes,
            maxEntryUncompressedBytes: maxJsonBytes,
            maxTotalUncompressedBytes: maxArchiveBytes,
          )
        : const <String, Uint8List>{};
    final jsonBytes = isZip ? entries['weaview-export.json'] : bytes;
    if (jsonBytes == null || jsonBytes.isEmpty) {
      throw const FormatException('备份文件中未找到 weaview-export.json。');
    }
    if (jsonBytes.length > maxJsonBytes) {
      throw FormatException('备份 JSON 超过 ${formatLimit(maxJsonBytes)} 限制。');
    }
    return DecodedBackup(
      json: utf8.decode(jsonBytes, allowMalformed: true),
      entries: entries,
    );
  }

  void ensureJsonWithinLimit(String json) {
    if (utf8.encode(json).length > maxJsonBytes) {
      throw FormatException('备份 JSON 超过 ${formatLimit(maxJsonBytes)} 限制。');
    }
  }

  Future<List<ChatSession>> restoreAttachments(
    List<ChatSession> sessions,
    Map<String, Uint8List> backupEntries, {
    required Future<Directory> Function() generatedImagesDirectory,
    required String Function(Directory directory, String preferredName)
    uniqueName,
  }) async {
    Directory? restoreDirectory;
    final restoredPathByEntry = <String, String>{};
    final restoredSessions = <ChatSession>[];
    for (final session in sessions) {
      final restoredMessages = <ChatMessage>[];
      for (final message in session.messages) {
        final restoredAttachments = <MessageAttachment>[];
        for (final attachment in message.attachments) {
          final path = attachment.path.trim();
          if (!path.startsWith(attachmentScheme)) {
            // Imported JSON must never grant a backup access to arbitrary
            // existing files on the destination device. Only embedded ZIP
            // entries are eligible for restoration.
            continue;
          }
          final entryName = path.substring(attachmentScheme.length);
          final bytes = backupEntries[entryName];
          if (bytes == null || bytes.length > maxEntryBytes) continue;
          var restoredPath = restoredPathByEntry[entryName];
          if (restoredPath == null) {
            restoreDirectory ??= Directory(
              '${(await generatedImagesDirectory()).path}'
              '${Platform.pathSeparator}restored_attachments',
            );
            await restoreDirectory.create(recursive: true);
            final target = File(
              '${restoreDirectory.path}${Platform.pathSeparator}'
              '${uniqueName(restoreDirectory, safeAttachmentName(attachment.name))}',
            );
            await target.writeAsBytes(bytes, flush: true);
            restoredPath = target.path;
            restoredPathByEntry[entryName] = restoredPath;
          }
          restoredAttachments.add(
            attachment.copyWith(path: restoredPath, size: bytes.length),
          );
        }
        restoredMessages.add(message.copy()..attachments = restoredAttachments);
      }
      restoredSessions.add(session.copyWith(messages: restoredMessages));
    }
    return restoredSessions;
  }

  String safeAttachmentName(String value) {
    final safe = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return safe.isEmpty
        ? 'attachment_${DateTime.now().millisecondsSinceEpoch}.bin'
        : safe;
  }

  String formatLimit(int bytes) {
    final megaBytes = bytes / (1024 * 1024);
    return megaBytes == megaBytes.roundToDouble()
        ? '${megaBytes.toInt()} MB'
        : '${megaBytes.toStringAsFixed(1)} MB';
  }
}
