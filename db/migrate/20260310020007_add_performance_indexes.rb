class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # vote_summaries: target_date is used in almost every controller query
    add_index :vote_summaries, :target_date, algorithm: :concurrently,
              if_not_exists: true

    # vote_summaries: target_date + shop_id for "hot shops" GROUP BY ranking
    add_index :vote_summaries, [ :target_date, :shop_id ], algorithm: :concurrently,
              name: "index_vote_summaries_on_target_date_and_shop",
              if_not_exists: true

    # vote_summaries: machine_model_id + target_date for machine page queries
    add_index :vote_summaries, [ :machine_model_id, :target_date ], algorithm: :concurrently,
              name: "index_vote_summaries_on_machine_model_target_date",
              if_not_exists: true

    # shops: exchange_rate for search filter
    add_index :shops, :exchange_rate, algorithm: :concurrently,
              if_not_exists: true

    # shops: prefecture_id + name for ordered listing in prefecture page
    add_index :shops, [ :prefecture_id, :name ], algorithm: :concurrently,
              name: "index_shops_on_prefecture_id_and_name",
              if_not_exists: true

    # votes: voted_on for daily count queries (home page)
    add_index :votes, :voted_on, algorithm: :concurrently,
              if_not_exists: true

    # machine_models: active + name for sorted active machine listings
    add_index :machine_models, [ :active, :name ], algorithm: :concurrently,
              name: "index_machine_models_on_active_and_name",
              if_not_exists: true
  end
end
