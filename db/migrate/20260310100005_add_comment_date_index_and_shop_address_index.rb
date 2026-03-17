class AddCommentDateIndexAndShopAddressIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # comments: polymorphic + target_date for shops#show comment loading
    # Covers: @shop.comments.for_date(@date) which queries
    # (commentable_type, commentable_id, target_date)
    add_index :comments, [ :commentable_type, :commentable_id, :target_date ],
              algorithm: :concurrently,
              name: "index_comments_on_commentable_and_target_date",
              if_not_exists: true

    # shops: address for GROUP BY city in prefectures#show
    # Also supports search by address substring
    add_index :shops, :address, algorithm: :concurrently,
              name: "index_shops_on_address",
              if_not_exists: true

    # shop_reviews: shop_id + rating for average_rating_for(shop_id) queries
    # (already has shop_id index, but compound helps AVG(rating) queries)
    add_index :shop_reviews, [ :shop_id, :rating ], algorithm: :concurrently,
              name: "index_shop_reviews_on_shop_id_and_rating",
              if_not_exists: true
  end
end
