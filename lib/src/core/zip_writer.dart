import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ZipEntryData {
  const ZipEntryData({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

Uint8List buildStoredZip(List<ZipEntryData> entries) {
  final output = BytesBuilder(copy: false);
  final centralDirectory = BytesBuilder(copy: false);
  var offset = 0;

  for (final entry in entries) {
    final nameBytes = utf8.encode(entry.name);
    final data = entry.bytes;
    final crc = _crc32(data);

    final local = BytesBuilder(copy: false)
      ..add(_u32(0x04034B50))
      ..add(_u16(20))
      ..add(_u16(0x0800))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u32(crc))
      ..add(_u32(data.length))
      ..add(_u32(data.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0))
      ..add(nameBytes)
      ..add(data);
    final localBytes = local.toBytes();
    output.add(localBytes);

    centralDirectory
      ..add(_u32(0x02014B50))
      ..add(_u16(20))
      ..add(_u16(20))
      ..add(_u16(0x0800))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u32(crc))
      ..add(_u32(data.length))
      ..add(_u32(data.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u32(0))
      ..add(_u32(offset))
      ..add(nameBytes);

    offset += localBytes.length;
  }

  final centralBytes = centralDirectory.toBytes();
  output
    ..add(centralBytes)
    ..add(_u32(0x06054B50))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(entries.length))
    ..add(_u16(entries.length))
    ..add(_u32(centralBytes.length))
    ..add(_u32(offset))
    ..add(_u16(0));

  return output.toBytes();
}

String? readZipUtf8Entry(
  Uint8List bytes,
  String entryName, {
  int? maxCompressedBytes,
  int? maxUncompressedBytes,
}) {
  var offset = 0;
  while (offset + 30 <= bytes.length) {
    if (_readU32(bytes, offset) != 0x04034B50) break;
    final flags = _readU16(bytes, offset + 6);
    final method = _readU16(bytes, offset + 8);
    final compressedSize = _readU32(bytes, offset + 18);
    final uncompressedSize = _readU32(bytes, offset + 22);
    final nameLength = _readU16(bytes, offset + 26);
    final extraLength = _readU16(bytes, offset + 28);
    final nameStart = offset + 30;
    final dataStart = nameStart + nameLength + extraLength;
    final dataEnd = dataStart + compressedSize;
    if ((flags & 0x0008) != 0) {
      throw const FormatException('暂不支持带数据描述符的 ZIP 备份。');
    }
    if (maxCompressedBytes != null && compressedSize > maxCompressedBytes) {
      throw FormatException(
        'ZIP 条目压缩体积超过 ${_formatLimit(maxCompressedBytes)} 限制。',
      );
    }
    if (maxUncompressedBytes != null &&
        uncompressedSize > maxUncompressedBytes) {
      throw FormatException(
        'ZIP 条目解压后体积超过 ${_formatLimit(maxUncompressedBytes)} 限制。',
      );
    }
    if (dataStart > bytes.length || dataEnd > bytes.length) break;

    final nameBytes = bytes.sublist(nameStart, nameStart + nameLength);
    final name = (flags & 0x0800) != 0
        ? utf8.decode(nameBytes, allowMalformed: true)
        : latin1.decode(nameBytes, allowInvalid: true);
    final normalized = name.replaceAll('\\', '/');
    final data = bytes.sublist(dataStart, dataEnd);
    if (normalized == entryName || normalized.endsWith('/$entryName')) {
      final decoded = switch (method) {
        0 => data,
        8 => ZLibDecoder(raw: true).convert(data),
        _ => throw FormatException('Unsupported zip compression: $method'),
      };
      if (maxUncompressedBytes != null &&
          decoded.length > maxUncompressedBytes) {
        throw FormatException(
          'ZIP 条目解压后体积超过 ${_formatLimit(maxUncompressedBytes)} 限制。',
        );
      }
      return utf8.decode(decoded, allowMalformed: true);
    }

    offset = dataEnd;
  }
  return null;
}

String _formatLimit(int bytes) {
  final megaBytes = bytes / (1024 * 1024);
  if (megaBytes == megaBytes.roundToDouble()) {
    return '${megaBytes.toInt()} MB';
  }
  return '${megaBytes.toStringAsFixed(1)} MB';
}

List<int> _u16(int value) => [value & 0xFF, (value >> 8) & 0xFF];

List<int> _u32(int value) => [
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

int _readU16(Uint8List bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _readU32(Uint8List bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
