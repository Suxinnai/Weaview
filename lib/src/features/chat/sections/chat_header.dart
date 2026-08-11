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
    final selectorWidth = (MediaQuery.sizeOf(context).width - 112).clamp(
      196.0,
      270.0,
    );
    final dark = state.isDark(context);
    final borderColor = state
        .text(context)
        .withValues(alpha: dark ? 0.1 : 0.09);
    final glassColor = state
        .layer(context)
        .withValues(alpha: dark ? 0.58 : 0.54);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 12,
                  child: _HeaderGlass(
                    state: state,
                    width: 44,
                    radius: 17,
                    borderColor: borderColor,
                    glassColor: glassColor,
                    child: IconCircleButton(
                      icon: Icons.menu_rounded,
                      onTap: onOpenSidebar,
                      color: state.text(context),
                      size: 44,
                      opacity: 0.72,
                    ),
                  ),
                ),
                _HeaderGlass(
                  state: state,
                  width: selectorWidth,
                  radius: 18,
                  borderColor: borderColor,
                  glassColor: glassColor,
                  child: Tooltip(
                    message: '选择模型',
                    child: Semantics(
                      button: true,
                      expanded: modelDropdownOpen,
                      label: '选择模型，当前$modelLabel',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleModelDropdown,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: state.accents[0],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: state.accents[0].withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.messages.isNotEmpty
                                            ? state.chatSessions
                                                      .firstWhereOrNull(
                                                        (session) =>
                                                            session.id ==
                                                            state
                                                                .currentSessionId,
                                                      )
                                                      ?.title ??
                                                  '未命名梦境'
                                            : '新梦境',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        modelLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 10,
                                          weight: FontWeight.w500,
                                          opacity: 0.54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: modelDropdownOpen ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 19,
                                    color: state
                                        .text(context)
                                        .withValues(alpha: 0.48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class _HeaderGlass extends StatelessWidget {
  const _HeaderGlass({
    required this.state,
    required this.width,
    required this.radius,
    required this.borderColor,
    required this.glassColor,
    required this.child,
  });

  final WeaviewState state;
  final double width;
  final double radius;
  final Color borderColor;
  final Color glassColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: state.isDark(context) ? 0.16 : 0.045,
            ),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
