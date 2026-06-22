# ヨミスロ Design System

パチスロの設定・収支を匿名で記録するCGMサイト。
打ち手が「ここ見とけば間違いない」と思えるUIを目指す。

## Overview

ダークモードデフォルトの情報密度高めなUI。
パチスロ店のホール感（暗い空間に光る情報）を意識しつつ、読みやすさとタップしやすさを最優先。
手書き風フォントで遊び心を出しつつ、データ部分はシャープに。

**トーン:** カジュアル・実用的。企業サイトではなく、打ち手の仲間が作ったツール感。

## Colors

### Semantic Tokens

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `--primary` | `#10b981` | `#34d399` | CTA、アクティブ状態、リンク |
| `--background` | `#fafafa` | `#0c0e14` | ページ背景 |
| `--foreground` | `#111827` | `#f4f4f5` | 主テキスト |
| `--card` | `#ffffff` | `#14161e` | カード背景 |
| `--secondary` | `#f3f4f6` | `#1c1e28` | セカンダリ背景 |
| `--muted` | `#f3f4f6` | `#1c1e28` | 控えめな背景 |
| `--muted-foreground` | `#6b7280` | `#8b8d98` | 補助テキスト |
| `--border` | `#e5e7eb` | `#252838` | ボーダー |
| `--destructive` | `#ef4444` | `#f87171` | 削除、エラー |
| `--surface-inset` | `#f0f1f3` | `#0a0c12` | 凹みサーフェス（統計エリア） |
| `--accent-muted` | `rgba(34,197,94,0.12)` | `rgba(74,222,128,0.12)` | アクセント背景（薄） |

### 設定ヒートマップ (setting-1 ~ setting-6)

パチスロの設定1~6を寒色→暖色で直感的に表現。

| 設定 | Light | Dark | 色名 |
|------|-------|------|------|
| 1 | `#3b82f6` | `#60a5fa` | Blue |
| 2 | `#06b6d4` | `#22d3ee` | Cyan |
| 3 | `#22c55e` | `#4ade80` | Green |
| 4 | `#eab308` | `#facc15` | Yellow |
| 5 | `#f97316` | `#fb923c` | Orange |
| 6 | `#ef4444` | `#f87171` | Red |

### 記録UI専用

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `--vote-yes` | `#22c55e` | `#4ade80` | リセット「あり」 |
| `--vote-no` | `#ef4444` | `#f87171` | リセット「なし」 |
| `--confirmed` | `#7c3aed` | `#a78bfa` | 確定演出（紫） |

### パチスロ演出カラー (ロゴ準拠)

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `--slot-blue` | `#3b82f6` | `#60a5fa` | 演出：青 |
| `--slot-yellow` | `#eab308` | `#facc15` | 演出：黄 |
| `--slot-green` | `#22c55e` | `#4ade80` | 演出：緑 |
| `--slot-red` | `#ef4444` | `#f87171` | 演出：赤 |

## Typography

| 用途 | フォント | クラス / トークン | 備考 |
|------|---------|------|------|
| 本文・UI | `Inter` + `M PLUS 1` | `--font-sans` (デフォルト) | Latin/数値はInter、日本語はM PLUS 1。汎用Noto脱却。本文ベースは `font-weight: 500`（暗背景で痩せ防止） |
| 数値表示 | `Inter` / `Geist Mono` | `.stat-number` | tabular-nums、データはシャープに |
| ブランド/見出し装飾 | `Uzura` | `font-heading` (`--font-heading`) | 手書き風、丸みのある親しみやすさ |
| ヒーロー装飾 | `ShigotoMemogaki` | inline 指定 | 手書きメモ風 |
| 特殊装飾 | `Anzumoji` | inline 指定 | 等幅手書き |

### タイポグラフィルール
- **個性は見出しで出す**: 量産デザイン（AI臭）から脱する最速の手段はフォント。汎用デフォルト（Inter/Noto単独）に頼らず、ブランド見出し・ヒーロー・主要セクション見出しには `font-heading`（手書き風 Uzura）を当てる
- **データはシャープに、見出しは手描きで**: 数値・表・機種名・ラベルなどデータ部分には絶対に手書きフォントを使わない（可読性最優先）。`font-heading` は装飾的な見出しに限定
- インラインの `style="font-family: 'Uzura'..."` は使わず、必ず `font-heading` ユーティリティを使う
- 見出し: `font-bold`, `letter-spacing: -0.025em`
- 数値: `.stat-number` (Inter/Geist Mono, tabular-nums, -0.04em, bold)
- テキスト階層: `--text-primary` → `--text-secondary` → `--text-tertiary`

## Elevation (サーフェス3段階)

カードを全て同じスタイルにしない。用途で使い分ける。

| レベル | クラス | 用途 |
|--------|--------|------|
| 標準カード | `bg-card rounded-lg border-b border-border/50` | 一覧行、情報表示 |
| インタラクティブ | `bg-card rounded-lg shadow-sm border-l-2 border-l-primary/20` | タップ可能なカード |
| 凹みサーフェス | `bg-surface-inset rounded-lg` | 統計エリア、集計表示 |

