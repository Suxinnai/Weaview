# 织境 Weaview · Fidelity Polish 全页面原型

这套原型以当前应用已经形成的雾白、淡青蓝与鼠尾草绿视觉为基础，做控件、层级、密度和交互状态精修。产品定位保持为多模态 AI 对话助手；图片生成、联网搜索、附件与多模型对比均作为对话能力存在。

## 核心对话与导航

| 编号 | 页面 | 原型 |
| --- | --- | --- |
| 01 | 精修主页 | [查看](./01-home-refined.png) |
| 02 | 首页模型下拉 | [查看](./02-model-dropdown.png) |
| 03 | 侧边栏与会话历史 | [查看](./03-sidebar.png) |
| 04 | 正常多模态对话 | [查看](./04-conversation.png) |
| 05 | 输入器“+”工具面板 | [查看](./05-composer-tools.png) |

## 图片生成与多模型

| 编号 | 页面 | 原型 |
| --- | --- | --- |
| 06 | 图片生成模式配置 | [查看](./06-image-generation-mode.png) |
| 07 | 一次生成 4 张结果 | [查看](./07-image-results.png) |
| 08 | 单图查看与继续编辑 | [查看](./08-image-viewer.png) |
| 09 | 多模型对比选择器 | [查看](./09-comparison-picker.png) |
| 10 | 多模型对比结果 | [查看](./10-comparison-results.png) |

## 工作空间

| 编号 | 页面 | 原型 |
| --- | --- | --- |
| 11 | 分支图谱 | [查看](./11-branch-graph.png) |
| 12 | 工作台 | [查看](./12-workboard.png) |
| 13 | 用量统计 | [查看](./13-usage-stats.png) |

## 设置主分类与提供商

| 编号 | 页面 | 原型 |
| --- | --- | --- |
| 14 | 设置 · 通用 | [查看](./14-settings-general.png) |
| 15 | 设置 · 提供商 | [查看](./15-settings-providers.png) |
| 16 | Gemini 提供商详情 | [查看](./16-provider-gemini-detail.png) |
| 17 | 设置 · 默认模型 | [查看](./17-settings-default-models.png) |
| 18 | 设置 · 扩展服务 | [查看](./18-settings-extensions.png) |
| 19 | 设置 · 数据管理 | [查看](./19-settings-data.png) |
| 20 | 设置 · 关于织境 | [查看](./20-settings-about.png) |

## 设置子页面

| 编号 | 页面 | 原型 |
| --- | --- | --- |
| 21 | 全局系统提示词 | [查看](./21-system-prompt.png) |
| 22 | 人物画像 | [查看](./22-persona-profile.png) |
| 23 | 记忆管理 | [查看](./23-memory-management.png) |
| 24 | 搜索服务配置 | [查看](./24-search-service.png) |
| 25 | 语音服务配置 | [查看](./25-tts-service.png) |
| 26 | 报告问题与反馈 | [查看](./26-feedback.png) |

## 统一设计规则

- 页面底色：雾白，局部使用低饱和淡青蓝与鼠尾草绿柔光。
- 主要文字：深蓝灰；次级文字：中性蓝灰；强调色：克制青绿色。
- 圆角：输入器与浮层 22–28px，分组容器 20px，行内图标容器 12–16px。
- 描边：1px 冷灰；常规页面几乎无阴影，仅浮层和抽屉使用极轻层级阴影。
- 触控：可操作区域不小于 44px；常规设置行高 64–76px。
- 设置页优先使用“分组容器 + 连续列表 + 细分隔线”，避免每项一张大卡。
- 移动端复杂内容优先纵向阅读、顶部切换或半屏选择，不硬塞多列桌面布局。
- 图片生成属于对话工具；默认模型、工具面板与结果页均保持该定位。

## Gemini 图片模型覆盖

- `gemini-3.1-flash-lite-image` · Nano Banana 2 Lite
- `gemini-3.1-flash-image` · Nano Banana 2
- `gemini-3-pro-image` · Nano Banana Pro
- `gemini-2.5-flash-image` · Nano Banana

设计母版来源保留为 [00-selected-home-reference.png](./00-selected-home-reference.png)，当前模拟器参考截图也保留在本目录，便于实现时做前后对照。
