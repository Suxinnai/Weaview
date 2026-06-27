import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/app/token_pricing.dart';

void main() {
  test('uses current public pricing for common providers', () {
    expect(tokenPricingFor('OpenAI', 'gpt-5.4').inputPerMillionUsd, 2.50);
    expect(tokenPricingFor('OpenAI', 'gpt-5.4').outputPerMillionUsd, 15);

    expect(
      tokenPricingFor('Anthropic', 'claude-sonnet-4.6').inputPerMillionUsd,
      3,
    );
    expect(
      tokenPricingFor('Anthropic', 'claude-sonnet-4.6').outputPerMillionUsd,
      15,
    );

    expect(
      tokenPricingFor('Gemini', 'gemini-2.5-flash').inputPerMillionUsd,
      0.30,
    );
    expect(
      tokenPricingFor('Gemini', 'gemini-2.5-flash').outputPerMillionUsd,
      2.50,
    );

    expect(
      tokenPricingFor('DeepSeek', 'deepseek-v4-flash').inputPerMillionUsd,
      0.14,
    );
    expect(
      tokenPricingFor('DeepSeek', 'deepseek-v4-flash').outputPerMillionUsd,
      0.28,
    );

    expect(tokenPricingFor('Grok', 'grok-4.3').inputPerMillionUsd, 1.25);
    expect(tokenPricingFor('Grok', 'grok-4.3').outputPerMillionUsd, 2.50);
  });

  test('treats explicitly free models as zero-cost estimates', () {
    final pricing = tokenPricingFor('ZenMux', 'z-ai/glm-5.2-free');

    expect(pricing.inputPerMillionUsd, 0);
    expect(pricing.outputPerMillionUsd, 0);
  });
}
