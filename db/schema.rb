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

ActiveRecord::Schema[8.0].define(version: 2026_03_09_002852) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id"
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.text "body", null: false
    t.date "target_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "commenter_name", default: "名無し"
    t.string "voter_token"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "machine_models", force: :cascade do |t|
    t.string "name", null: false
    t.string "maker"
    t.integer "machine_type", default: 0
    t.integer "spec_type", default: 0
    t.string "slug", null: false
    t.date "released_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_machine_models_on_slug", unique: true
  end

  create_table "prefectures", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_prefectures_on_name", unique: true
    t.index ["slug"], name: "index_prefectures_on_slug", unique: true
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "reporter_id"
    t.string "reportable_type", null: false
    t.bigint "reportable_id", null: false
    t.integer "reason", default: 0, null: false
    t.boolean "resolved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "voter_token"
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
    t.index ["reporter_id"], name: "index_reports_on_reporter_id"
  end

  create_table "shops", force: :cascade do |t|
    t.bigint "prefecture_id", null: false
    t.string "name", null: false
    t.string "address"
    t.decimal "lat", precision: 10, scale: 7
    t.decimal "lng", precision: 10, scale: 7
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prefecture_id"], name: "index_shops_on_prefecture_id"
    t.index ["slug"], name: "index_shops_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "nickname", null: false
    t.integer "role", default: 0
    t.decimal "trust_score", precision: 3, scale: 2, default: "0.5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vote_summaries", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "machine_model_id", null: false
    t.date "target_date", null: false
    t.integer "total_votes", default: 0
    t.integer "reset_yes_count", default: 0
    t.integer "reset_no_count", default: 0
    t.decimal "setting_avg", precision: 3, scale: 1
    t.jsonb "setting_distribution", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["machine_model_id"], name: "index_vote_summaries_on_machine_model_id"
    t.index ["shop_id", "machine_model_id", "target_date"], name: "index_vote_summaries_unique_shop_machine_date", unique: true
    t.index ["shop_id"], name: "index_vote_summaries_on_shop_id"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "shop_id", null: false
    t.bigint "machine_model_id", null: false
    t.date "voted_on", null: false
    t.integer "reset_vote"
    t.integer "setting_vote"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "voter_token"
    t.index ["machine_model_id"], name: "index_votes_on_machine_model_id"
    t.index ["shop_id", "machine_model_id", "voted_on"], name: "index_votes_for_aggregation"
    t.index ["shop_id"], name: "index_votes_on_shop_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["voter_token", "shop_id", "machine_model_id", "voted_on"], name: "idx_votes_unique_per_voter", unique: true
    t.index ["voter_token"], name: "index_votes_on_voter_token"
  end

  add_foreign_key "shops", "prefectures"
  add_foreign_key "vote_summaries", "machine_models"
  add_foreign_key "vote_summaries", "shops"
  add_foreign_key "votes", "machine_models"
  add_foreign_key "votes", "shops"
end
