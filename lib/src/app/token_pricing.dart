class TokenPricing {
  const TokenPricing({
    required this.inputPerMillionUsd,
    required this.outputPerMillionUsd,
  });

  final double inputPerMillionUsd;
  final double outputPerMillionUsd;
}

TokenPricing tokenPricingFor(String provider, String model) {
  final providerKey = provider.toLowerCase();
  final modelKey = model.toLowerCase();
  if (modelKey.contains('free')) {
    return const TokenPricing(inputPerMillionUsd: 0, outputPerMillionUsd: 0);
  }
  if (providerKey.contains('deepseek') || modelKey.contains('deepseek')) {
    if (modelKey.contains('pro')) {
      return const TokenPricing(
        inputPerMillionUsd: 0.435,
        outputPerMillionUsd: 0.87,
      );
    }
    return const TokenPricing(
      inputPerMillionUsd: 0.14,
      outputPerMillionUsd: 0.28,
    );
  }
  if (providerKey.contains('gemini') || modelKey.contains('gemini')) {
    if (modelKey.contains('3')) {
      return const TokenPricing(inputPerMillionUsd: 2, outputPerMillionUsd: 12);
    }
    if (modelKey.contains('2.5') && modelKey.contains('pro')) {
      return const TokenPricing(
        inputPerMillionUsd: 1.25,
        outputPerMillionUsd: 10,
      );
    }
    if (modelKey.contains('2.5') && modelKey.contains('flash-lite')) {
      return const TokenPricing(
        inputPerMillionUsd: 0.18,
        outputPerMillionUsd: 0.72,
      );
    }
    if (modelKey.contains('2.5') && modelKey.contains('flash')) {
      return const TokenPricing(
        inputPerMillionUsd: 0.30,
        outputPerMillionUsd: 2.50,
      );
    }
    if (modelKey.contains('flash')) {
      return const TokenPricing(
        inputPerMillionUsd: 0.10,
        outputPerMillionUsd: 0.40,
      );
    }
    return const TokenPricing(inputPerMillionUsd: 1.25, outputPerMillionUsd: 5);
  }
  if (providerKey.contains('kimi') || modelKey.contains('moonshot')) {
    return const TokenPricing(
      inputPerMillionUsd: 0.42,
      outputPerMillionUsd: 0.42,
    );
  }
  if (providerKey.contains('anthropic') || modelKey.contains('claude')) {
    if (modelKey.contains('haiku') && modelKey.contains('4.5')) {
      return const TokenPricing(inputPerMillionUsd: 1, outputPerMillionUsd: 5);
    }
    if (modelKey.contains('haiku')) {
      return const TokenPricing(
        inputPerMillionUsd: 0.80,
        outputPerMillionUsd: 4,
      );
    }
    if (modelKey.contains('sonnet')) {
      return const TokenPricing(inputPerMillionUsd: 3, outputPerMillionUsd: 15);
    }
    if (modelKey.contains('opus') &&
        (modelKey.contains('4.5') ||
            modelKey.contains('4.6') ||
            modelKey.contains('4.7') ||
            modelKey.contains('4.8'))) {
      return const TokenPricing(inputPerMillionUsd: 5, outputPerMillionUsd: 25);
    }
    return const TokenPricing(inputPerMillionUsd: 15, outputPerMillionUsd: 75);
  }
  if (providerKey.contains('grok') ||
      providerKey.contains('xai') ||
      providerKey.contains('x.ai') ||
      modelKey.contains('grok')) {
    if (modelKey.contains('build')) {
      return const TokenPricing(inputPerMillionUsd: 1, outputPerMillionUsd: 2);
    }
    return const TokenPricing(
      inputPerMillionUsd: 1.25,
      outputPerMillionUsd: 2.50,
    );
  }
  if (modelKey.contains('gpt-5.5-pro') || modelKey.contains('gpt-5.4-pro')) {
    return const TokenPricing(inputPerMillionUsd: 30, outputPerMillionUsd: 180);
  }
  if (modelKey.contains('gpt-5.5')) {
    return const TokenPricing(inputPerMillionUsd: 5, outputPerMillionUsd: 30);
  }
  if (modelKey.contains('gpt-5.4-mini')) {
    return const TokenPricing(
      inputPerMillionUsd: 0.75,
      outputPerMillionUsd: 4.50,
    );
  }
  if (modelKey.contains('gpt-5.4-nano')) {
    return const TokenPricing(
      inputPerMillionUsd: 0.20,
      outputPerMillionUsd: 1.25,
    );
  }
  if (modelKey.contains('gpt-5.4')) {
    return const TokenPricing(
      inputPerMillionUsd: 2.50,
      outputPerMillionUsd: 15,
    );
  }
  if (modelKey.contains('4o-mini')) {
    return const TokenPricing(
      inputPerMillionUsd: 0.15,
      outputPerMillionUsd: 0.60,
    );
  }
  if (modelKey.contains('4o') || modelKey.contains('4.1')) {
    return const TokenPricing(
      inputPerMillionUsd: 2.50,
      outputPerMillionUsd: 10,
    );
  }
  if (modelKey.startsWith('o3') || modelKey.startsWith('o4')) {
    return const TokenPricing(
      inputPerMillionUsd: 1.10,
      outputPerMillionUsd: 4.40,
    );
  }
  return const TokenPricing(
    inputPerMillionUsd: 0.50,
    outputPerMillionUsd: 1.50,
  );
}
