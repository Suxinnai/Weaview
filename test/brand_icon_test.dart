import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/shared/widgets/brand_icon.dart';

void main() {
  test('brand icon registry prefers MiniMax over xAI substring matches', () {
    final asset = BrandIconRegistry.assetForModel(
      providerName: 'demo',
      model: const AiModel(
        id: 'nvidia/minimaxai/minimax-m2.7',
        name: 'nvidia/minimaxai/minimax-m2.7',
      ),
    );

    expect(asset, 'assets/icons/minimax-color.png');
  });
}
