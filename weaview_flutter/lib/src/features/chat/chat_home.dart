import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../../shared/view_models/provider_model.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../history/sidebar_overlay.dart';
import '../settings/settings_sheet.dart';
import 'message_widgets.dart';

class WeaviewHome extends StatefulWidget {
  const WeaviewHome({super.key, required this.state});

  final WeaviewState state;

  @override
  State<WeaviewHome> createState() => _WeaviewHomeState();
}

class _WeaviewHomeState extends State<WeaviewHome>
    with TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _modelSearch = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  static const MethodChannel _nativeSpeech = MethodChannel(
    'weaview/native_speech',
  );
  late final speech.SpeechToText _speech;
  late final AnimationController _wave;
  bool _sidebarOpen = false;
  bool _dockExpanded = false;
  bool _modelDropdownOpen = false;
  bool _recording = false;
  bool _webSearchEnabled = false;
  String _recordingPrefix = '';
  int _seenMessageCount = 0;
  DateTime _lastAutoScroll = DateTime.fromMillisecondsSinceEpoch(0);
  List<MessageAttachment> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _speech = speech.SpeechToText();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.state.addListener(_stateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_stateChanged);
    _input.dispose();
    _modelSearch.dispose();
    _scroll.dispose();
    _wave.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _stateChanged() {
    if (!mounted) return;
    final now = DateTime.now();
    final countChanged = widget.state.messages.length != _seenMessageCount;
    final shouldTrackStream =
        widget.state.isStreaming &&
        now.difference(_lastAutoScroll).inMilliseconds > 90;
    if (countChanged || shouldTrackStream) {
      _seenMessageCount = widget.state.messages.length;
      _lastAutoScroll = now;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(animated: !widget.state.isStreaming),
      );
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    if (animated) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _submit() async {
    if (widget.state.isStreaming) {
      widget.state.cancelStreaming();
      return;
    }
    final text = _input.text;
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) {
      return;
    }
    if (_recording) {
      await _speech.stop();
      _wave.stop();
      setState(() => _recording = false);
    }
    final attachments = List<MessageAttachment>.from(_pendingAttachments);
    final useWebSearch = _webSearchEnabled;
    _input.clear();
    setState(() => _pendingAttachments = []);
    await widget.state.submitMessage(
      text,
      attachments: attachments,
      useWebSearch: useWebSearch,
    );
  }

  void _toggleWebSearch() {
    if (!widget.state.hasActiveSearchKey) {
      _snack('请先在「设置 > 扩展服务 > 搜索服务」中配置 Tavily API Key。');
      return;
    }
    setState(() => _webSearchEnabled = !_webSearchEnabled);
  }

  Future<void> _retryMessage(int index) async {
    await widget.state.retryMessageAt(
      index,
      useWebSearch: _webSearchEnabled && widget.state.hasActiveSearchKey,
    );
  }

  Future<void> _translateMessage(int index) async {
    try {
      await widget.state.translateMessageAt(index);
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _copyMessage(ChatMessage message) async {
    final text = [
      if (message.content.trim().isNotEmpty) message.content.trim(),
      if (message.translation.trim().isNotEmpty)
        '\n\n翻译：${message.translation.trim()}',
    ].join();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _snack('已复制到剪贴板。');
  }

  Future<void> _downloadAttachment(MessageAttachment attachment) async {
    final file = File(attachment.path);
    if (!await file.exists()) {
      _snack('附件文件不存在，无法保存。');
      return;
    }
    final bytes = await file.readAsBytes();
    final path = await FilePicker.saveFile(
      dialogTitle: '保存 ${attachment.name}',
      fileName: attachment.name,
      bytes: bytes,
    );
    if (path != null) _snack('文件已保存。');
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _speech.stop();
      _wave.stop();
      setState(() => _recording = false);
      return;
    }
    _recordingPrefix = _input.text;
    final available = await _speech.initialize(
      debugLogging: true,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            _wave.stop();
            setState(() => _recording = false);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          _wave.stop();
          setState(() => _recording = false);
          if (error.permanent) {
            _snack('语音插件不可用，正在尝试系统语音输入。');
            unawaited(_nativeSpeechFallback(error.errorMsg));
          } else {
            _snack('语音输入失败：${error.errorMsg}');
          }
        }
      },
    );
    if (!available) {
      await _nativeSpeechFallback('speech_to_text unavailable');
      return;
    }
    final locales = await _speech.locales();
    final systemLocale = await _speech.systemLocale();
    final localeId =
        locales
            .firstWhereOrNull(
              (locale) => locale.localeId.toLowerCase().startsWith('zh'),
            )
            ?.localeId ??
        systemLocale?.localeId;
    _wave.repeat();
    setState(() => _recording = true);
    await _speech.listen(
      localeId: localeId,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 5),
      listenOptions: speech.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: speech.ListenMode.dictation,
      ),
      onResult: (result) {
        _applyRecognizedSpeech(result.recognizedWords);
      },
    );
  }

  Future<void> _nativeSpeechFallback(String reason) async {
    try {
      final text = await _nativeSpeech.invokeMethod<String>('listen', {
        'locale': 'zh-CN',
      });
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        _snack('没有识别到语音内容。');
        return;
      }
      _applyRecognizedSpeech(text);
      setState(() {});
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.message?.trim().isNotEmpty == true
          ? error.message!
          : reason;
      _snack('语音输入不可用：$message');
    }
  }

  void _applyRecognizedSpeech(String recognizedWords) {
    final words = recognizedWords.trim();
    if (words.isEmpty) return;
    final prefix = _recordingPrefix.trim();
    _input.text = [if (prefix.isNotEmpty) prefix, words].join(' ');
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  Future<void> _pickAvatar(bool userAvatar) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1024,
    );
    if (file == null) return;
    if (userAvatar) {
      widget.state.updateUserAvatar(file.path);
    } else {
      widget.state.updateAssistantAvatar(file.path);
    }
  }

  Future<void> _pickChatImages() async {
    final files = await _imagePicker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (files.isEmpty) return;
    final attachments = <MessageAttachment>[];
    for (final file in files) {
      final data = File(file.path);
      final stat = await data.stat();
      attachments.add(
        MessageAttachment(
          path: file.path,
          name: file.name,
          mimeType: lookupMimeType(file.path) ?? 'image/jpeg',
          kind: 'image',
          size: stat.size,
        ),
      );
    }
    setState(() {
      _pendingAttachments = [..._pendingAttachments, ...attachments];
      _dockExpanded = false;
    });
  }

  Future<void> _pickChatFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final attachments = <MessageAttachment>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      attachments.add(
        MessageAttachment(
          path: path,
          name: file.name,
          mimeType: lookupMimeType(path) ?? 'application/octet-stream',
          kind: 'file',
          size: file.size,
        ),
      );
    }
    setState(() {
      _pendingAttachments = [..._pendingAttachments, ...attachments];
      _dockExpanded = false;
    });
  }

  void _removePendingAttachment(MessageAttachment attachment) {
    setState(() {
      _pendingAttachments = _pendingAttachments
          .where((item) => item.path != attachment.path)
          .toList();
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openSettings() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _dockExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsSheet(
          state: widget.state,
          open: true,
          onClose: () => Navigator.of(context).maybePop(),
          onPickAvatar: _pickAvatar,
          showSnack: _snack,
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dark = state.isDark(context);
    final overlayStyle = dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: PopScope(
            canPop: !_sidebarOpen && !_modelDropdownOpen && !_dockExpanded,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              setState(() {
                if (_modelDropdownOpen) {
                  _modelDropdownOpen = false;
                } else if (_dockExpanded) {
                  _dockExpanded = false;
                } else if (_sidebarOpen) {
                  _sidebarOpen = false;
                }
              });
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    color: state.background(context),
                  ),
                  AmbientBlob(
                    alignment: Alignment.topLeft,
                    color: state.accents[0],
                    size: 360,
                    opacity: dark ? 0.16 : 0.22,
                  ),
                  AmbientBlob(
                    alignment: Alignment.bottomRight,
                    color: state.accents[1],
                    size: 320,
                    opacity: dark ? 0.18 : 0.26,
                  ),
                  if (state.themePulse > 0)
                    ThemeRipple(
                      key: ValueKey(state.themePulse),
                      color: state.text(context),
                    ),
                  _buildChatBody(state),
                  _buildHeader(state),
                  _buildSuggestions(state),
                  _buildInputDock(state),
                  _buildModelDropdown(state),
                  SidebarOverlay(
                    state: state,
                    open: _sidebarOpen,
                    onClose: () => setState(() => _sidebarOpen = false),
                    onSettings: () {
                      setState(() => _sidebarOpen = false);
                      _openSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(WeaviewState state) {
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
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() {
                      _sidebarOpen = true;
                      _dockExpanded = false;
                      _modelDropdownOpen = false;
                    });
                  },
                  color: state.text(context),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _modelDropdownOpen = !_modelDropdownOpen;
                  _modelSearch.clear();
                }),
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
                            turns: _modelDropdownOpen ? -0.25 : 0.25,
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

  Widget _buildChatBody(WeaviewState state) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final suggestionPad =
        state.suggestions.isNotEmpty &&
            !state.isStreaming &&
            !_dockExpanded &&
            keyboardInset == 0
        ? 48.0
        : 0.0;
    final bottomPad =
        136.0 +
        keyboardInset +
        suggestionPad +
        (_dockExpanded ? 92 : 0) +
        (_pendingAttachments.isEmpty ? 0 : 78);
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: 86, bottom: bottomPad),
          child: state.messages.isEmpty
              ? Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '今天，你想编织什么梦境？',
                          textAlign: TextAlign.center,
                          style: state
                              .textStyle(
                                context,
                                size: 17,
                                weight: FontWeight.w300,
                                opacity: 0.82,
                              )
                              .copyWith(letterSpacing: 1.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'What dream shall we weave today?',
                          textAlign: TextAlign.center,
                          style: state
                              .textStyle(
                                context,
                                size: 12,
                                weight: FontWeight.w400,
                                opacity: 0.38,
                              )
                              .copyWith(letterSpacing: 0.7),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: state.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 32),
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return MessageBubble(
                      state: state,
                      message: message,
                      assistantAvatar: state.assistantAvatar,
                      userAvatar: state.userAvatar,
                      onCopy: () => _copyMessage(message),
                      onRetry: () => _retryMessage(index),
                      onTranslate: () => _translateMessage(index),
                      onDownloadAttachment: _downloadAttachment,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildInputDock(WeaviewState state) {
    final dark = state.isDark(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final dockSurface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: (dark ? Colors.black : state.layer(context)).withValues(
          alpha: dark ? 0.58 : 0.62,
        ),
        borderRadius: BorderRadius.circular(_dockExpanded ? 24 : 32),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(
            alpha: dark ? 0.06 : 0.07,
          ),
        ),
        boxShadow: [
          if (!keyboardOpen)
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.14 : 0.055),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _recording
                ? _recordingStrip(state)
                : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _pendingAttachments.isEmpty
                ? const SizedBox.shrink()
                : AttachmentPreviewStrip(
                    state: state,
                    attachments: _pendingAttachments,
                    onRemove: _removePendingAttachment,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _dockExpanded = !_dockExpanded),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 260),
                    turns: _dockExpanded ? 0.125 : 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _dockExpanded
                            ? state.text(context).withValues(alpha: 0.06)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: state
                            .text(context)
                            .withValues(alpha: _dockExpanded ? 1 : 0.5),
                      ),
                    ),
                  ),
                ),
                IconCircleButton(
                  icon: _webSearchEnabled
                      ? Icons.travel_explore_rounded
                      : Icons.public_rounded,
                  onTap: _toggleWebSearch,
                  color: _webSearchEnabled ? sendGreen : state.text(context),
                  background: _webSearchEnabled
                      ? sendGreen.withValues(alpha: 0.14)
                      : Colors.transparent,
                  opacity: _webSearchEnabled ? 1 : 0.42,
                  size: 38,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: state.textStyle(context, size: 15, height: 1.45),
                    decoration: InputDecoration(
                      hintText: '今天想编织什么？',
                      hintStyle: state.textStyle(
                        context,
                        size: 15,
                        opacity: 0.38,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 4),
                if ((_input.text.trim().isEmpty || _recording) &&
                    !state.isStreaming)
                  IconCircleButton(
                    icon: Icons.mic_none_rounded,
                    onTap: _toggleRecording,
                    color: _recording ? sendGreen : state.text(context),
                    background: _recording
                        ? sendGreen.withValues(alpha: 0.18)
                        : Colors.transparent,
                    opacity: _recording ? 1 : 0.42,
                    size: 38,
                  ),
                const SizedBox(width: 3),
                SendButton(
                  streaming: state.isStreaming,
                  enabled:
                      state.isStreaming ||
                      ((_input.text.trim().isNotEmpty ||
                                  _pendingAttachments.isNotEmpty) &&
                              !state.isStreaming) &&
                          !_recording,
                  onTap: _submit,
                  state: state,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: _dockExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Row(
                      children: [
                        ToolChip(
                          icon: Icons.image_outlined,
                          label: '图片',
                          state: state,
                          onTap: _pickChatImages,
                        ),
                        const SizedBox(width: 10),
                        ToolChip(
                          icon: Icons.description_outlined,
                          label: '文件',
                          state: state,
                          onTap: _pickChatFiles,
                        ),
                        const SizedBox(width: 10),
                        ToolChip(
                          icon: Icons.public_rounded,
                          label: _webSearchEnabled ? '关闭联网' : '联网搜索',
                          state: state,
                          onTap: _toggleWebSearch,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
    final dock = ClipRRect(
      borderRadius: BorderRadius.circular(_dockExpanded ? 24 : 32),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: keyboardOpen ? 0 : 4,
          sigmaY: keyboardOpen ? 0 : 4,
        ),
        child: dockSurface,
      ),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: dock,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(WeaviewState state) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (state.suggestions.isEmpty ||
        state.isStreaming ||
        _dockExpanded ||
        keyboardInset > 0) {
      return const SizedBox.shrink();
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: 14,
      right: 14,
      bottom: 92 + MediaQuery.paddingOf(context).bottom,
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
                        _input.text = suggestion;
                        _input.selection = TextSelection.collapsed(
                          offset: _input.text.length,
                        );
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordingStrip(WeaviewState state) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: sendGreen.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: state.text(context).withValues(alpha: 0.06),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  width: 5,
                  height:
                      10 +
                      (math.sin((_wave.value * math.pi * 2) + i * 0.75) + 1) *
                          8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: sendGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                '聆听中...',
                style: state
                    .textStyle(context, size: 12, weight: FontWeight.w600)
                    .copyWith(color: sendGreen, letterSpacing: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelDropdown(WeaviewState state) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final allModels = [
      for (final provider in state.providers)
        for (final model in provider.models)
          ProviderModel(provider: provider, model: model),
    ];
    final query = _modelSearch.text.trim().toLowerCase();
    final filtered = allModels.where((item) {
      if (query.isEmpty) return true;
      return item.model.name.toLowerCase().contains(query) ||
          item.provider.name.toLowerCase().contains(query) ||
          item.model.id.toLowerCase().contains(query);
    }).toList();

    return IgnorePointer(
      ignoring: !_modelDropdownOpen,
      child: AnimatedOpacity(
        opacity: _modelDropdownOpen ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _modelDropdownOpen = false),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: safeTop + 62,
              left: 0,
              right: 0,
              child: Center(
                child: GlassPanel(
                  state: state,
                  radius: 22,
                  child: SizedBox(
                    width: math.min(
                      390.0,
                      MediaQuery.sizeOf(context).width - 28,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '选择模型',
                                  style: state
                                      .textStyle(
                                        context,
                                        size: 11,
                                        weight: FontWeight.w700,
                                        opacity: 0.42,
                                      )
                                      .copyWith(letterSpacing: 1.6),
                                ),
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: state
                                      .text(context)
                                      .withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                          TextField(
                            controller: _modelSearch,
                            autofocus: false,
                            onChanged: (_) => setState(() {}),
                            style: state.textStyle(context, size: 12),
                            decoration: InputDecoration(
                              hintText: '搜索模型...',
                              hintStyle: state.textStyle(
                                context,
                                size: 12,
                                opacity: 0.38,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: state
                                  .text(context)
                                  .withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.min(
                                420.0,
                                MediaQuery.sizeOf(context).height * 0.48,
                              ),
                            ),
                            child: filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      children: [
                                        Text(
                                          allModels.isEmpty
                                              ? '未配置可用模型'
                                              : '未找到匹配模型',
                                          style: state.textStyle(
                                            context,
                                            size: 13,
                                            opacity: 0.52,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _modelDropdownOpen = false;
                                            });
                                            _openSettings();
                                          },
                                          child: const Text('前往设置配置'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      final selected =
                                          state
                                                  .modelAssignments['chat']
                                                  ?.provider ==
                                              item.provider.name &&
                                          state
                                                  .modelAssignments['chat']
                                                  ?.model ==
                                              item.model.name;
                                      return ModelDropdownItem(
                                        state: state,
                                        item: item,
                                        selected: selected,
                                        onTap: () {
                                          state.saveModelAssignment(
                                            'chat',
                                            ModelAssignment(
                                              provider: item.provider.name,
                                              model: item.model.name,
                                              prompt:
                                                  state
                                                      .modelAssignments['chat']
                                                      ?.prompt ??
                                                  '',
                                            ),
                                          );
                                          setState(() {
                                            _modelDropdownOpen = false;
                                            _modelSearch.clear();
                                          });
                                        },
                                      );
                                    },
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
      ),
    );
  }
}
