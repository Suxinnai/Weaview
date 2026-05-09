String imagePromptWithDefaultQualityGuard(String prompt) {
  final trimmed = prompt.trim();
  if (trimmed.isEmpty || _explicitlyRequestsObscuredFaces(trimmed)) {
    return trimmed;
  }
  return '$trimmed\n\n'
      'Quality guard: unless the user explicitly requested it, keep every '
      'person or character face clear, coherent, natural, non-pixelated, '
      'non-mosaic, non-blurred, and free of censorship blocks or unintended '
      'face-obscuring artifacts.';
}

bool _explicitlyRequestsObscuredFaces(String prompt) {
  final text = prompt.toLowerCase();
  const needles = [
    '马赛克',
    '打码',
    '模糊脸',
    '遮脸',
    '遮挡脸',
    '脸部模糊',
    '像素化',
    '隐私保护',
    'mosaic',
    'pixelated',
    'pixelated face',
    'blurred face',
    'face blur',
    'censor',
    'censored',
    'anonymized',
    'obscured face',
  ];
  return needles.any(text.contains);
}
