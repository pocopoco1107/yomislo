# 相棒モンスター「ヨミ」キャラクター仕様書（発注用・叩き台 v0.2）

> このドキュメントは、ヨミスロの育成キャラ「ヨミ」のドット絵を **外部の画像生成AI / ドット絵職人に発注するための仕様書** です。
> 誰に・どのツールに投げても出力がブレないことを目的に、世界観・一貫性ルール・カラーパレット・サイズ・命名規則・プロンプト雛形までを固定します。
> ステータスは **叩き台（未確定）**。`要決定` タグの項目は発注前に確定させること。

---

## 0. これは何か（コンセプト）

ヨミスロは「パチスロの設定・リセット・収支を匿名ワンタップで記録するCGM」。
その記録行動に愛着と継続のフックを足すため、**ユーザーの記録データから育つ相棒モンスター「ヨミ」** を導入する。

- **餌＝記録**（賭けや課金ではない）。台を見て記録するほどヨミが育つ
- **打ち方でヨミの姿が変わる**（=系統分岐）。「自分のヨミは自分の打ち方そのもの」
- 卵から始まり、**可愛い幼体 → 熟練するほど凶暴でかっこいいモンスター**へ成長する（デジモン的な成長段階）

### 世界観の一文（キャラ設定の核）
> ホールにはむかしから "ヨミ" っていう小さいのが棲んでて、打ち手の記録を食って育つ。設定を読むやつのヨミ、朝イチに強いやつのヨミ、全国回るやつのヨミ——みんな育ち方が違う。

---

## 1. ブランド制約（MUST / NEVER）

ヨミスロのデザイン規約（`DESIGN.md`）に従う。キャラもこの世界観の中に置く。

### MUST
- **エメラルド基調**：体のベースカラーはブランドのプライマリ `#10b981 / #34d399`（emerald）系。これがキャラの"地"の色
- **ダークモード前提**：背景 `#0c0e14`（ほぼ黒）の上に置かれる。暗背景で映える明るめの発色・縁取りにする
- **透過背景（アルファ付きPNG）** で納品
- **キャラの一貫性**：全段階・全系統で「同じ生き物が育った」と分かる共通DNA（§3）を保つ
- 「打ち手の仲間が作ったツール」感。カジュアル・実用・親しみ

### NEVER
- **既存IPの意匠を使わない**：「デジモン風」はあくまで"成長して凶暴化する"という構造の参照のみ。デジモン/ポケモン等のデザイン・シルエット・配色の流用は厳禁（商標・著作権）
- レインボー（4色以上）グラデーション、グラデーションブロブ背景
- ネオングリーン `#00ff00` 系をプライマリにしない（エメラルドを維持）
- AIっぽいツルッとした量産マスコット感。ドット絵の「クセ・愛嬌」を活かす

---

## 2. 成長段階（縦軸：6段階）

ポイント（`VoterProfile.points`）に連動。既存の称号閾値と並走させる。

| # | 段階 | stageキー | pt目安 | 並走称号 | 見た目の温度感 | サイズ感 |
|---|------|-----------|--------|----------|----------------|----------|
| 1 | タマゴ | `egg` | 登録直後 | — | 卵。模様入り。たまに揺れる | 小 |
| 2 | 幼年期 | `baby` | 0–4 | 見習い | まんまる・特大の目・無防備に可愛い。手足なし | 小 |
| 3 | 成長期 | `growth` | 5–29 | 記録者 | 小さい角と乳歯みたいな牙。短い手足。ちょいモンスター | 中 |
| 4 | 成熟期 | `mature` | 30–199 | 常連〜目利き師 | 二足で立つ。角が伸び目が鋭くなる。**ここで系統が確定** | 中大 |
| 5 | 完成期 | `perfect` | 200+ | 設定看破マスター〜伝説 | トゲ・牙・翼。かっこいい／凶暴。系統の最終形 | 大 |
| 6 | 究極体 | `ultimate` | レア条件 | — | 完成期＋金オーラ・特別カラー・追加装飾 | 大 |

> **重要な設計**：
> - **卵→幼年期→成長期は全員まったく同じ一本道**（打ち方の差は姿に出ない）。**成熟期で初めて分岐**する
> - 幼年期で必ず「無防備に可愛い」を通す。最初に情がわくほど、凶暴体に育てた時の達成感が効く
> - 成熟期以降の分岐は「強さの段階差」ではなく、**かっこいい/美しい/おもしろい等の"魅力ベクトル"の違い**（デジモン式）。§4参照

