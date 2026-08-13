import 'package:mime/mime.dart';

class MessageAttachment {
  const MessageAttachment({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.kind,
    this.size,
    this.pixelWidth,
    this.pixelHeight,
  });

  factory MessageAttachment.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return MessageAttachment(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? '未命名文件',
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
      kind: map['kind']?.toString() == 'image' ? 'image' : 'file',
      size: (map['size'] as num?)?.toInt(),
      pixelWidth: (map['pixelWidth'] as num?)?.toInt(),
      pixelHeight: (map['pixelHeight'] as num?)?.toInt(),
    );
  }

  final String path;
  final String name;
  final String mimeType;
  final String kind;
  final int? size;
  final int? pixelWidth;
  final int? pixelHeight;

  bool get hasPixelSize => (pixelWidth ?? 0) > 0 && (pixelHeight ?? 0) > 0;

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
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
  );

  MessageAttachment copyWith({
    String? path,
    String? name,
    String? mimeType,
    String? kind,
    int? size,
    int? pixelWidth,
    int? pixelHeight,
  }) {
    return MessageAttachment(
      path: path ?? this.path,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'mimeType': mimeType,
    'kind': kind,
    'size': size,
    if (pixelWidth != null) 'pixelWidth': pixelWidth,
    if (pixelHeight != null) 'pixelHeight': pixelHeight,
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
