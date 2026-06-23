class Pet < ApplicationRecord
  # 進化段階 (一本道)。値は migration / DB と一致させること
  #   egg(0)=卵 → baby(1)=幼年期 → child(2)=成長期 → adult(3)=成熟期
  STAGES = { egg: 0, baby: 1, child: 2, adult: 3 }.freeze
  enum :stage, STAGES

  # Voter モデルは存在せず、匿名識別子 voter_token(cookie) で 1人1体に紐づく。
  # 関連の代わりにこのトークンで find する (VoterProfile と同じ方式)。
  validates :voter_token, presence: true, uniqueness: true
  validates :exp, :streak_days, :branch_axis,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