---

## 3. キャラの共通DNA（一貫性ルール）

全段階・全系統で守る「これがヨミだ」と分かる固有要素。**発注時は必ずこのDNAを添える。**

- **シルエット**：縦長の卵型ボディが基本。頭と体の境界は曖昧（ずんぐり）
- **目**：左右に離れた大きめの丸い目。瞳は縦楕円。幼いほど目が大きく、熟練するほど細く鋭くなる
- **体色**：エメラルドの2〜3トーン（明 `#34d399` / 中 `#10b981` / 影 `#047857`）
- **額の「読みの印」**：額に小さな菱形（◇）マークが1つ。設定を"読む"象徴。全段階で残す（幼年期は薄く、究極体は発光）
- **口元**：への字〜にやり。感情で変わるが牙の有無で段階を表現
- **質感**：つるっとさせない。1〜2pxの縁取り（`#064e3b` 濃緑）で輪郭を締める

---

## 4. 系統（横軸：4系統）

成熟期（`mature`）以降で分岐。判定は `VoterProfile` の傾向スコア最大値で決定（§ ロジックは別途実装仕様で）。
**タマゴ・幼年期・成長期は系統共通（未分岐）。**

| 系統 | speciesキー | 打ち手像 | アクセント色（既存トークン） | 見た目の方向性 |
|------|-------------|----------|------------------------------|----------------|
| 読み師系 | `reader` | 設定を読んで当てる職人 | 紫 `#a78bfa / #7c3aed`（確定演出カラー） | 賢者風。片眼鏡／第三の目、流れるような角。理知的で静か | 
| 朝駆け系 | `dawn` | 朝イチ・リセット狙い | 橙 `#fb923c / #f97316`（朝日） | 俊敏。鶏冠状のトゲ、引き締まった体。背に朝日のオーラ |
| 行脚系 | `wanderer` | 全国の店を回る放浪型 | 青 `#60a5fa / #3b82f6`（slot-blue） | 旅装束（笠・マント）、長い脚、風のエフェクト |
| ヌシ系 | `nushi` | ホームを掘り下げる常連 | 深緑＋金 `#059669` + `#facc15` | 一番大柄で貫禄。重厚な角、苔や注連縄っぽい装飾。"主"の風格 |

> 系統差は **角・目の光・装飾・オーラの色** で出す。体のエメラルドは保つ＝ブランド統一。
> 行脚系↔ヌシ系は「広く薄く↔狭く深く」で背反。シルエットも「すらり↔どっしり」で対比させる。

---

## 5. 制作スコープ（作る数の現実解）

全段階×全系統 = 6×4 でも、未分岐3段階は共通なので **実数は 15体**。

```
共通（系統なし）:  common_egg / common_baby / common_growth        … 3体
読み師系:          reader_mature / reader_perfect / reader_ultimate … 3体
朝駆け系:          dawn_mature / dawn_perfect / dawn_ultimate       … 3体
行脚系:            wanderer_mature / wanderer_perfect / wanderer_ultimate … 3体
ヌシ系:            nushi_mature / nushi_perfect / nushi_ultimate    … 3体
合計 15体（＋横断差分: §9）
```

> **ロードマップ**：いきなり15体は破綻する。まず **読み師系の1ライン（egg→baby→growth→reader_mature→reader_perfect→reader_ultimate / 6体）** を試作して様式を確定 → 残り系統へ横展開。

---

## 6. カラーパレット（indexed / ドット絵用）

ドット絵はパレットを絞るほど締まる。**1キャラ最大8〜10色**を目安。

### 共通パレット（全キャラ）
| 役割 | キー | HEX | 備考 |
|------|------|-----|------|
| 体・明 | `body-l` | `#34d399` | ハイライト面 |
| 体・中 | `body-m` | `#10b981` | ベース（emerald-500） |
| 体・影 | `body-d` | `#047857` | 陰・下半身 |
| 輪郭 | `outline` | `#064e3b` | 1〜2px縁取り |
| 目・白 | `eye-w` | `#f4f4f5` | |
| 瞳 | `pupil` | `#0c0e14` | 背景色＝ほぼ黒 |
| 凶暴な目（完成期+） | `eye-fierce` | 系統アクセント色 | 光る目 |

