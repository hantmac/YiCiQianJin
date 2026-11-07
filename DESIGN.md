# 小象单词 设计规范

更新：2026-11-07

## 方向
夜读用的烫金词典：深墨蓝纸面，金色只用在主动作和奖励上，英文单词像词典词条一样用衬线大字。（用户确认：升级档，深墨蓝底配暖金，衬线词条，首页只留一个主卡）

## 品牌资产（不动）
- 小象吉祥物 `Mascot`（用户确认）
- 「千金」金币与金色（用户确认）
- Word Atlas「一词一画」插画（用户确认）

## 语义角色
变量在 `YiCiQianJin/Views/Theme.swift`，这里只写用途。
- `Theme.bgTop/bgBottom` + `AppBackground`：所有页面的底，不再用紫色渐变。
- `Theme.textPrimary/textSecondary/textTertiary`：文字三级，不直接写 `.white`。（Agent 推断）
- `Theme.surface`：普通卡片；`Theme.surfaceStrong`：每屏唯一的主卡或题干卡。（Agent 推断）
- `Theme.gold/goldGradient`：主按钮、千金、金卡、已通过的记忆节点。一屏只有一个金色大按钮；其他动作用 `GlassButtonStyle`。（用户确认）
- `Theme.silver`：银卡与图表里的次要数据。`Theme.flame`：连胜与「快要忘了」。`Theme.correct/wrong`：答题对错。（Agent 推断）
- 字体：英文单词用 `Theme.wordFont`（New York 衬线）；大数字用 `Theme.number` 或 `.serif`；中文界面文字用系统字体，不用衬线。（Agent 推断）
- 形状：卡片圆角 `Theme.radius`（20），主卡 24，按钮 16；描边统一 `Theme.stroke` 细线，不加投影，金色按钮和金卡除外。（Agent 推断）
- 动效：按压 `.spring(duration: 0.2)` 缩放 0.97–0.98；页面与题目切换沿用 `ContentView`/`QuizView` 的移入淡出；尊重 `accessibilityReduceMotion`。（Agent 推断）

## 可用组件
- `card()`、`GoldButtonStyle`、`GlassButtonStyle`、`PressableStyle`、`CapsuleBar`、`ProgressRing`、`SpeakButton`、`CoinLabel`：`Theme.swift`。
- `MemoryNodeTrack`、`RetentionBar`、`MemorySparkline`、`WordMemorySheet`、`MemoryFormat`：`Views/MemoryComponents.swift`。
- `GameSummaryView`：`Views/GamesView.swift`，所有游戏结算页共用。

## 样板页面
- `YiCiQianJin/Views/HomeView.swift`：主卡（含三步进度）+ 记忆曲线卡 + 2×2 入口 + 词书 + 等级行。
- `YiCiQianJin/Views/MemoryCurveView.swift`：图表卡片的写法。

## 不要做
- 不用白色半透明玻璃叠紫色渐变。
- 首页不再加独立的任务卡或大等级卡；新入口进 2×2 宫格。
- 金色不用于装饰性图标底色；朗读按钮是深色圆底金色图标。
