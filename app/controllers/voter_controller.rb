class VoterController < ApplicationController
  def status
    set_meta_tags title: "マイステータス", noindex: true

    token = cookies[:voter_token]

    if token.blank?
      @has_votes = false
      return
    end

    @has_votes = true
    votes = Vote.where(voter_token: token)

    @total_votes_count = votes.count
    @shops_count = votes.distinct.count(:shop_id)
    @machines_count = votes.distinct.count(:machine_model_id)
    @prefectures_count = votes.joins(:shop).distinct.count("shops.prefecture_id")

    @recent_votes = votes.includes(:shop, :machine_model)
                         .order(voted_on: :desc, updated_at: :desc)
                         .limit(10)

    @badges = compute_badges(
      total_votes: @total_votes_count,
      prefectures_count: @prefectures_count,
      machines_count: @machines_count
    )

    @voter_label = "投票者##{token.last(4)}"
  end

  private

  BADGE_DEFINITIONS = [
    { key: :first_vote,    icon: "\u{1F3B0}", name: "初投票",       description: "1票以上投票",         check: ->(s) { s[:total_votes] >= 1 } },
    { key: :contributor,   icon: "\u{1F4CA}", name: "データ提供者",  description: "10票以上投票",        check: ->(s) { s[:total_votes] >= 10 } },
    { key: :regular,       icon: "\u{1F3C6}", name: "常連投票者",    description: "50票以上投票",        check: ->(s) { s[:total_votes] >= 50 } },
    { key: :expert,        icon: "\u2B50",    name: "エキスパート",  description: "100票以上投票",       check: ->(s) { s[:total_votes] >= 100 } },
    { key: :master,        icon: "\u{1F451}", name: "マスター",      description: "500票以上投票",       check: ->(s) { s[:total_votes] >= 500 } },
    { key: :traveler,      icon: "\u{1F5FA}", name: "旅打ち",       description: "3県以上で投票",       check: ->(s) { s[:prefectures_count] >= 3 } },
    { key: :machine_mania, icon: "\u{1F3AF}", name: "機種マニア",    description: "10機種以上で投票",    check: ->(s) { s[:machines_count] >= 10 } }
  ].freeze

  def compute_badges(stats)
    BADGE_DEFINITIONS.map do |badge|
      badge.merge(earned: badge[:check].call(stats))
    end
  end
end