### 系統アクセント（角・装飾・目の光・オーラ）
| 系統 | accent-light | accent-dark |
|------|--------------|-------------|
| `reader` | `#a78bfa` | `#7c3aed` |
| `dawn` | `#fb923c` | `#f97316` |
| `wanderer` | `#60a5fa` | `#3b82f6` |
| `nushi` | `#34d399`（濃緑 `#059669`） | 金縁 `#facc15` |

### 横断（究極体・特別状態）
| 役割 | HEX | 用途 |
|------|-----|------|
| 金オーラ | `#facc15` | 究極体の発光、30日ストリークの金色化 |
| 勝ち運 | `#facc15`（薄グロウ） | 収支プラス継続バフ（全系統に重ねる） |

---

## 7. ドット絵 技術仕様

| 項目 | 仕様 |
|------|------|
| 原画解像度 | **48×48px**（キャラが収まる範囲。余白含む。要決定で 32 or 64 も検討） |
| 表示 | 整数倍スケール（×2 / ×3）、`image-rendering: pixelated` |
| 背景 | **透過（アルファPNG）** |
| アンチエイリアス | **なし**（crisp pixel。ぼかし禁止） |
| パレット | 1キャラ8〜10色以内（§6準拠） |
| 向き | 正面やや見下ろし（idle）。1キャラ1ポーズでOK |
| 余白 | キャラ周囲に最低2pxの透明余白（スケール時の見切れ防止） |

---

## 8. アニメーション仕様（「少し動く」）

待機（idle）の小モーションで"生きてる感"を出す。**過剰に動かさない**（DESIGN.md：意味のあるモーションのみ）。

| 種別 | 内容 | フレーム数 | 備考 |
|------|------|-----------|------|
| idle | 上下にプニッと伸縮＋まばたき | 2〜4コマ | 全段階に付ける。ループ |
| タマゴ揺れ | 卵が左右にコトッ、たまにヒビ | 2〜3コマ | 孵化前の"気配" |
| 進化演出 | 白フラッシュ → 新フォーム登場 | 共通エフェクトで可 | コマ別に持たず汎用化 |
| 究極体オーラ | 金色オーラのゆらぎ | 2コマ or CSS opacity | |

### 実装方式（推奨）
- **スプライトシート＋CSS `steps()`**：idleの数コマを横1列PNGに並べ、`background-position` を `steps(N)` でコマ送り。依存ゼロ・最軽量
- 進化の瞬間だけ別シートの演出を差し込む
- 納品はコマ分割PNG or 横並びスプライトシート（どちらでも可、§ 命名参照）

---

## 9. 横断要素（系統と独立して重ねる装飾）

| 要素 | 条件（既存データ） | 表現 |
|------|--------------------|------|
| 勝ち運オーラ | `PlayRecord` 収支プラス継続 | 体に金色の薄グロウを加算（マイナスでは何も奪わない） |
| 金ピカ | 30日ストリーク達成 | 体色を特別カラーに（オーバーレイ差分で対応） |
| レア進化「神読」 | 読み師系 × 的中率80%超 | `reader_ultimate` の特別スキン |
| レア進化「化けヨミ」 | 全系統スコア拮抗（オールラウンダー） | 専用 `ultimate` 差分 |

> 横断差分は**ベース体への加算レイヤー**として作ると、15体×状態の組み合わせ爆発を避けられる。

---

## 10. 命名規則・納品物（Rails実装と整合）

配置先: `app/assets/images/companions/`

```
companions/
  common_egg.png            # 静止
  common_egg_idle.png       # idleスプライトシート（横並び、コマ数はファイル名末尾 _4f 等で明示）
  common_baby.png
  common_baby_idle.png
  common_growth.png
  reader_mature.png
  reader_perfect.png
  reader_ultimate.png
  dawn_mature.png
  ...
  overlay_gold.png          # 横断：金ピカ加算レイヤー
  overlay_win_aura.png      # 横断：勝ち運オーラ
```

