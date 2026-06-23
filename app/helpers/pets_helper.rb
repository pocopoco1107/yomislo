module PetsHelper
  # mood ごとの文言テキスト色
  MOOD_TEXT = {
    genki:  "text-primary",
    normal: "text-muted-foreground",
    lonely: "text-slot-blue"
  }.freeze

  def pet_mood_text(mood)
    MOOD_TEXT.fetch(mood, MOOD_TEXT[:normal])
  end

  # 「次の進化まで あと◯件 ／ あと◯日」の文言を組み立てる
  def pet_next_evolution_text(next_evo)
    parts = []
    parts << "あと#{next_evo[:exp_remaining]}件" if next_evo[:exp_remaining]
    parts << "あと#{next_evo[:days_remaining]}日" if next_evo[:days_remaining]
    parts.join(" ／ ")
  end
end
