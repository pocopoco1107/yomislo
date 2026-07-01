# ヨミスロ Design System

パチスロの設定・収支を匿名で記録するCGMサイト。
打ち手が「ここ見とけば間違いない」と思えるUIを目指す。

## Overview

ダークモードデフォルトの情報密度高めなUI。**緑基調の8bit/ファミコン調レトロ**（漆黒寄り背景＋ドット絵フォント＋▶メニューカーソル＋ドット絵アイコン＋四角ばった角＋エメラルド緑のアクセント）。
パチスロ店のホール感（暗い空間に光る情報）を意識しつつ、読みやすさとタップしやすさを最優先。相棒ペット（ドット絵）と世界観を統一する。

**トーン:** 緑基調のレトロゲーム。企業サイトではなく、打ち手の仲間が作ったツール感。レトロ感は「フォント＋▶カーソル＋配色＋四角ばり＋ドット絵アイコン」で出す。**白枠のコマンドウィンドウ（`.rpg-window`）は乱用しない**（ゲームでも1画面に窓は1つ）——進化トースト等の一時ポップアップに限定。**記録UI（投票ボタン・機種リスト・フォーム）・本文・桁数値の可読性とタップ性は絶対に犠牲にしない**。

> ⚠️ 過去に「フルドラクエ化（白枠コマンドウィンドウを多用＋漆黒）」を試したが、(1) 窓の多用で見づらい・ゲーム的に不自然 (2) 緑基調とドラクエ青で世界観が中途半端 (3) クリック対象が不明瞭、との指摘で**緑基調8bitへ方針転換**。窓の多用には戻さないこと。

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
| `--rpg-frame` | `#1f2937` | `#e8eaf2` | コマンドウィンドウ枠（外縁。`.rpg-window`） |
| `--rpg-frame-inner` | `#ffffff` | `#11131c` | コマンドウィンドウ枠（内側の明線） |
| `--rpg-window-bg` | `#ffffff` | `#0a0c14` | コマンドウィンドウ内側の地色（`.rpg-window` が自前で適用） |

> **角丸（`--radius`）はファミコン調で `0.2rem`（≈3px）に四角ばらせている**。`rounded-lg`≈3px / `rounded-md`≈1px。`rounded-full`（ピル）は別系統で従来どおり。
> **ダークパレットは漆黒寄り**（`--background: #07080f` / `--card: #14161f` / `--surface-inset: #0c0e16`）。カードは背景より少し明るく＋薄ボーダーで境界（＝クリック対象）を見せる。
> `--rpg-frame*` / `--rpg-window-bg` は `.rpg-window`（進化トースト等の一時ポップアップ限定）でのみ使用。

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
| 数値表示（一般） | `Inter` / `Geist Mono` | `.stat-number` | tabular-nums、データはシャープに。桁の多い金額・表内の数値はこれ |
| 大きなスコア数値 | `DotGothic16` → `Inter` | `.score-num` | ポイント/順位/件数/ストリーク等「大きく見せる数字」**だけ**ドット絵に。小さい数字・桁の多い金額には使わない |
| ブランド/見出し装飾 | `DotGothic16` | `font-heading` (`--font-heading`) | ドット絵でレトロRPG感。単一ウェイト(400)だと本文より細く見劣りするため**擬似ボールド(700)で太らせる**（下記ルール参照） |
| ヒーロー装飾 | `ShigotoMemogaki` | inline 指定 | 手書きメモ風（補助） |
| 特殊装飾 | `Anzumoji` | inline 指定 | 等幅手書き（補助） |

### タイポグラフィルール
- **個性は見出しで出す**: 量産デザイン（AI臭）から脱する最速の手段はフォント。汎用デフォルト（Inter/Noto単独）に頼らず、ブランド見出し・ヒーロー・主要セクション見出しには `font-heading`（ドット絵 DotGothic16）を当てる
- **セクション見出しは `section_heading` ヘルパーで統一** ([app/helpers/ui_helper.rb](app/helpers/ui_helper.rb))。`<h2>` を手書きするのではなく `section_heading "店舗情報", accent: :yellow, extra: "mb-3"` を使う。`font-heading` 適用と**ドラクエ風 ▶ メニューカーソル**（accent色）を同時に担保する
  - accent: `:primary` `:yellow` `:red` `:blue` `:green` `:confirmed`（▶カーソルの色＝意味。乱用しない）／ size: `:sm`(14px) `:base`(16px) `:lg`(18px)
  - ▶カーソルを手書きする場合は `<span class="text-[0.7em] text-{accent}" aria-hidden="true">▶</span>`（右側に別要素を置く見出し等、ヘルパーに収まらない時のみ）
