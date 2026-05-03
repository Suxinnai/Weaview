import '../core/app_utils.dart';
import '../domain/models.dart';

class ModelConfigResolver {
  const ModelConfigResolver._();

  static AiProvider? providerForAssignment(
    List<AiProvider> providers,
    ModelAssignment assignment,
  ) {
    if (assignment.provider.isEmpty) return null;
    return providers.firstWhereOrNull((p) => p.name == assignment.provider);
  }

  static String? modelConfigIssue({
    required ModelAssignment? assignment,
    required AiProvider? provider,
    required String roleLabel,
    required String geminiApiKey,
  }) {
    if (assignment == null ||
        assignment.provider.trim().isEmpty ||
        assignment.model.trim().isEmpty) {
      return '请先在「设置 > 默认模型」中分配$roleLabel。';
    }
    if (provider == null) {
      return '$roleLabel关联的提供商不存在，请重新选择模型。';
    }
    final isGemini = provider.name.toLowerCase().contains('gemini');
    if (provider.apiKey.trim().isEmpty &&
        !(isGemini && geminiApiKey.isNotEmpty)) {
      return '请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。';
    }
    return null;
  }

  static AiProvider activeChatProvider({
    required List<AiProvider> providers,
    required Map<String, ModelAssignment> assignments,
  }) {
    final assignment = assignments['chat'];
    if (assignment != null && assignment.provider.isNotEmpty) {
      final matched = providers.firstWhereOrNull(
        (p) => p.name == assignment.provider,
      );
      if (matched != null) return matched;
    }
    return providers.firstWhereOrNull((p) => p.current) ?? providers.first;
  }

  static String friendlyAiError(
    Object error, {
    required Duration chatRequestTimeout,
  }) {
    final text = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    if (text.contains('TimeoutException')) {
      return '请求超时：当前设备网络或提供商在 ${chatRequestTimeout.inSeconds} 秒内没有返回数据。'
          '如果桌面端可用但真机不可用，请确认手机网络能直接访问当前 Base URL，或为手机配置同一网络代理。';
    }
    if (text.contains('SocketException')) {
      return '网络连接失败：当前设备无法连接到提供商地址。';
    }
    if (text.contains('HandshakeException') || text.contains('CERTIFICATE')) {
      return '安全连接失败：请检查提供商证书或改用有效的 HTTPS 地址。';
    }
    return text.isEmpty ? '未知错误。' : text;
  }
}
