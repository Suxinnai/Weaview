import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../history/sidebar_overlay.dart';
import '../settings/settings_sheet.dart';
import 'chat_home_sections.dart';

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
                  ChatBody(
                    state: state,
                    scrollController: _scroll,
                    dockExpanded: _dockExpanded,
                    pendingAttachments: _pendingAttachments,
                    onCopyMessage: _copyMessage,
                    onRetryMessage: _retryMessage,
                    onTranslateMessage: _translateMessage,
                    onDownloadAttachment: _downloadAttachment,
                  ),
                  ChatHeader(
                    state: state,
                    modelDropdownOpen: _modelDropdownOpen,
                    onOpenSidebar: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _sidebarOpen = true;
                        _dockExpanded = false;
                        _modelDropdownOpen = false;
                      });
                    },
                    onToggleModelDropdown: () => setState(() {
                      _modelDropdownOpen = !_modelDropdownOpen;
                      _modelSearch.clear();
                    }),
                  ),
                  SuggestionsBar(
                    state: state,
                    inputController: _input,
                    dockExpanded: _dockExpanded,
                    onSuggestionSelected: () => setState(() {}),
                  ),
                  ChatInputDock(
                    state: state,
                    inputController: _input,
                    wave: _wave,
                    recording: _recording,
                    webSearchEnabled: _webSearchEnabled,
                    dockExpanded: _dockExpanded,
                    pendingAttachments: _pendingAttachments,
                    onToggleExpanded: () =>
                        setState(() => _dockExpanded = !_dockExpanded),
                    onToggleWebSearch: _toggleWebSearch,
                    onSubmit: _submit,
                    onToggleRecording: _toggleRecording,
                    onPickChatImages: _pickChatImages,
                    onPickChatFiles: _pickChatFiles,
                    onRemoveAttachment: _removePendingAttachment,
                    onTextChanged: () => setState(() {}),
                  ),
                  ChatModelDropdown(
                    state: state,
                    modelSearchController: _modelSearch,
                    open: _modelDropdownOpen,
                    onClose: () => setState(() => _modelDropdownOpen = false),
                    onOpenSettings: () {
                      setState(() => _modelDropdownOpen = false);
                      _openSettings();
                    },
                    onSearchChanged: () => setState(() {}),
                    onSelectModel: (item) {
                      state.saveModelAssignment(
                        'chat',
                        ModelAssignment(
                          provider: item.provider.name,
                          model: item.model.name,
                          prompt: state.modelAssignments['chat']?.prompt ?? '',
                        ),
                      );
                      setState(() {
                        _modelDropdownOpen = false;
                        _modelSearch.clear();
                      });
                    },
                  ),
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
}
