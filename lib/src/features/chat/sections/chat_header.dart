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
    final sessionTitle =
        state.chatSessions
            .firstWhereOrNull((session) => session.id == state.currentSessionId)
            ?.title ??
        '新梦境';
    final activeAssignment = imageGenerationMode
        ? state.modelAssignments['image']
        : state.modelAssignments['chat'];
    final activeModel = activeAssignment?.model.trim() ?? '';
    final modelLabel = activeModel.isEmpty
        ? (imageGenerationMode ? '未选择生图模型' : '未选择模型')
        : (imageGenerationMode ? '生图 · $activeModel' : activeModel);
    final selectorWidth = (MediaQuery.sizeOf(context).width - 112).clamp(
      180.0,
      268.0,
    );
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: IconCircleButton(
                  icon: Icons.menu_rounded,
                  onTap: onOpenSidebar,
                  color: state.text(context),
                  size: 44,
                  opacity: 0.82,
                  background: state.text(context).withValues(alpha: 0.055),
                ),
              ),
              Positioned(
                right: 12,
                child: Semantics(
                  button: true,
                  label: '新建对话',
                  child: IconCircleButton(
                    icon: Icons.edit_rounded,
                    onTap: state.newSession,
                    color: state.text(context),
                    size: 44,
                    opacity: 0.82,
                    background: state.text(context).withValues(alpha: 0.055),
                  ),
                ),
              ),
              Tooltip(
                message: '选择模型',
                child: Semantics(
                  button: true,
                  expanded: modelDropdownOpen,
                  label: '选择模型，当前$modelLabel',
                  child: Material(
                    color: state
                        .layer(context)
                        .withValues(alpha: state.isDark(context) ? 0.70 : 0.76),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: onToggleModelDropdown,
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: selectorWidth,
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: state.accents[0],
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: state.accents[0].withValues(
                                        alpha: 0.65,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sessionTitle,
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
                                        size: 10.5,
                                        weight: FontWeight.w600,
                                        opacity: 0.58,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedRotation(
                                turns: modelDropdownOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: state
                                      .text(context)
                                      .withValues(alpha: 0.55),
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
    );
  }
}
