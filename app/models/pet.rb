class Pet < ApplicationRecord
  # 進化段階 (一本道)。値は migration / DB と一致させること
  #   egg(0)=卵 → baby(1)=幼年期 → child(2)=成長期 → adult(3)=成熟期
  STAGES = { egg: 0, baby: 1, child: 2, adult: 3 }.freeze
  enum :stage, STAGES

  # 段階の昇順 (進化の一本道)
  STAGE_ORDER = %i[egg baby child adult].freeze

  # 進化閾値。各段階に上がる条件は「累計 exp(=記録件数)」または「連続記録日数」の
  # どちらか達成でOK。後から調整しやすいよう、ここ一箇所にまとめる。
  #   baby  : 初記録で孵化 (exp 1)
  #   child : 累計 7 件 または 連続 3 日
  #   adult : 累計 30 件 または 連続 14 日
  EVOLUTION_THRESHOLDS = {
    baby:  { exp: 1,  streak_days: nil },
    child: { exp: 7,  streak_days: 3 },
    adult: { exp: 30, streak_days: 14 }
  }.freeze

  # register! の戻り値。進化演出の出し分けに使う
  RegistrationResult = Struct.new(:pet, :evolved, :from_stage, :to_stage, keyword_init: true) do
    def evolved?
      evolved
    end
  end

  # --- 表示用ラベル / 文言 ---
  STAGE_LABELS = { "egg" => "卵", "baby" => "幼年期", "child" => "成長期", "adult" => "成熟期" }.freeze
  MOOD_LABELS = { genki: "ごきげん", normal: "ふつう", lonely: "しょんぼり" }.freeze
  MOOD_MESSAGES = {
    genki:  "よく記録してるね！",
    normal: "ぼちぼち記録してる感じ",
    lonely: "さいきん会えてないな…また記録してね"
  }.freeze

  # mood: 直近の記録からの経過日数で算出 (保存しない)。
  #   0〜3日: genki / 4〜7日: normal / 8日以上 or 未記録: lonely
  def mood(today = Date.current)
    return :lonely if last_recorded_on.nil?

    days = (today - last_recorded_on).to_i
    if days <= 3
      :genki
    elsif days <= 7
      :normal
    else
      :lonely
    end
  end

  def stage_label
    STAGE_LABELS.fetch(stage, stage)
  end

  def mood_label(today = Date.current)
    MOOD_LABELS.fetch(mood(today))
  end

  def mood_message(today = Date.current)
    MOOD_MESSAGES.fetch(mood(today))
  end

  # 進化段階に対応する画像 (app/assets/images/companions/{stage}.png)
  def image_name
    "companions/#{stage}.png"
  end

  def alt_text(today = Date.current)
    "あなたのペット（#{stage_label}・#{mood_label(today)}）"
  end

  # 次の進化までの残り。最終段階(adult)なら nil。
  # exp_remaining / days_remaining はどちらか達成で進化 (片方が nil の段階あり)。
  def next_evolution
    next_key = STAGE_ORDER[STAGES.fetch(stage.to_sym) + 1]
    return nil if next_key.nil?

    th = EVOLUTION_THRESHOLDS.fetch(next_key)
    {
      stage: next_key,
      stage_label: STAGE_LABELS.fetch(next_key.to_s),
      exp_remaining:  th[:exp] ? [ th[:exp] - exp, 0 ].max : nil,
      days_remaining: th[:streak_days] ? [ th[:streak_days] - streak_days, 0 ].max : nil
    }
  end

  # Voter モデルは存在せず、匿名識別子 voter_token(cookie) で 1人1体に紐づく。
  # 関連の代わりにこのトークンで find する (VoterProfile と同じ方式)。
  validates :voter_token, presence: true, uniqueness: true
  validates :exp, :streak_days, :branch_axis,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # 記録 1回 (または count 件) を反映してペットを更新する唯一の入口。
  # 記録作成の成功後にコントローラ/サービスから明示的に呼ぶ。
  #   voter_token : 記録者
  #   recorded_on : 記録の対象日 (Vote#voted_on / PlayRecord#played_on)
  #   count       : 同日同時に作られた記録件数 (バッチ作成用。exp の加算幅)
  # 戻り値: RegistrationResult (進化したか / 進化元・先の段階)
  def self.register!(voter_token:, recorded_on:, count: 1)
    pet = find_or_create_by!(voter_token: voter_token)
    from_stage = nil
    # 同一トークンへの同時記録でも更新が消えないよう行ロック内で増減する
    pet.with_lock do
      from_stage = pet.apply_record(recorded_on: recorded_on, count: count)
      pet.save!
    end
    RegistrationResult.new(
      pet: pet,
      evolved: !from_stage.nil?,
      from_stage: from_stage,
      to_stage: pet.stage
    )
  rescue ActiveRecord::RecordNotUnique
    # find_or_create_by! の競合 (初回作成の競争)。すでに行があるので作り直し
    retry
  end

  # exp / streak / stage を in-memory で更新する (保存は呼び出し側)。
  # 進化した場合は進化前の段階キー(文字列)、しなければ nil を返す。
  def apply_record(recorded_on:, count: 1)
    count = count.to_i
    return nil if count < 1

    from_stage = stage
    self.exp += count
    update_streak(normalize_date(recorded_on))
    apply_evolution
    stage == from_stage ? nil : from_stage
  end

  private

  def normalize_date(value)
    value.respond_to?(:to_date) ? value.to_date : value
  end

  # 連続記録日数の更新。
  #   - 最終記録日が前日 → +1
  #   - 同日 → 据え置き (同日複数記録で伸ばさない)
  #   - 2日以上空いた → 1 にリセット
  #   - 過去日の後追い記録 (recorded_on < last_recorded_on) → 最新日基準を保つため触らない
  def update_streak(recorded_on)
    return if recorded_on.blank?

    if last_recorded_on.nil?
      self.streak_days = 1
      self.last_recorded_on = recorded_on
    elsif recorded_on == last_recorded_on
      # 据え置き
    elsif recorded_on == last_recorded_on + 1
      self.streak_days += 1
      self.last_recorded_on = recorded_on
    elsif recorded_on > last_recorded_on
      self.streak_days = 1
      self.last_recorded_on = recorded_on
    end
  end

  # 条件を満たす最大段階まで一気に上げる (飛び級許容)。降格はしない。
  def apply_evolution
    target = qualified_stage
    self.stage = target if STAGES[target] > STAGES[stage.to_sym]
  end

  # 現在の exp / streak_days で到達できる最大段階を返す
  def qualified_stage
    reached = :egg
    STAGE_ORDER.drop(1).each do |st|
      th = EVOLUTION_THRESHOLDS[st]
      meets = (th[:exp] && exp >= th[:exp]) ||
              (th[:streak_days] && streak_days >= th[:streak_days])
      break unless meets
      reached = st
    end
    reached
  end
end
