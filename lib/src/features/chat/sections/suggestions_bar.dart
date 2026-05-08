import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../shared/widgets/shared_widgets.dart';

class SuggestionsBar extends StatelessWidget {
  const SuggestionsBar({
    super.key,
    required this.state,
    required this.inputController,
    required this.inputFocusNode,
    required this.dockExpanded,
    required this.dockHeight,
    required this.onSuggestionSelected,
  });

  final WeaviewState state;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool dockExpanded;
  final double dockHeight;
  final VoidCallback onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: inputFocusNode,
      builder: (context, _) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        if (state.suggestions.isEmpty ||
            state.isStreaming ||
            dockExpanded ||
            inputFocusNode.hasFocus ||
            keyboardInset > 0) {
          return const SizedBox.shrink();
        }
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: 14,
          right: 14,
          bottom: dockHeight + MediaQuery.paddingOf(context).bottom + 8,
          child: IgnorePointer(
            ignoring: state.suggestions.isEmpty,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: state.suggestions.isEmpty ? 0 : 1,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final suggestion in state.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SuggestionChip(
                          state: state,
                          label: suggestion,
                          onTap: () {
                            inputController.text = suggestion;
                            inputController.selection = TextSelection.collapsed(
                              offset: inputController.text.length,
                            );
                            onSuggestionSelected();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
