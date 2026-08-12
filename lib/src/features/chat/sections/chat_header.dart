import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../core/app_utils.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.state,
    required this.modelDropdownOpen,
    required this.imageGenerationMode,
    required this.onOpenSidebar,
    required this.onToggleModelDropdown,
  });

  final WeaviewState state;
  final bool modelDropdownOpen;
  final bool imageGenerationMode;
  final VoidCallback onOpenSidebar;
  final VoidCallback onToggleModelDropdown;

  @override
  Widget build(BuildContext context) {
    final activeAssignment = imageGenerationMode
        ? state.modelAssignments['image']
        : state.modelAssignments['chat'];
    final activeModel = activeAssignment?.model.trim() ?? '';
    final modelLabel = activeModel.isEmpty
        ? (imageGenerationMode ? '未选择生图模型' : '未选择模型')
        : (imageGenerationMode ? '生图 · $activeModel' : activeModel);
    final sessionTitle = state.messages.isNotEmpty
        ? state.chatSessions
                  .firstWhereOrNull(
                    (session) => session.id == state.currentSessionId,
                  )
                  ?.title ??
              '未命名梦境'
        : '新梦境';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 14,
                  child: _FrostedCircle(
                    state: state,
                    size: 40,
                    child: IconCircleButton(
                      icon: Icons.menu_rounded,
                      onTap: onOpenSidebar,
                      color: state.text(context),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  expanded: modelDropdownOpen,
                  label: '选择模型，当前$modelLabel',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleModelDropdown,
                    child: _ModelChip(
                      state: state,
                      open: modelDropdownOpen,
                      sessionTitle: sessionTitle,
                      modelLabel: modelLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedCircle extends StatelessWidget {
  const _FrostedCircle({
    required this.state,
    required this.size,
    required this.child,
  });

  final WeaviewState state;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: state
                .layer(context)
                .withValues(alpha: state.isDark(context) ? 0.5 : 0.55),
            border: Border.all(
              color: state.text(context).withValues(alpha: 0.08),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.state,
    required this.open,
    required this.sessionTitle,
    required this.modelLabel,
  });

  final WeaviewState state;
  final bool open;
  final String sessionTitle;
  final String modelLabel;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 272, minHeight: 40),
          padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
          decoration: BoxDecoration(
            color: state
                .layer(context)
                .withValues(alpha: dark ? 0.52 : 0.58),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: state.text(context).withValues(
                alpha: open ? 0.16 : 0.08,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.18 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: state.accents[0],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: state.accents[0].withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: state.text(context).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Text(
                  modelLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state
                      .textStyle(
                        context,
                        size: 10.5,
                        weight: FontWeight.w500,
                        opacity: 0.62,
                      )
                      .copyWith(letterSpacing: 0.4),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: open ? -0.25 : 0.25,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: state.text(context).withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
