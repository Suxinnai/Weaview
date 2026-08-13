# Weaview UI Fidelity QA

## Scope

- Source visual truth: `design/prototypes/weaview-fidelity-polish/`
- Implementation: Flutter Android app under `lib/src/`
- Device evidence: Android emulator, 1080 × 2400 px physical screenshot
- Comparison viewport: both source and implementation normalized to 393 × 825 logical px. The 393 × 850 source boards were cropped only at the bottom safe-area before scaling; the emulator status/navigation bars were removed before scaling.
- State caveat: prototype samples intentionally contain populated conversations, providers and usage. The implementation captures use real local state and therefore show empty states when no API key, conversation or usage record exists.

## Evidence

### Full-view composites

- Home: `.omx/audits/weaview-ui/qa/home-full.png`
- Model picker: `.omx/audits/weaview-ui/qa/models-full.png`
- Sidebar: `.omx/audits/weaview-ui/qa/sidebar-full.png`
- Settings/general: `.omx/audits/weaview-ui/qa/settings-full.png`
- Settings/providers: `.omx/audits/weaview-ui/qa/providers-full.png`
- Workboard: `.omx/audits/weaview-ui/qa/workboard-full.png`
- Branch graph: `.omx/audits/weaview-ui/qa/branch-full.png`
- Usage: `.omx/audits/weaview-ui/qa/usage-full.png`

### Focused-region composites

- Home header: `.omx/audits/weaview-ui/qa/home-header.png`
- Home composer: `.omx/audits/weaview-ui/qa/home-composer.png`
- Theme selector: `.omx/audits/weaview-ui/qa/settings-theme.png`
- Provider rows: `.omx/audits/weaview-ui/qa/providers-list.png`

### Post-fix simulator captures

- `.omx/audits/weaview-ui/simulator/fidelity-final-build.png`
- `.omx/audits/weaview-ui/simulator/fidelity-home.png`
- `.omx/audits/weaview-ui/simulator/fidelity-models.png`
- `.omx/audits/weaview-ui/simulator/fidelity-sidebar.png`
- `.omx/audits/weaview-ui/simulator/fidelity-settings-final.png`
- `.omx/audits/weaview-ui/simulator/fidelity-providers-final.png`
- `.omx/audits/weaview-ui/simulator/fidelity-gemini-detail.png`
- `.omx/audits/weaview-ui/simulator/fidelity-gemini-models.png`
- `.omx/audits/weaview-ui/simulator/fidelity-workboard.png`
- `.omx/audits/weaview-ui/simulator/fidelity-branch.png`
- `.omx/audits/weaview-ui/simulator/fidelity-usage.png`
- `build/visual-qa/release-final-6s.png`
- `build/visual-qa/home-reference-comparison.png`
- `build/visual-qa/weaview-settings-restored.png`
- `build/visual-qa/weaview-providers-restored.png`
- `build/visual-qa/weaview-gemini-detail-restored.png`
- `build/visual-qa/weaview-v2.0.1-empty-home.png`
- `build/visual-qa/weaview-v2.0.1-home.png`
- `build/visual-qa/weaview-v2.0.1-actions.png`
- `build/visual-qa/weaview-v2.0.1-model-picker.png`
- `build/visual-qa/weaview-v2.0.1-settings.png`

## Comparison history

1. Iteration 1 found a P1/P2 horizontal overflow in the general-settings theme segmented control (33 px). Padding was reduced and sizing was made responsive.
2. Iteration 2 still showed a 9.3 px overflow. The final control now uses 1/1/2 flex allocation and fixed 40 px tap height. `fidelity-settings-final.png` has no overflow warning.
3. Provider settings initially reported all providers as configured because a default base URL was treated as credentials. Configuration status now depends on a usable API key/status, so the empty profile correctly reports the configured count.
4. Provider rows were reduced from 108 px to 82 px, and redundant switch/status content was removed for unconfigured providers. The row remains fully tappable and exposes the details page.
5. The comparison picker exposed an unbounded `Stack` at runtime. Its selected-model summary now has an explicit 36 px height and is protected by widget coverage.
6. A provider-row interaction regression was caught after styling; the `InkWell` navigation target was restored and verified.
7. The current correction restores six direct settings destinations (`通用 / 提供商 / 默认模型 / 扩展服务 / 数据管理 / 关于织境`) and removes the ambiguous “更多” bucket and no-op header search action.
8. Provider presets now use progressive disclosure: six general-purpose providers are visible initially and all 13 providers expand with a 240 ms ease-out size transition.
9. Accent color and nickname controls were verified both with widget tests and on the emulator; the theme transition respects Android reduced-motion settings.
10. The home screen was returned to its established branded hierarchy. The model selector, menu action and composer now use restrained translucent surfaces without adding onboarding copy or a competing new-session action.
11. Assistant avatar editing and emotional-response controls were restored to the general settings page and are covered by interaction tests.
12. Message action toggles are compact touch targets instead of full-width strips. HTTP failures are summarized in an actionable card, with raw payloads hidden under technical details.
13. Message actions now expand as a single short translucent capsule (under 220 px wide and 44 px high in widget verification), with compact copy, retry, edit, read-aloud and overflow controls positioned directly below the selected message.
14. Official Gemini image generation and connection testing use the native Interactions endpoint, while custom OpenAI-compatible Gemini gateways use `/chat/completions` and parse `message.images`; both routes retain the 1–4 image workflow.
15. Startup preference and conversation restoration now begin after Flutter's first frame, then heavy conversation migration completes without blocking the native splash. The same release emulator improved from roughly 8–9 seconds to 5.6 seconds to the first rendered app frame.

