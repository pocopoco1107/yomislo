---
name: design-check
description: >
  DESIGN.md の規約違反（ハードコードHEX、レインボーグラデーション、Tailwind v4の hidden+flex競合、
  AIっぽい禁止用語、Turbo Frame内の広告配置など）を変更ファイルから自動検出する。
  Use when ユーザーが「design-check」「デザインチェック」「DESIGN.md準拠確認」を依頼したとき、
  または .erb / .css / .html を編集した直後にレビューを求めたとき。
---

# Design Check

DESIGN.md の規約に違反していないか自動検出するスキル。
`.erb` / `.html` / `.css` / `.js` の変更内容を grep ベースで横断スキャンする。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff を確認（既定） | `.claude/skills/design-check/check.sh` |
| 特定ファイルを確認 | `.claude/skills/design-check/check.sh app/views/shops/show.html.erb` |
| プロジェクト全体 | `.claude/skills/design-check/check.sh --all` |

ユーザーが `/design-check` と打ったら、引数なしで diff モードで実行する。

```bash
cd /Users/kasedashouta/Desktop/develop/yomislo && .claude/skills/design-check/check.sh
```

## 検出ルール

| ID | 重要度 | 内容 | DESIGN.md 該当 |
|----|--------|------|----------------|
| hardcoded-hex | WARN | `#xxxxxx` / `#xxx` 直書き | Do's: セマンティックトークン |
| raw-rgb | WARN | `rgb()` / `rgba()` 直書き | Do's: CSS変数経由 |
| rainbow-gradient | **FAIL** | `via-*` を2つ以上含むグラデーション | Don'ts: レインボー禁止 |
| gradient-blob | WARN | `blur-3xl` + `opacity` の組み合わせ | Don'ts: グラデーションブロブ禁止 |
| japanese-gradient-text | WARN | `bg-clip-text` + `text-transparent` | Don'ts: 日本語にグラデーション禁止 |
| hidden-flex-conflict | **FAIL** | `hidden` と `flex`/`grid` の併用 | Don'ts: Tailwind v4 既知バグ |
| banned-copy-words | WARN | `集合知`/`可視化`/`集約`/`ソリューション`/`最適化された` | Don'ts: 硬い用語禁止 |
| neon-green | **FAIL** | `#00ff00` / `#0f0` / `rgb(0,255,0)` | Don'ts: エメラルド系を維持 |
| promotion-in-frame | WARN | 同一ファイルに `turbo_frame_tag` と `render_promotion` | CLAUDE.md: Turbo Frame内禁止 |

## 結果の読み方

- ✅ **違反なし**: そのまま OK
- ⚠️ **WARN**: 修正推奨だが文脈次第（例: `#xxxxxx` が DESIGN.md 自身に書かれた色見本なら無視）
- ❌ **FAIL**: 修正必須（exit code 1）

## ユーザーへの報告フォーマット

実行後、こう要約:

```
## design-check 結果

| カテゴリ | 件数 | 状態 |
|---------|------|------|
| FAIL    | 0    | ✅ |
| WARN    | 1    | ⚠️ |

### 詳細
- `promotion-in-frame`: app/views/shops/show.html.erb
  → Turbo Frame と render_promotion が同居。Frame外に出すか確認

**結論**: ✅ FAIL なし / ⚠️ 要確認 1 件
```

## 限界

- grep ベースのため、`<% if false %>` 内のコードや CSSコメント内の HEX も拾う → 誤検知の可能性
- erb のヘルパーメソッド経由で色を渡している場合は検出できない
- Turbo Frame `内` か `外` かはファイル単位の検出のみ（要目視確認）

## 関連

- [DESIGN.md](../../../DESIGN.md) — 規約本体
- [[feedback_design_system]] — エメラルドプライマリ、3段階サーフェスの背景
- [[feedback_tailwind_v4_display]] — hidden+flex競合の経緯
- [[feedback_copywriting]] — 禁止用語の背景
