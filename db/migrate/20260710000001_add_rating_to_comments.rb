class AddRatingToComments < ActiveRecord::Migration[8.1]
  # クチコミをコメントに一本化する。星評価は任意項目として comments.rating に持たせ、
  # 既存の shop_reviews を comments へ移送する（データ消失を避けるため）。
  def up
    add_column :comments, :rating, :integer

    # 既存レビューをコメントへ移送。reviewer_name は commenter_name の DB デフォルト
    # (名無し) に合わせて COALESCE する。
    execute(<<~SQL.squish)
      INSERT INTO comments
        (commentable_type, commentable_id, body, commenter_name, voter_token, rating, created_at, updated_at)
      SELECT 'Shop', shop_id, body, COALESCE(reviewer_name, '名無し'), voter_token, rating, created_at, updated_at
      FROM shop_reviews
    SQL
  end

  def down
    remove_column :comments, :rating
  end
end
