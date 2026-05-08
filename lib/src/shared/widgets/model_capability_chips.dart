import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';

class ModelCapabilityChips extends StatelessWidget {
  const ModelCapabilityChips({
    super.key,
    required this.state,
    required this.capabilities,
    this.compact = false,
  });

  final WeaviewState state;
  final List<String> capabilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final caps = capabilities.isEmpty ? const ['chat'] : capabilities;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final cap in caps)
          _CapabilityChip(state: state, cap: cap, compact: compact),
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.state,
    required this.cap,
    required this.compact,
  });

  final WeaviewState state;
  final String cap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = switch (cap) {
      'vision' => (Icons.image_search_outlined, '视觉', const Color(0xFF60A5FA)),
      'image' => (Icons.image_outlined, '图像', const Color(0xFFA78BFA)),
      'tool' => (Icons.build_outlined, '工具', const Color(0xFFF59E0B)),
      'reason' => (Icons.psychology_outlined, '推理', const Color(0xFF34D399)),
      'chat' => (
        Icons.chat_bubble_outline_rounded,
        '聊天',
        const Color(0xFF38BDF8),
      ),
      _ => (Icons.tune_rounded, cap, state.accents[0]),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: meta.$3.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            meta.$1,
            size: compact ? 13 : 15,
            color: state.text(context).withValues(alpha: 0.72),
          ),
          const SizedBox(width: 4),
          Text(
            meta.$2,
            style: state.textStyle(
              context,
              size: compact ? 10.5 : 11.5,
              weight: FontWeight.w700,
              opacity: 0.74,
            ),
          ),
        ],
      ),
    );
  }
}