- **ドット絵フォントは擬似ボールド(700)で太らせる**: DotGothic16 は単一ウェイト(400)で、そのままだと周囲の本文(500)より細く見劣りする。DotGothic16 はアウトライン系なので擬似ボールドでもドットが極端には潰れない。`.font-heading` 側で `font-weight: 700 !important`、`.score-num` も `font-weight: 700`。字間 `0.04em` で隣接ドットの結合を防ぐ（light/darkともに検証済）
- **データはシャープに、見出しはドット絵で**: 数値・表・機種名・ラベルなどデータ部分・本文・桁の多い金額には絶対にドット絵フォントを使わない（可読性最優先）。`font-heading` は装飾的な見出しに、`.score-num` は「大きく見せるスコア数値」に限定
- **小さい数字にドット絵を使わない**: DotGothic16 は `text-xs`(12px) 以下だと数字が潰れて読みにくい。`.score-num` は `text-sm`(14px) 以上の数値にだけ付ける。位/件 等の小さい単位サフィックスは `font-sans` でInterに戻す
- インラインの `style="font-family: ..."` は使わず、必ず `font-heading` ユーティリティを使う
- 見出し: `letter-spacing: -0.025em`（ただし `.font-heading` は weight 700・`0.04em` でドットの太さと可読性を両立）
- 数値: 一般は `.stat-number` (Inter/Geist Mono, tabular-nums, -0.04em, bold)、大きなスコアは `.score-num` (DotGothic16, tabular-nums, weight 700)
- テキスト階層: `--text-primary` → `--text-secondary` → `--text-tertiary`

### フォントサイズスケール
量産感は「サイズの細切れ」からも出る。任意値の乱用を避け、下記スケールに寄せる。
- 本文・ラベルの**最小は `text-xs`(12px)**。`text-[10px]` / `text-[9px]` を本文・説明・小見出しに使わない
- 極小バッジ（display_type 等、1行記録UIのみ）に限り `text-[11px]` を許容
- 階層: `text-[11px]`(極小バッジ) → `text-xs`(12px 補助/メタ) → `text-sm`(14px 本文/小見出し) → `text-base`(16px セクション見出し) → `text-lg`+(主要見出し)

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
- 角丸: `rounded-lg`（`--radius` により ≈3px の四角ばり。ファミコン調）
- プライマリ: `bg-primary text-primary-foreground`
- 記録ボタン（設定1~6）: 対応する `setting-*` カラー、選択時 `ring-2`
- リセットボタン: `vote-yes` / `vote-no` カラー

### フォームコントロール
- ダークモード: `bg-secondary border-border text-foreground`
- placeholder: `text-muted-foreground`
- フォーカス: `outline: 2px solid var(--ring)`, `outline-offset: 2px`

### コマンドウィンドウ枠 (`.rpg-window`) — ⚠️ 乱用禁止
- ドラクエ風の白い二重縁取り（box-shadowの多重リング、追加DOMなし）。`--rpg-frame` / `--rpg-frame-inner` トークン、ライト/ダーク自動対応。`.rpg-window` 自身が地色 (`--rpg-window-bg`) と角丸4pxを持つので `bg-card`/`rounded-*`/`border-*` は付けない
- **1画面に窓は1つが原則**。トースト（進化 / マイルストーン）は一時ポップアップなので別カウント。ページ内の永続配置は下記のみ：
  - `shops/show` の店舗ヘッダー（そのページの主役1枚として）
  - `voter/status` の相棒＆称号カード（「ぼうけんのしょ」の主役1枚として）
- カードやリスト・機種行を枠で囲むのは禁止（見づらい・不自然・緑基調と中途半端になる）
- 通常のカードは `bg-card rounded-lg border border-border/60`（必要なら左アクセント `border-l-2 border-l-{accent}`）で表現する

