const minImageGenerationCount = 1;
const maxImageGenerationCount = 6;

int clampImageGenerationCount(int value) =>
    value.clamp(minImageGenerationCount, maxImageGenerationCount).toInt();
