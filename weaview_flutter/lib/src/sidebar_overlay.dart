part of '../main.dart';

class _SidebarOverlay extends StatelessWidget {
  const _SidebarOverlay({
    required this.state,
    required this.open,
    required this.onClose,
    required this.onSettings,
  });

  final WeaviewState state;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final width = math.min(286.0, MediaQuery.sizeOf(context).width * 0.84);
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                color: Colors.black.withValues(
                  alpha: state.isDark(context) ? 0.42 : 0.12,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: open ? 0 : -width,
            width: width,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: state.layer(context).withValues(alpha: 0.92),
                    border: Border(
                      right: BorderSide(
                        color: state.text(context).withValues(alpha: 0.07),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 36,
                        offset: const Offset(16, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: state.accents[0],
                                    width: 0.8,
                                  ),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: state.accents,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '织境',
                                style: state
                                    .textStyle(
                                      context,
                                      size: 13,
                                      weight: FontWeight.w600,
                                      opacity: 0.82,
                                    )
                                    .copyWith(letterSpacing: 3),
                              ),
                              const Spacer(),
                              _IconCircleButton(
                                icon: Icons.close_rounded,
                                onTap: onClose,
                                color: state.text(context),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: state.accents[0].withValues(
                                alpha: 0.16,
                              ),
                              foregroundColor: state.text(context),
                              elevation: 0,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () {
                              state.newSession();
                              onClose();
                            },
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('新的织梦'),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  '历史梦境',
                                  style: state
                                      .textStyle(
                                        context,
                                        size: 10,
                                        weight: FontWeight.w700,
                                        opacity: 0.36,
                                      )
                                      .copyWith(letterSpacing: 1.8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (state.chatSessions.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Text(
                                    '暂无历史记录',
                                    textAlign: TextAlign.center,
                                    style: state.textStyle(
                                      context,
                                      size: 12,
                                      opacity: 0.4,
                                    ),
                                  ),
                                )
                              else
                                for (final session in state.chatSessions)
                                  _HistoryTile(
                                    state: state,
                                    session: session,
                                    selected:
                                        session.id == state.currentSessionId,
                                    onTap: () {
                                      state.selectSession(session);
                                      onClose();
                                    },
                                  ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: state
                                  .text(context)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                _AvatarDot(
                                  value: state.userAvatar,
                                  fallbackIcon: Icons.person_outline_rounded,
                                  imageSize: 42,
                                  accent: state.accents[0],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.userName,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 13,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Pro Plan',
                                        style: state.textStyle(
                                          context,
                                          size: 10,
                                          opacity: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _IconCircleButton(
                                  icon: Icons.settings_outlined,
                                  onTap: onSettings,
                                  color: state.text(context),
                                  size: 34,
                                  opacity: 0.62,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