### ▶ メニューカーソル (`.dq-cursor` / `section_heading`)
- ドラクエのコマンド選択カーソル。見出しには `section_heading`（accent色の静的▶）。「選択中」を示す要素（アクティブな下部ナビ等）には `.dq-cursor.dq-cursor--blink`（点滅、`reduced-motion`で停止）
- 色は `currentColor` 継承（`.dq-cursor`）か accent 色（見出し）

### アイコン（下部ナビ等）
- **下部ナビは標準の線画SVGアイコン**（[app/views/shared/_bottom_tab_bar.html.erb](app/views/shared/_bottom_tab_bar.html.erb)）。色は親の `text-*`（アクティブ=primary）を継承し、アクティブは fill 塗り＋ラベルに点滅▶（`.dq-cursor--blink`）
- ⚠️ ドット絵（`<rect>` 8bit）アイコンを試したが **20px では虫眼鏡/コインが判別できず断念**。小サイズのアイコンは線画で可読性を優先する（レトロ感はフォント・▶・配色・四角ばりで出す）

### 記録行 (machine_vote_row)
- Turbo Frame で部分更新
- コンパクトさ重視（縦幅を抑える）
- 機種名 + 設定ボタン6個 + リセットボタン を1行に収める
- **RPG装飾（ドット絵フォント・ウィンドウ枠）を持ち込まない**（記録動線の可読性・操作性が最優先）

### ドット分割バー (`dot_bar` ヘルパー)
- HP/MP風のドット分割プログレスバー。[app/helpers/ui_helper.rb](app/helpers/ui_helper.rb) の `dot_bar(current, total, color:, segments:, height:, label:, value:)`
- パチスロ演出カラー (`:primary`/`:green`/`:blue`/`:yellow`/`:red`/`:confirmed`) の中から意味に紐付けて選ぶ
- 「ぼうけんのしょ」(voter/status) のつよさバー、ペット進化バーで使用。**通常のリニアバー (`.h-1.5 bg-secondary`) は残してもOK**（併存 → 用途で使い分け）
- `role="progressbar"` + `aria-valuenow/min/max/label` 自動付与 (a11y準拠)

### トースト / 記録フィードバック
[app/views/layouts/application.html.erb](app/views/layouts/application.html.erb) の `#pet_toast` (fixed bottom, z-50) に turbo_stream で append。3種混在OK、階層は「サイズ」で表現：

| 種類 | パーシャル | 用途 | サイズ | 発火頻度 |
|---|---|---|---|---|
| ゴールドトースト | `votes/_gold_toast.html.erb` | 新規記録ごとの「+N ゴールド」 | 丸ピル(小) | 毎回 |
| マイルストーントースト | `votes/_milestone_toast.html.erb` | 節目到達 (10/100/1000件、7/30日連続、初高設定) | `.rpg-window--glow`(中) | 生涯数回 |
| 進化トースト | `pets/_evolution_toast.html.erb` | Pet進化 (baby→child→adult) | `.rpg-window--glow`(中) | 各2〜3回 |

- **鬱陶しさ回避**: 大きい演出（rpg-window 系）は節目のみ。毎回のフィードバックは小さいピルに徹する
- `dismissable` controller で自動フェード。`delay-value`: 1400ms (gold) / 5000ms (milestone) / 4000ms (evolution)
- 「毎回フルスクリーン演出」はNG (打ち手が1日に何回もタップする動線を阻害する)

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
- ホーム: 2ゾーンタブ (店舗・設定 / マイデータ)。地域は「都道府県からさがす」7地域タイル（地域固有色の▶＋DotGothic16見出し＋件数）。中身はアコーディオンで都道府県chipsを展開
- 店舗ページ: `.rpg-window` の店舗ヘッダー → 機種一覧 → 記録UI (Turbo Frame)
- 県ページ: 市区町村グループ → 店舗一覧
- マイステータス (voter/status): 「ぼうけんのしょ」レイアウト。相棒＆称号カード (`.rpg-window`) → 「▶ つよさ」窓 (dot_bar 3本)  → 副次Stats → 的中率 → 最近の記録

