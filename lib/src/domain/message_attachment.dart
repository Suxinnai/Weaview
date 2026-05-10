import 'package:mime/mime.dart';

class MessageAttachment {
  const MessageAttachment({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.kind,
    this.size,
  });

  factory MessageAttachment.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return MessageAttachment(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? '未命名文件',
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
      kind: map['kind']?.toString() == 'image' ? 'image' : 'file',
      size: (map['size'] as num?)?.toInt(),
    );
  }

  final String path;
  final String name;
  final String mimeType;
  final String kind;
  final int? size;

  bool get isImage =>
      kind == 'image' ||
      mimeType.startsWith('image/') ||
      _normalizedImageMimeType(lookupMimeType(path)) != null ||
      _normalizedImageMimeType(lookupMimeType(name)) != null;

  String resolvedImageMimeType({List<int>? headerBytes}) {
    return _normalizedImageMimeType(mimeType) ??
        _normalizedImageMimeType(
          lookupMimeType(path, headerBytes: headerBytes),
        ) ??
        _normalizedImageMimeType(
          lookupMimeType(name, headerBytes: headerBytes),
        ) ??
        'image/png';
  }

  MessageAttachment copy() => MessageAttachment(
    path: path,
    name: name,
    mimeType: mimeType,
    kind: kind,
    size: size,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'mimeType': mimeType,
    'kind': kind,
    'size': size,
  };
}

String? _normalizedImageMimeType(String? value) {
  final mime = value?.split(';').first.trim().toLowerCase();
  if (mime == null || mime.isEmpty || !mime.startsWith('image/')) {
    return null;
  }
  return switch (mime) {
    'image/jpg' => 'image/jpeg',
    'image/pjpeg' => 'image/jpeg',
    'image/x-png' => 'image/png',
    _ => mime,
  };
}
