import '../../domain/message_attachment.dart';

const int maxChatAttachmentCount = 8;
const int maxChatAttachmentBytes = 10 * 1024 * 1024;
const String maxChatAttachmentSizeLabel = '10MB';

class AttachmentLimitResult {
  const AttachmentLimitResult({
    required this.accepted,
    required this.rejectedOversized,
    required this.rejectedOverflow,
  });

  final List<MessageAttachment> accepted;
  final List<MessageAttachment> rejectedOversized;
  final List<MessageAttachment> rejectedOverflow;

  bool get hasRejections =>
      rejectedOversized.isNotEmpty || rejectedOverflow.isNotEmpty;

  String? get message {
    final parts = <String>[];
    if (rejectedOversized.isNotEmpty) {
      parts.add(
        '${rejectedOversized.length} 个文件超过 $maxChatAttachmentSizeLabel，已跳过',
      );
    }
    if (rejectedOverflow.isNotEmpty) {
      parts.add(
        '最多上传 $maxChatAttachmentCount 个文件，已跳过 ${rejectedOverflow.length} 个',
      );
    }
    if (parts.isEmpty) return null;
    return '${parts.join('；')}。';
  }
}

AttachmentLimitResult applyChatAttachmentLimits({
  required int existingCount,
  required List<MessageAttachment> incoming,
}) {
  final remainingSlots = (maxChatAttachmentCount - existingCount).clamp(
    0,
    maxChatAttachmentCount,
  );
  final rejectedOversized = <MessageAttachment>[];
  final sizeAccepted = <MessageAttachment>[];

  for (final attachment in incoming) {
    final size = attachment.size;
    if (size != null && size > maxChatAttachmentBytes) {
      rejectedOversized.add(attachment);
    } else {
      sizeAccepted.add(attachment);
    }
  }

  final accepted = sizeAccepted.take(remainingSlots).toList();
  final rejectedOverflow = sizeAccepted.skip(remainingSlots).toList();

  return AttachmentLimitResult(
    accepted: accepted,
    rejectedOversized: rejectedOversized,
    rejectedOverflow: rejectedOverflow,
  );
}