### テーマ強化: 夜=ダンジョン / 昼=そうげん
- ダーク時: `body::before` に固定スキャンライン (opacity 0.35, pointer-events:none, reduced-motion対応)。ファミコンCRT感を演出しつつ、可読性・タップ性は無干渉
- ライト時: ホームヒーロー等に `.world-meadow` クラスで空→草原の極薄グラデを敷ける (既存 `.noise-texture` と両立、`::after` レイヤ)
- 既存 dark/light テーマの延長として実装。「モード追加」概念は増やさない

## Spacing（余白）

余白の不統一もゴチャつきの原因。下記に寄せてリズムを揃える。

| 用途 | カードpadding | 要素間gap |
|------|--------------|-----------|
| コンパクト（記録行・リスト行） | `p-3` | `gap-2` |
| 標準（情報カード・統計） | `p-4` | `gap-3` |
| 開放的（主要セクション） | `p-5` | `gap-4` |

- セクション間マージンは `mb-4`（標準）/ `mb-6`（区切り）に統一
- モバイル/デスクトップで段差を作る場合のみ `md:` を足す（`p-4 md:p-5` 等）

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
- [ ] 角丸が丸すぎないか（ヨミスロはファミコン調で `--radius`≈3px の四角ばり。`rounded-xl` 等の大きな丸みは使わない）
- [ ] 「最適化」「集約」「ソリューション」等の空疎・硬いコピーが無いか（→ copy-reviewer）
- [ ] カードが全部同一スタイルの単調グリッドになっていないか

## アクセシビリティ (WCAG 2.1 AA) チェックリスト

ヨミスロは緑基調ビビッドカラー＋ファミコン調なので、特に **コントラスト** と **ドット絵フォントの可読性** で落ちやすい。新しい色組み合わせ・モーダル・トグルUIを足すときは下記を必ず通すこと。

- [ ] **コントラスト 4.5:1 以上** — `bg-primary text-primary-foreground` / `bg-vote-* text-*` / `bg-setting-* text-*` 等の組み合わせは原則 AA Normal を満たす値で実装。明るい背景(setting-2〜5/vote-yes/vote-no) は **`text-gray-900`** を使い、暗い背景(setting-1/setting-6) のみ `text-white` を許容。`--primary` (light) は `#059669` で固定（`#10b981` は CTA 用としては NG）
- [ ] **トグルボタンの aria-pressed** — お気に入り星・確定設定トグル等、状態を持つボタンは Stimulus の `connect()` 時に `aria-pressed`/`aria-label` を必ずトグル。初期 HTML 上で `aria-pressed="false"` を書くだけにしない
- [ ] **`prefers-reduced-motion` で全アニメ停止** — 自前で `@keyframes` を足したらグローバルの `@media (prefers-reduced-motion: reduce)` ブロックで止まるか確認。新規 `animate-*` を独自実装した場合は対象に含まれているか確認
- [ ] **DotGothic16 は 14px 未満で使わない** — `.font-heading` / `.score-num` (700) は見出し・大きなスコアに限定。本文・表・補足ラベル（`text-xs` 以下）には絶対に当てない（ドットがにじんで判読不能になる）
- [ ] **モーダル/ダイアログに `role="dialog"` + `aria-modal="true"` + `aria-labelledby` + focus 管理** — open 時にパネルへ `focus()` を移し、close 時に直前のフォーカス要素へ戻す（`record_modal_controller.js` 参照）。`tabindex="-1"` をパネルに付ける

## Do's and Don'ts

### Do's
- セマンティックトークン (`--primary`, `--card` 等) を使う。ハードコードHEX値は避ける
- 3段階サーフェスを用途で使い分ける
- 一般の数値は `.stat-number`、大きなスコア数値は `.score-num`（ドット絵）で統一
- RPGウィンドウ枠 (`.rpg-window`) は主役級のフィーチャーカードに限定して使う
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
- ドット絵フォント（DotGothic16）を本文・機種名・表・桁の多い金額・`text-xs`以下の小さい数字に使わない（可読性が落ちる）
- ドット絵フォントを weight 400 のまま使わない（細く見劣りする → `.font-heading`/`.score-num` は 700 で太らせる）
- RPGウィンドウ枠を記録UI・一覧行・フォームに使わない（操作性・情報密度を損なう）
