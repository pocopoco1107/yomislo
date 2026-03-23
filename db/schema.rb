# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_23_093326) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.string "commenter_name", default: "名無し"
    t.datetime "created_at", null: false
    t.date "target_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "voter_token"
    t.index ["commentable_type", "commentable_id", "target_date"], name: "index_comments_on_commentable_and_target_date"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "exchange_rate_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "denomination", null: false
    t.string "rate_key", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.string "voter_token", null: false
    t.index ["shop_id", "denomination"], name: "idx_exchange_rate_reports_aggregation"
    t.index ["shop_id"], name: "index_exchange_rate_reports_on_shop_id"
    t.index ["voter_token", "shop_id", "denomination"], name: "idx_exchange_rate_reports_unique", unique: true
  end

  create_table "exchange_rate_summaries", force: :cascade do |t|
    t.string "consensus_rate"
    t.datetime "created_at", null: false
    t.integer "denomination", null: false
    t.jsonb "rate_distribution", default: {}
    t.bigint "shop_id", null: false
    t.integer "total_reports", default: 0
    t.datetime "updated_at", null: false
    t.index ["shop_id", "denomination"], name: "idx_exchange_rate_summaries_unique", unique: true
    t.index ["shop_id"], name: "index_exchange_rate_summaries_on_shop_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.text "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "voter_token"
    t.index ["status"], name: "index_feedbacks_on_status"
  end

  create_table "machine_guide_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "link_type", default: 0, null: false
    t.bigint "machine_model_id", null: false
    t.string "source"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["link_type"], name: "index_machine_guide_links_on_link_type"
    t.index ["machine_model_id", "url"], name: "index_machine_guide_links_on_machine_model_id_and_url", unique: true
    t.index ["machine_model_id"], name: "index_machine_guide_links_on_machine_model_id"
    t.index ["status"], name: "index_machine_guide_links_on_status"
  end

  create_table "machine_models", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "ceiling_info", default: {}
    t.datetime "created_at", null: false
    t.string "generation"
    t.string "image_url"
    t.date "introduced_on"
    t.boolean "is_smart_slot", default: false, null: false
    t.string "maker"
    t.string "name", null: false
    t.decimal "payout_rate_max", precision: 4, scale: 1
    t.decimal "payout_rate_min", precision: 4, scale: 1
    t.integer "ptown_id"
    t.jsonb "reset_info", default: {}
    t.string "slug", null: false
    t.string "type_detail"
    t.datetime "updated_at", null: false
    t.index ["active", "name"], name: "index_machine_models_on_active_and_name"
    t.index ["active"], name: "index_machine_models_on_active"
    t.index ["ptown_id"], name: "index_machine_models_on_ptown_id", unique: true, where: "(ptown_id IS NOT NULL)"
    t.index ["slug"], name: "index_machine_models_on_slug", unique: true
  end

  create_table "play_record_summaries", force: :cascade do |t|
    t.integer "avg_result", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "lose_count", default: 0, null: false
    t.string "period_key", null: false
    t.integer "period_type", default: 0, null: false
    t.bigint "scope_id", null: false
    t.string "scope_type", null: false
    t.integer "total_records", default: 0, null: false
    t.integer "total_result", default: 0, null: false
    t.datetime "updated_at", null: false
    t.jsonb "weekday_stats", default: {}
    t.integer "win_count", default: 0, null: false
    t.decimal "win_rate", precision: 5, scale: 1, default: "0.0"
    t.index ["scope_type", "period_type", "period_key"], name: "idx_play_record_summaries_lookup"
    t.index ["scope_type", "scope_id", "period_type", "period_key"], name: "idx_play_record_summaries_unique", unique: true
  end

  create_table "play_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "investment"
    t.boolean "is_public", default: true, null: false
    t.bigint "machine_model_id"
    t.text "memo"
    t.integer "payout"
    t.date "played_on", null: false
    t.integer "result_amount", null: false
    t.bigint "shop_id", null: false
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "voter_token", null: false
    t.index ["machine_model_id"], name: "index_play_records_on_machine_model_id"
    t.index ["played_on", "is_public"], name: "idx_play_records_public_date"
    t.index ["shop_id"], name: "index_play_records_on_shop_id"
    t.index ["tags"], name: "index_play_records_on_tags", using: :gin
    t.index ["voter_token", "shop_id", "machine_model_id", "played_on"], name: "idx_play_records_unique", unique: true
    t.index ["voter_token"], name: "index_play_records_on_voter_token"
  end

  create_table "prefectures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_prefectures_on_name", unique: true
    t.index ["slug"], name: "index_prefectures_on_slug", unique: true
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "reason", default: 0, null: false
    t.bigint "reportable_id", null: false
    t.string "reportable_type", null: false
    t.bigint "reporter_id"
    t.boolean "resolved", default: false
    t.datetime "updated_at", null: false
    t.string "voter_token"
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
    t.index ["reporter_id"], name: "index_reports_on_reporter_id"
  end

  create_table "shop_contributions", force: :cascade do |t|
    t.integer "contribution_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.string "voter_token", null: false
    t.index ["shop_id"], name: "index_shop_contributions_on_shop_id"
    t.index ["voter_token", "shop_id", "contribution_type"], name: "idx_shop_contributions_unique", unique: true
  end

  create_table "shop_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "event_date", null: false
    t.integer "event_type", default: 0, null: false
    t.bigint "shop_id", null: false
    t.string "source", default: "user", null: false
    t.string "source_url"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "voter_token"
    t.index ["shop_id", "event_date"], name: "index_shop_events_on_shop_id_and_event_date"
    t.index ["shop_id"], name: "index_shop_events_on_shop_id"
    t.index ["status"], name: "index_shop_events_on_status"
    t.index ["voter_token"], name: "index_shop_events_on_voter_token"
  end

  create_table "shop_machine_models", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "data_source", default: "ptown"
    t.bigint "machine_model_id", null: false
    t.bigint "shop_id", null: false
    t.integer "unit_count"
    t.datetime "updated_at", null: false
    t.index ["machine_model_id"], name: "index_shop_machine_models_on_machine_model_id"
    t.index ["shop_id", "machine_model_id"], name: "index_shop_machine_models_on_shop_id_and_machine_model_id", unique: true
    t.index ["shop_id"], name: "index_shop_machine_models_on_shop_id"
  end

  create_table "shop_requests", force: :cascade do |t|
    t.string "address"
    t.text "admin_note"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "note"
    t.bigint "prefecture_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "voter_token", null: false
    t.index ["prefecture_id", "name", "status"], name: "index_shop_requests_on_pref_name_status"
    t.index ["prefecture_id"], name: "index_shop_requests_on_prefecture_id"
    t.index ["status"], name: "index_shop_requests_on_status"
    t.index ["voter_token"], name: "index_shop_requests_on_voter_token"
  end

  create_table "shop_reviews", force: :cascade do |t|
    t.text "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.string "reviewer_name", default: "名無し"
    t.bigint "shop_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "voter_token", null: false
    t.index ["category"], name: "index_shop_reviews_on_category"
    t.index ["shop_id", "created_at"], name: "index_shop_reviews_on_shop_id_and_created_at"
    t.index ["shop_id", "rating"], name: "index_shop_reviews_on_shop_id_and_rating"
    t.index ["shop_id", "voter_token"], name: "index_shop_reviews_on_shop_id_and_voter_token", unique: true
    t.index ["shop_id"], name: "index_shop_reviews_on_shop_id"
    t.index ["voter_token"], name: "index_shop_reviews_on_voter_token"
  end

  create_table "shops", force: :cascade do |t|
    t.string "access_info"
    t.string "address"
    t.string "business_hours"
    t.datetime "created_at", null: false
    t.string "features"
    t.integer "geocode_precision", default: 0, null: false
    t.datetime "last_synced_at"
    t.decimal "lat", precision: 10, scale: 7
    t.decimal "lng", precision: 10, scale: 7
    t.string "morning_entry"
    t.string "name", null: false
    t.date "opened_on"
    t.integer "parking_spaces"
    t.string "phone_number"
    t.bigint "prefecture_id", null: false
    t.integer "ptown_shop_id"
    t.integer "slot_machines"
    t.string "slug", null: false
    t.integer "total_machines"
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_shops_on_address"
    t.index ["prefecture_id", "name"], name: "index_shops_on_prefecture_id_and_name"
    t.index ["prefecture_id"], name: "index_shops_on_prefecture_id"
    t.index ["ptown_shop_id"], name: "index_shops_on_ptown_shop_id", unique: true
    t.index ["slug"], name: "index_shops_on_slug", unique: true
  end

  create_table "sns_reports", force: :cascade do |t|
    t.integer "confidence", default: 0
    t.datetime "created_at", null: false
    t.bigint "machine_model_id"
    t.text "raw_text"
    t.date "reported_on"
    t.bigint "shop_id"
    t.string "source", null: false
    t.string "source_title"
    t.string "source_url"
    t.integer "status", default: 0
    t.jsonb "structured_data", default: {}
    t.string "suggested_setting"
    t.string "trophy_type"
    t.datetime "updated_at", null: false
    t.index ["machine_model_id", "reported_on"], name: "index_sns_reports_on_machine_model_id_and_reported_on"
    t.index ["machine_model_id"], name: "index_sns_reports_on_machine_model_id"
    t.index ["shop_id"], name: "index_sns_reports_on_shop_id"
    t.index ["source"], name: "index_sns_reports_on_source"
    t.index ["source_url"], name: "index_sns_reports_on_source_url", unique: true, where: "(source_url IS NOT NULL)"
    t.index ["status"], name: "index_sns_reports_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "nickname", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0
    t.decimal "trust_score", precision: 3, scale: 2, default: "0.5"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vote_summaries", force: :cascade do |t|
    t.jsonb "confirmed_setting_counts", default: {}
    t.datetime "created_at", null: false
    t.bigint "machine_model_id", null: false
    t.integer "reset_no_count", default: 0
    t.integer "reset_yes_count", default: 0
    t.decimal "setting_avg", precision: 3, scale: 1
    t.jsonb "setting_distribution", default: {}
    t.bigint "shop_id", null: false
    t.date "target_date", null: false
    t.integer "total_votes", default: 0
    t.datetime "updated_at", null: false
    t.index ["machine_model_id", "target_date"], name: "index_vote_summaries_on_machine_model_target_date"
    t.index ["machine_model_id"], name: "index_vote_summaries_on_machine_model_id"
    t.index ["shop_id", "machine_model_id", "target_date"], name: "index_vote_summaries_unique_shop_machine_date", unique: true
    t.index ["shop_id"], name: "index_vote_summaries_on_shop_id"
    t.index ["target_date", "shop_id"], name: "index_vote_summaries_on_target_date_and_shop"
    t.index ["target_date"], name: "index_vote_summaries_on_target_date"
  end

  create_table "voter_profiles", force: :cascade do |t|
    t.decimal "accuracy_confirmed", precision: 5, scale: 1
    t.decimal "accuracy_majority", precision: 5, scale: 1
    t.datetime "created_at", null: false
    t.integer "current_streak", default: 0, null: false
    t.string "display_name"
    t.decimal "high_setting_rate", precision: 5, scale: 1
    t.date "last_voted_on"
    t.integer "max_streak", default: 0, null: false
    t.integer "monthly_votes", default: 0, null: false
    t.integer "points", default: 0, null: false
    t.string "rank_title", default: "見習い", null: false
    t.integer "total_votes", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "voter_token", null: false
    t.integer "weekly_votes", default: 0, null: false
    t.index ["rank_title"], name: "index_voter_profiles_on_rank_title"
    t.index ["total_votes"], name: "index_voter_profiles_on_total_votes"
    t.index ["voter_token"], name: "index_voter_profiles_on_voter_token", unique: true
  end

  create_table "voter_rankings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "period_key", null: false
    t.integer "period_type", default: 0, null: false
    t.integer "rank_position", null: false
    t.bigint "scope_id"
    t.string "scope_type", default: "national", null: false
    t.datetime "updated_at", null: false
    t.integer "vote_count", default: 0, null: false
    t.string "voter_token", null: false
    t.index ["period_type", "period_key", "scope_type", "scope_id", "rank_position"], name: "idx_voter_rankings_lookup"
    t.index ["period_type", "period_key", "scope_type", "scope_id", "voter_token"], name: "idx_voter_rankings_unique", unique: true
    t.index ["voter_token"], name: "index_voter_rankings_on_voter_token"
  end

  create_table "votes", force: :cascade do |t|
    t.string "confirmed_setting", default: [], array: true
    t.datetime "created_at", null: false
    t.bigint "machine_model_id", null: false
    t.integer "reset_vote"
    t.integer "setting_vote"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.date "voted_on", null: false
    t.string "voter_token"
    t.index ["confirmed_setting"], name: "index_votes_on_confirmed_setting", using: :gin
    t.index ["machine_model_id"], name: "index_votes_on_machine_model_id"
    t.index ["shop_id", "machine_model_id", "voted_on"], name: "index_votes_for_aggregation"
    t.index ["shop_id"], name: "index_votes_on_shop_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["voted_on"], name: "index_votes_on_voted_on"
    t.index ["voter_token", "shop_id", "machine_model_id", "voted_on"], name: "idx_votes_unique_per_voter", unique: true
    t.index ["voter_token"], name: "index_votes_on_voter_token"
  end

  add_foreign_key "exchange_rate_reports", "shops"
  add_foreign_key "exchange_rate_summaries", "shops"
  add_foreign_key "machine_guide_links", "machine_models"
  add_foreign_key "play_records", "machine_models"
  add_foreign_key "play_records", "shops"
  add_foreign_key "shop_contributions", "shops"
  add_foreign_key "shop_events", "shops"
  add_foreign_key "shop_machine_models", "machine_models"
  add_foreign_key "shop_machine_models", "shops"
  add_foreign_key "shop_requests", "prefectures"
  add_foreign_key "shop_reviews", "shops"
  add_foreign_key "shops", "prefectures"
  add_foreign_key "sns_reports", "machine_models"
  add_foreign_key "sns_reports", "shops"
  add_foreign_key "vote_summaries", "machine_models"
  add_foreign_key "vote_summaries", "shops"
  add_foreign_key "votes", "machine_models"
  add_foreign_key "votes", "shops"
end