- ファイル名 = `{species|common}_{stage}[_idle][_Nf].png`（`_Nf` はコマ数）
- DB側：`VoterProfile` に `species`（enum: reader/dawn/wanderer/nushi/null）・`stage`（enum: egg/baby/growth/mature/perfect/ultimate）を持たせ、ビューで `"#{species||'common'}_#{stage}"` を組み立てて出し分け
- キャラ名表示は `font-heading`（Uzura・手書き風）を当てる

### 納品チェックリスト
- [ ] 透過PNG／アンチエイリアスなし／指定解像度
- [ ] パレット8〜10色以内・共通DNA（§3）を保持
- [ ] エメラルド基調＋系統アクセント色が§6と一致
- [ ] idleスプライトのコマ間隔・サイズが揃っている（ガタつかない）
- [ ] 既存IPの意匠を含まない

---

## 11. プロンプト雛形（コピペ用 / 英語）

`{ACCENT}` `{SPECIES_TRAIT}` を系統ごとに差し替える。共通DNAを必ず添える。

**共通の前置き（毎回つける）**
```
16-bit pixel art creature sprite, single character centered, transparent background,
48x48, crisp pixels, NO anti-aliasing, retro JRPG monster style.
Recurring character "Yomi": rounded egg-shaped body, two large round eyes,
a small diamond mark on the forehead, emerald body palette
(#34d399 light / #10b981 mid / #047857 shadow) with #064e3b outline.
Dark background friendly (bright emerald, clear silhouette).
```

**段階別（前置きに続けて）**
```
[egg]      a speckled egg, no limbs, slightly wobbling, cute, calm.
[baby]     a round baby blob, oversized adorable eyes, no limbs, innocent, soft.
[growth]   small budding horns, tiny baby fangs, stubby short limbs, a bit mischievous.
[mature]   standing on two legs, longer horns, sharper narrow eyes, lean and confident.
[perfect]  fierce evolved monster, large horns, fangs, small wings, back spikes, intimidating yet cool.
[ultimate] same as perfect plus glowing golden aura (#facc15), extra ornaments, majestic and powerful.
```

**系統アクセント（mature 以降に追記）**
```
[reader]   sage-like, a monocle / third eye, flowing horns, violet accents (#a78bfa / #7c3aed), calm and intellectual.
[dawn]     swift build, cockscomb-like spikes, orange sunrise accents (#fb923c / #f97316), an aura of dawn light.
[wanderer] traveler attire (straw hat / cloak), long legs, blue accents (#60a5fa / #3b82f6), wind motion lines.
[nushi]    the largest and most imposing, heavy horns, moss / shimenawa-rope ornaments, deep green + gold trim (#059669 / #facc15), the air of a guardian "lord".
```

> 例（reader_perfect）：共通前置き ＋ `[perfect]` ＋ `[reader]` を連結して投げる。

---

## 12. ライセンス・商用利用チェック（発注前に必須）

- [ ] 使用する画像生成AIの **商用利用が規約上OK**か（例：PixelLab.ai / Retro Diffusion は商用プランあり。要確認）
- [ ] 生成物の**著作権・帰属**が自社運用に問題ないか
- [ ] 「デジモン等の既存IP意匠を含まない」ことを成果物レビューで確認
- [ ] 人に発注する場合は**二次利用・改変・独占**の範囲を契約で明記

### ツール候補
| 用途 | ツール | メモ |
|------|--------|------|
| ドット絵特化（第一候補） | PixelLab.ai / Retro Diffusion | スプライト・アニメ出力に強い。キャラ固定が課題 |
| 汎用画像AI | Midjourney / DALL·E 等 | `16-bit pixel art sprite` 指定。ばらつき注意 |
| アニメ手付け・最終調整 | Aseprite / Pixel Studio | idleコマの調整は人の手が確実 |

---

## 13. 要決定リスト（発注前に埋める）

- [ ] `要決定` 原画解像度：48×48 で確定か（32 / 64 も検討）
- [ ] `要決定` 究極体のレア条件の最終定義（神読・化けヨミ以外の隠しを足すか）
- [ ] `要決定` idleのコマ数（2 / 4）と1コマあたりの表示時間
- [ ] `要決定` 進化演出をどこまでリッチにするか（白フラッシュのみ / 専用カットイン）
- [ ] `要決定` キャラの公式名称（「ヨミ」で確定か、系統別の固有名を付けるか）
- [ ] `要決定` 発注先（AI / 職人）と予算

---

*v0.1 叩き台 / ヨミスロ companion 構想*
