module MachinesHelper
  # 機種詳細ページの天井・期待値 / リセット恩恵テーブルのラベル。
  # スクレイピングした英語キーを打ち手に馴染む日本語に置き換える。
  # 未知キーはそのまま出す (英語のままよりは崩れにくいフォールバック)。
  CEILING_INFO_LABELS = {
    "condition" => "条件",
    "benefit"   => "恩恵"
  }.freeze

  RESET_INFO_LABELS = {
    "description" => "詳細"
  }.freeze

  def ceiling_info_label(key)
    CEILING_INFO_LABELS[key.to_s] || key.to_s
  end

  def reset_info_label(key)
    RESET_INFO_LABELS[key.to_s] || key.to_s
  end
end
