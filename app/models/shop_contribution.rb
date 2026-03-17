class ShopContribution < ApplicationRecord
  belongs_to :shop

  enum :contribution_type, { exchange_rate: 0 }

  validates :voter_token, presence: true
  validates :value, presence: true
  validates :contribution_type, presence: true
  validates :voter_token, uniqueness: { scope: [ :shop_id, :contribution_type ], message: "この情報は報告済みです" }
end
