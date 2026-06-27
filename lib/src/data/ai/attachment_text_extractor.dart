import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/message_attachment.dart';

const int maxAttachmentTextCharacters = 30000;

class AttachmentPayloadException implements Exception {
  const AttachmentPayloadException(this.message);

  final String message;

  @override
  String toString() => '附件处理失败：$message';
}

class AttachmentTextExtraction {
  const AttachmentTextExtraction({
    required this.text,
    required this.truncated,
    required this.byteLength,
  });

  final String text;
  final bool truncated;
  final int byteLength;
}

Future<AttachmentTextExtraction?> extractAttachmentText(
  MessageAttachment attachment,
) async {
  final file = File(attachment.path);
  if (!await file.exists()) {
    throw AttachmentPayloadException(
      '“${attachment.name}”在本机已不存在，请删除该附件后重新选择文件。',
    );
  }

  if (attachment.isImage) return null;

  try {
    final byteLength = await file.length();
    if (byteLength == 0) {
      throw AttachmentPayloadException('“${attachment.name}”是空文件，没有可供模型解读的内容。');
    }

    final sampled = await _readTextSample(file, byteLength);
    final text = _decodeText(sampled.head, attachment.name);
    final tail = sampled.tail == null
        ? ''
        : _decodeText(
            sampled.tail!,
            attachment.name,
            allowLeadingFragment: true,
          );
    final combined = tail.isEmpty ? text : '$text\n\n$tail';

    if (!_isSupportedTextAttachment(attachment, sampled.head, combined)) {
      throw AttachmentPayloadException(
        '“${attachment.name}”不是可直接读取的文本文件。'
        '目前支持图片以及 TXT、Markdown、CSV、JSON、XML、YAML、HTML、代码和日志等文本格式；'
        '请先将 PDF、Office 文档或其他二进制文件导出为 TXT/Markdown 后重试。',
      );
    }

    final normalized = combined.replaceAll('\u0000', '').trim();
    if (normalized.isEmpty) {
      throw AttachmentPayloadException('“${attachment.name}”中没有检测到可读文本。');
    }
    final shortened = _truncateText(normalized);
    return AttachmentTextExtraction(
      text: shortened.text,
      truncated: sampled.tail != null || shortened.truncated,
      byteLength: byteLength,
    );
  } on AttachmentPayloadException {
    rethrow;
  } on FileSystemException catch (error) {
    throw AttachmentPayloadException(
      '无法读取“${attachment.name}”：${error.message}。请确认文件未被移动，且应用仍有访问权限。',
    );
  } on FormatException {
    throw AttachmentPayloadException(
      '“${attachment.name}”的文本编码无法识别，请将文件转换为 UTF-8 后重试。',
    );
  }
}

Future<({Uint8List head, Uint8List? tail})> _readTextSample(
  File file,
  int byteLength,
) async {
  const fullReadLimit = 1024 * 1024;
  if (byteLength <= fullReadLimit) {
    return (head: await file.readAsBytes(), tail: null);
  }

  const headBytes = 160 * 1024;
  const tailBytes = 80 * 1024;
  final handle = await file.open();
  try {
    final head = await handle.read(math.min(headBytes, byteLength));
    await handle.setPosition(math.max(0, byteLength - tailBytes));
    final tail = await handle.read(math.min(tailBytes, byteLength));
    return (head: head, tail: tail);
  } finally {
    await handle.close();
  }
}

String _decodeText(
  Uint8List bytes,
  String fileName, {
  bool allowLeadingFragment = false,
}) {
  if (bytes.isEmpty) return '';
  if (!allowLeadingFragment && bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
  }
  final withoutBom =
      !allowLeadingFragment &&
          bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? bytes.sublist(3)
      : bytes;
  try {
    return utf8.decode(withoutBom);
  } on FormatException {
    final decoded = utf8.decode(withoutBom, allowMalformed: true);
    final replacementCount = '\uFFFD'.allMatches(decoded).length;
    final tolerated = allowLeadingFragment ? 2 : 0;
    if (replacementCount > tolerated) {
      throw FormatException('Unsupported encoding for $fileName');
    }
    return decoded;
  }
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

bool _isSupportedTextAttachment(
  MessageAttachment attachment,
  Uint8List bytes,
  String decoded,
) {
  final mime = attachment.mimeType.split(';').first.trim().toLowerCase();
  final name = attachment.name.toLowerCase();
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1);
  if (_binaryMimeTypes.contains(mime) ||
      _binaryExtensions.contains(extension)) {
    return false;
  }
  if (mime.startsWith('text/') || _textMimeTypes.contains(mime)) return true;
  if (_textExtensions.contains(extension)) return true;

  final nulCount = bytes.where((byte) => byte == 0).length;
  if (nulCount > math.max(2, bytes.length ~/ 100)) return false;
  if (decoded.isEmpty) return false;
  final controlCount = decoded.runes.where((rune) {
    return rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D;
  }).length;
  return controlCount <= math.max(2, decoded.runes.length ~/ 100);
}

({String text, bool truncated}) _truncateText(String text) {
  final characters = text.runes.toList();
  if (characters.length <= maxAttachmentTextCharacters) {
    return (text: text, truncated: false);
  }
  const headCharacters = 20000;
  const tailCharacters = maxAttachmentTextCharacters - headCharacters;
  final head = String.fromCharCodes(characters.take(headCharacters));
  final tail = String.fromCharCodes(
    characters.skip(characters.length - tailCharacters),
  );
  return (text: '$head\n\n[……中间内容因上下文长度限制已省略……]\n\n$tail', truncated: true);
}

const _textMimeTypes = {
  'application/json',
  'application/ld+json',
  'application/xml',
  'application/javascript',
  'application/x-javascript',
  'application/x-yaml',
  'application/yaml',
  'application/toml',
  'application/sql',
  'application/rtf',
};

const _textExtensions = {
  'txt',
  'md',
  'markdown',
  'csv',
  'tsv',
  'json',
  'jsonl',
  'xml',
  'yaml',
  'yml',
  'toml',
  'html',
  'htm',
  'css',
  'js',
  'mjs',
  'cjs',
  'ts',
  'tsx',
  'jsx',
  'dart',
  'java',
  'kt',
  'kts',
  'py',
  'go',
  'rs',
  'c',
  'h',
  'cc',
  'cpp',
  'hpp',
  'cs',
  'rb',
  'php',
  'sh',
  'bash',
  'zsh',
  'ps1',
  'sql',
  'log',
  'ini',
  'cfg',
  'conf',
  'properties',
  'env',
  'tex',
  'rtf',
  'srt',
  'vtt',
  'gradle',
  'gitignore',
};

const _binaryMimeTypes = {
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/zip',
  'application/x-rar-compressed',
  'application/x-7z-compressed',
};

const _binaryExtensions = {
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'zip',
  'rar',
  '7z',
  'epub',
  'pages',
  'numbers',
  'key',
};
