import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../core/app_utils.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.state,
    required this.modelDropdownOpen,
    required this.onOpenSidebar,
    required this.onToggleModelDropdown,
  });

  final WeaviewState state;
  final bool modelDropdownOpen;
  final VoidCallback onOpenSidebar;
  final VoidCallback onToggleModelDropdown;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: 74,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: IconCircleButton(
                  icon: Icons.menu_rounded,
                  onTap: onOpenSidebar,
                  color: state.text(context),
                ),
              ),
              GestureDetector(
                onTap: onToggleModelDropdown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.messages.isNotEmpty
                            ? state.chatSessions
                                      .firstWhereOrNull(
                                        (s) => s.id == state.currentSessionId,
                                      )
                                      ?.title ??
                                  '未命名梦境'
                            : '新梦境',
                        style: state.textStyle(
                          context,
                          size: 15,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
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
                                  color: state.accents[0].withValues(
                                    alpha: 0.8,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              state
                                          .modelAssignments['chat']
                                          ?.model
                                          .isNotEmpty ==
                                      true
                                  ? state.modelAssignments['chat']!.model
                                  : '未选择模型',
                              overflow: TextOverflow.ellipsis,
                              style: state
                                  .textStyle(
                                    context,
                                    size: 10,
                                    weight: FontWeight.w600,
                                    opacity: 0.55,
                                  )
                                  .copyWith(letterSpacing: 1.4),
                            ),
                          ),
                          AnimatedRotation(
                            turns: modelDropdownOpen ? -0.25 : 0.25,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: state
                                  .text(context)
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ],
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
