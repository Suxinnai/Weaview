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
import '../../data/ai/ai_gateway.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _modelSearch = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  static const MethodChannel _nativeSpeech = MethodChannel(
    'weaview/native_speech',
  );
  static const MethodChannel _nativeTts = MethodChannel('weaview/native_tts');
  late final speech.SpeechToText _speech;
  late final AnimationController _wave;
  bool _sidebarOpen = false;
  bool _dockExpanded = false;
  bool _modelDropdownOpen = false;
  bool _recording = false;
  bool _webSearchEnabled = false;
  bool _imageGenerationMode = false;
  String _recordingPrefix = '';
  int _seenMessageCount = 0;
  DateTime _lastAutoScroll = DateTime.fromMillisecondsSinceEpoch(0);
  List<MessageAttachment> _pendingAttachments = [];
  double _dockHeight = 68.0;
  bool _backgroundedWithImageGeneration = false;

  @override
  void initState() {
    super.initState();
    _speech = speech.SpeechToText();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addObserver(this);
    _inputFocus.addListener(_handleInputFocusChange);
    widget.state.addListener(_stateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_stateChanged);
    _inputFocus.removeListener(_handleInputFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _modelSearch.dispose();
    _inputFocus.dispose();
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
        _isNearConversationEnd() &&
        now.difference(_lastAutoScroll).inMilliseconds > 90;
    if (countChanged || shouldTrackStream) {
      _seenMessageCount = widget.state.messages.length;
      _lastAutoScroll = now;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(animated: !widget.state.isStreaming),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _backgroundedWithImageGeneration = widget.state.hasActiveImageGeneration;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final shouldRetry = _backgroundedWithImageGeneration;
    _backgroundedWithImageGeneration = false;
    unawaited(
      widget.state.resumeInterruptedImageGeneration(
        retryLastFailure: shouldRetry,
      ),
    );
    _scheduleKeyboardAwareScroll();
  }

  void _handleInputFocusChange() {
    if (!_inputFocus.hasFocus) return;
    _scheduleKeyboardAwareScroll();
  }

  bool _isNearConversationEnd() {
    if (!_scroll.hasClients) return true;
    final distance = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    return distance < 360;
  }

  void _scheduleKeyboardAwareScroll() {
    for (final delay in const [
      Duration(milliseconds: 90),
      Duration(milliseconds: 240),
      Duration(milliseconds: 420),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !_scroll.hasClients) return;
        _scrollToBottom(animated: true);
      });
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
    if (_imageGenerationMode) {
      if (text.trim().isEmpty) return;
      _input.clear();
      setState(() {
        _pendingAttachments = [];
        _dockExpanded = false;
      });
      await widget.state.submitImageGeneration(text, attachments: attachments);
      return;
    }
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
      imageGeneration: _imageGenerationMode,
    );
  }

  Future<void> _editMessage(int index) async {
    if (index < 0 || index >= widget.state.messages.length) return;
    final message = widget.state.messages[index];
    if (message.role == 'user') {
      _input.text = message.content;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      setState(() => _dockExpanded = false);
      _inputFocus.requestFocus();
      return;
    }
  }

  void _branchMessage(int index) {
    widget.state.createBranchAt(index);
    _snack('已从当前消息创建分支。');
  }

  Future<void> _deleteMessage(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.state.deleteMessageAt(index);
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

  Future<void> _speakMessage(ChatMessage message) async {
    final text = message.content.trim();
    if (text.isEmpty) return;
    if (!widget.state.ttsEnabled) {
      _snack('请先在「设置 > 扩展服务 > 语音服务」中手动启用一个 TTS 服务。');
      return;
    }
    try {
      if (widget.state.activeTtsId == 'system') {
        await _nativeTts.invokeMethod<void>('speak', {
          'text': text,
          'locale': 'zh-CN',
        });
        return;
      }
      final provider = widget.state.activeTtsProvider;
      if (provider == null) {
        _snack('当前 TTS 服务不存在，请重新选择。');
        return;
      }
      if (_isPcm16StreamingTts(provider)) {
        await _nativeTts.invokeMethod<void>('startPcm16Stream', {
          'sampleRate': 24000,
        });
        try {
          await AiGateway.streamSpeechPcm16(
            config: provider,
            text: text,
            onChunk: (chunk) async {
              if (chunk.isEmpty) return;
              await _nativeTts.invokeMethod<void>('appendPcm16', {
                'bytes': chunk,
              });
            },
          );
          await _nativeTts.invokeMethod<void>('finishPcm16Stream');
        } catch (_) {
          await _nativeTts.invokeMethod<void>('stop').catchError((_) {});
          rethrow;
        }
        return;
      }
      final audio = await AiGateway.synthesizeSpeech(
        config: provider,
        text: text,
      );
      await _nativeTts.invokeMethod<void>('playAudio', {
        'bytes': audio.bytes,
        'mimeType': audio.mimeType,
      });
    } on PlatformException catch (error) {
      final detail = error.message?.trim().isNotEmpty == true
          ? error.message!
          : error.code;
      _snack('语音播报不可用：$detail');
    } catch (error) {
      _snack('语音播报不可用：${error.toString().replaceFirst('Exception: ', '')}');
    }
  }

  bool _isPcm16StreamingTts(TtsProviderConfig provider) {
    final lower = '${provider.type} ${provider.name} ${provider.baseUrl}'
        .toLowerCase();
    return lower.contains('xiaomi') ||
        lower.contains('mimo') ||
        lower.contains('xiaomimimo');
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
      await _nativeSpeech.invokeMethod<void>('cancel').catchError((_) {});
      _wave.stop();
      setState(() => _recording = false);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isAndroid) {
      await _listenWithNativeSpeech('android native recognizer');
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
    await _listenWithNativeSpeech(reason);
  }

  Future<void> _listenWithNativeSpeech(String reason) async {
    try {
      _recordingPrefix = _input.text;
      FocusManager.instance.primaryFocus?.unfocus();
      _wave.repeat();
      if (mounted) setState(() => _recording = true);
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
      if (error.code == 'CANCELLED') return;
      final message = error.message?.trim().isNotEmpty == true
          ? error.message!
          : reason;
      if (_isMicrophonePermissionError(error, message)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showMicrophonePermissionDialog(message));
        });
        return;
      }
      if (error.code == 'SPEECH_ENGINE_AUTH_REQUIRED') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showSpeechEngineDialog(message));
        });
        return;
      }
      _snack('语音输入不可用：$message');
    } finally {
      if (mounted) {
        _wave.stop();
        setState(() => _recording = false);
      }
    }
  }

  bool _isMicrophonePermissionError(PlatformException error, String message) {
    return error.code == 'PERMISSION_DENIED' ||
        message.contains('麦克风权限') ||
        message.contains('缺少麦克风权限');
  }

  Future<void> _showSpeechEngineDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('语音引擎需要授权'),
        content: Text(
          '$message\n\n这是系统语音识别服务的授权，不是织境的麦克风权限。完成授权后再点击麦克风即可继续使用。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMicrophonePermissionDialog(String message) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: Text('$message\n\n请在系统权限中允许麦克风后，再返回织境使用语音输入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (openSettings != true) return;
    try {
      await _nativeSpeech.invokeMethod<void>('openAppSettings');
    } on PlatformException catch (error) {
      final detail = error.message?.trim().isNotEmpty == true
          ? error.message!
          : error.code;
      if (mounted) _snack('无法打开权限设置：$detail');
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
                    dockHeight: _dockHeight,
                    pendingAttachments: _pendingAttachments,
                    onCopyMessage: _copyMessage,
                    onRetryMessage: _retryMessage,
                    onEditMessage: _editMessage,
                    onTranslateMessage: _translateMessage,
                    onBranchMessage: _branchMessage,
                    onDeleteMessage: _deleteMessage,
                    onSpeakMessage: _speakMessage,
                    onDownloadAttachment: _downloadAttachment,
                  ),
                  ChatHeader(
                    state: state,
                    modelDropdownOpen: _modelDropdownOpen,
                    imageGenerationMode: _imageGenerationMode,
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
                    inputFocusNode: _inputFocus,
                    dockExpanded: _dockExpanded,
                    dockHeight: _dockHeight,
                    onSuggestionSelected: () => setState(() {}),
                  ),
                  ChatInputDock(
                    state: state,
                    inputController: _input,
                    inputFocusNode: _inputFocus,
                    wave: _wave,
                    recording: _recording,
                    webSearchEnabled: _webSearchEnabled,
                    imageGenerationMode: _imageGenerationMode,
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
                    onHeightChanged: (size) {
                      if (_dockHeight != size.height) {
                        setState(() => _dockHeight = size.height);
                      }
                    },
                  ),
                  ChatModelDropdown(
                    state: state,
                    modelSearchController: _modelSearch,
                    open: _modelDropdownOpen,
                    imageGenerationMode: _imageGenerationMode,
                    onClose: () => setState(() => _modelDropdownOpen = false),
                    onOpenSettings: () {
                      setState(() => _modelDropdownOpen = false);
                      _openSettings();
                    },
                    onSearchChanged: () => setState(() {}),
                    onSelectModel: (item) {
                      final role = item.supportsImageGeneration
                          ? 'image'
                          : 'chat';
                      state.saveModelAssignment(
                        role,
                        ModelAssignment(
                          provider: item.provider.name,
                          model: item.model.name,
                          prompt: state.modelAssignments[role]?.prompt ?? '',
                        ),
                      );
                      setState(() {
                        _imageGenerationMode = item.supportsImageGeneration;
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