## Final findings

- P0: none.
- P1: none.
- P2: none.
- P3: populated prototype samples and honest empty implementation states differ by design; this avoids fabricated provider, task and billing data.
- P3: the implementation uses the platform Chinese font fallback rather than an unbundled Inter declaration, so glyph metrics vary slightly from the bitmap prototype while avoiding runtime font substitution issues.
- Golden-test renders on the host lack CJK fonts, so simulator captures are the authoritative typography evidence.

## Interaction verification

- Home menu, model picker, new-session action and composer controls.
- Model search/filter tabs, provider grouping, management entry and role-aware selection.
- Sidebar workspace shortcuts, history empty state, account/settings entry.
- Settings tabs, editable theme accent, nickname dialog, provider list and provider detail/model subpage.
- Assistant avatar picker and persisted emotional-response switch.
- Gemini model list includes all four requested image-model API IDs; mainstream image presets include OpenAI, Grok, Seedream, Recraft, Stability AI, FLUX, Ideogram and Replicate official models.
- Workboard, branch graph and usage-statistics navigation/back actions.
- Multi-image generation count (1–4), multi-select gallery, save-selected and full-screen preview affordances.
- Android release build starts past the splash screen, restores local configuration, and returns to the home screen without clearing application data.

## Result

The implemented UI preserves the app's original home identity, cool neutral palette, teal interaction color, rounded-card system, direct settings navigation and bottom composer while remaining truthful to local data. All discovered P0–P2 visual or interaction issues were fixed. The v2.0.1 empty-home comparison is captured in `build/visual-qa/home-reference-comparison.png`; the earlier real-device message action state is captured in `build/visual-qa/weaview-v2.0.1-actions.png`, while the current implementation expands all five action targets to 44 dp. Static analysis is clean and the complete 210-test suite passes with 60.93% line coverage. An Android debug APK builds successfully, and unsigned release builds are now explicitly blocked until production signing variables are provided.

final result: passed

---

## Settings refresh v2 implementation QA (2026-08-13)

### Scope

- Provider management: compact two-column cards, persistent drag ordering, long-press delete mode, and a distinct current-provider state.
- About: one condensed identity panel plus four non-duplicated destinations.
- General theme: three visual theme cards and an inline accent palette.
- Conversation history: recursive branch rows nested directly under their parent session.

### Combined comparison evidence

- Theme: `design/ui-concepts/settings-refresh-v2/implemented/theme-compare.png`
- Providers: `design/ui-concepts/settings-refresh-v2/implemented/providers-compare.png`
- About: `design/ui-concepts/settings-refresh-v2/implemented/about-compare.png`
- Branch conversations: `design/ui-concepts/settings-refresh-v2/implemented/branches-compare.png`
- Current-provider selected state: `design/ui-concepts/settings-refresh-v2/implemented/providers-current.png`

### Findings and corrections

1. The first provider implementation allowed card contents to determine width, producing uneven columns. The card surface now expands to the full grid cell width.
2. The provider screen contains no resting-state search, add, overflow, enable switch, or “view all” controls. Configuration remains available by tapping a card; sorting and deletion are intentionally moved behind long press.
3. The active provider is identified by a mint-tinted selected surface, border, check mark, and the single status line `当前 · N 个模型`.
4. Theme selection now communicates light, dark, and system-following behavior with direct previews instead of a dense segmented control. Accent colors stay visible and one-tap selectable.
5. About-page version data appears once in the identity panel; support and repository destinations are consolidated into four rows.
6. A branch created from an assistant message was verified on the emulator. It renders below the root conversation with an indented connector, `分支` badge, independent selection, and retained overflow actions.

### Verification

- Flutter static analysis: no issues.
- Full Flutter test suite: 216 tests passed.
- Focused post-layout provider/settings tests: 5 tests passed after the equal-width correction.
- Android debug APK built, installed, and launched on `emulator-5554` (`Pixel_9_Pro_XL_API_35`).

### Result

No P0–P2 visual or interaction defects remain in the four confirmed surfaces. Differences from the concept boards are limited to real device content, provider ordering, and platform font metrics.

final result: passed

---

## Default model roles and collapsible branches (2026-08-13)

- `设置 > 默认模型` now separates `核心模型` from `辅助任务` and exposes independent translation and title-generation assignments.
- Both new rows open the existing provider/model/system-prompt editor and use the established assignment persistence path.
- Conversations with branches now expose a compact chevron. Root collapse hides its full descendant tree; nested collapse hides only that branch's descendants.
- Expanded device evidence: `build/visual-qa/sidebar-branches-expanded.png`.
- Collapsed device evidence: `build/visual-qa/sidebar-branches-collapsed.png`.
- Default-model device evidence: `build/visual-qa/default-models-translation-title.png`.
- Full static analysis: no issues. Full Flutter suite: 218 tests passed.

final result: passed

---

## Model picker glass refresh (2026-08-13)

- Reworked the in-chat model picker as a compact glass surface with a clipped 30 px backdrop blur, translucent gradient, fine border, depth shadow, and restrained mint glow.
- Consolidated usage filters into one segmented glass rail, strengthened search focus feedback, and simplified model rows around capability chips plus a single `当前` status.
- Added provider/model counts and a compact management footer without obscuring the conversation behind the picker.
- Final emulator evidence: `build/visual-qa/model-picker-glass-v3.png`.
- Reference comparison: `build/visual-qa/model-picker-glass-compare.png`.
- Flutter static analysis: no issues. Full Flutter suite: 218 tests passed.

final result: passed