### その他のエフェクト
- グロウ: `.glow-primary` — プライマリカラーの柔らかい光彩
- ノイズテクスチャ: `.noise-texture` — 背景に微かなざらつき
- 設定ボタン選択時: `ring-2` + カラーグロウ shadow

## Components

### ボタン
- 角丸: `rounded-lg` (10px)
- プライマリ: `bg-primary text-primary-foreground`
- 記録ボタン（設定1~6）: 対応する `setting-*` カラー、選択時 `ring-2`
- リセットボタン: `vote-yes` / `vote-no` カラー

### フォームコントロール
- ダークモード: `bg-secondary border-border text-foreground`
- placeholder: `text-muted-foreground`
- フォーカス: `outline: 2px solid var(--ring)`, `outline-offset: 2px`

### 記録行 (machine_vote_row)
- Turbo Frame で部分更新
- コンパクトさ重視（縦幅を抑える）
- 機種名 + 設定ボタン6個 + リセットボタン を1行に収める

### アコーディオン
- アニメーション: `accordion-down` / `accordion-up` (0.2s ease-out)
- Stimulus `accordion` コントローラで制御

### アニメーション
- フェードイン: `fade-in 0.3s`
- スライド: `slide-in-up/down/left/right 0.3s`
- 記録成功: `vote-success` (scale bounce)
- パルス: `pulse-once 0.6s`

## Layout

### モバイルファースト
- デフォルト: モバイル幅
- `sm:` (640px~) でデスクトップ対応
- タップ領域: 最小 44x44px
- 横スクロール: `overflow-x: hidden` で防止

### ダークモード
- `.dark` クラスベース（Stimulus `theme` コントローラで制御）
- デフォルトはダーク
- `@custom-variant dark (&:is(.dark *))` で Tailwind v4 対応

### ページ構成
- ホーム: 2ゾーンタブ (店舗・設定 / マイデータ)
- 店舗ページ: 機種一覧 → 記録UI (Turbo Frame)
- 県ページ: 市区町村グループ → 店舗一覧

## 脱・量産デザイン（Anti-AIっぽさ）

AIコード生成は「ネット上の最頻出パターン＝中央値の見た目」に収束する（distributional convergence）。放置すると全サイトが同じ顔になる。ヨミスロは以下を守って「打ち手の仲間が作ったツール」の固有の見た目を維持する。効果の大きい順:

1. **タイポグラフィで差別化する（最優先）** — Inter/Noto単独の汎用デフォルトに頼らない。見出しは `font-heading`。詳細は Typography 参照
2. **レイアウトのデフォルトを壊す** — 「左右対称の巨大ヒーロー＋均等な4枚カードグリッド」は典型的なAI臭。非対称・情報密度・余白の強弱で個性を出す（例: ホームのヒーローは手書きタグライン ←→ 統計数値の非対称分割）
3. **全カードを同一スタイルにしない** — 3段階サーフェス（標準/インタラクティブ/凹み）を用途で使い分ける。`bg-surface-inset rounded-lg p-3` を全カードにコピペしない（shadcn/uiテンプレ感が出る）
4. **人間味のある素材を混ぜる** — ストック画像/AI画像より実店舗・実機の写真。`noise-texture` のような微かな質感もOK（real > perfect）
5. **モーションは意味のあるものだけ** — 装飾アニメではなく「記録できた」等のフィードバック。`vote-success` / `pulse-once` のように動作に紐づくもの

### AI臭チェックリスト（design-check と併用）
- [ ] 見出しが汎用デフォルトフォントのまま放置されていないか（`font-heading` の検討）
- [ ] 青〜紫グラデーション、レインボーを使っていないか（→ Don'ts）
- [ ] 角丸が全要素 `rounded-xl`(16px) で機械的に統一されていないか（ヨミスロは10pxベース＋用途で使い分け）
- [ ] 「最適化」「集約」「ソリューション」等の空疎・硬いコピーが無いか（→ copy-reviewer）
- [ ] カードが全部同一スタイルの単調グリッドになっていないか

## Do's and Don'ts

### Do's
- セマンティックトークン (`--primary`, `--card` 等) を使う。ハードコードHEX値は避ける
- 3段階サーフェスを用途で使い分ける
- 数値は `.stat-number` クラスで統一
- コピー文は打ち手の口調 — 「ポチるだけ」「アテになる」「勝手にまとまる」
- 設定カラーは必ず1=blue→6=redのヒートマップ順
- ダークモードを常に考慮（CSS変数で自動切替）
- タップ領域44px以上を確保

### Don'ts
- レインボーグラデーション (4色以上) を使わない
- グラデーションブロブ背景を使わない
- 日本語テキストにグラデーントを適用しない
- 全カード同一スタイルにしない (shadcn/uiテンプレート感が出る)
- 「集合知」「可視化」「集約」「ソリューション」のような硬い用語を使わない
- ネオングリーン (#00ff00系) をプライマリにしない。エメラルド系を維持
- 企業サイト風の説明文を書かない — 友達に説明する感覚
- AIっぽいテンプレートデザインにしない
- Tailwind v4 で `hidden` と `flex`/`grid` を同じ要素に併用しない (表示切替は `style.display` で制御)
