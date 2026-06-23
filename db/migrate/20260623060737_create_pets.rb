class CreatePets < ActiveRecord::Migration[8.1]
  def change
    create_table :pets do |t|
      # 匿名ユーザー識別子。Voter モデルは存在しないため voter_token(cookie) で 1人1体に紐づける
      t.string :voter_token, null: false
      # 進化段階 (enum: 0=egg/1=baby/2=child/3=adult)
      t.integer :stage, null: false, default: 0
      # 経験値 = 累計記録件数 (Vote + PlayRecord)。単調増加
      t.integer :exp, null: false, default: 0
      # 連続記録日数
      t.integer :streak_days, null: false, default: 0
      # mood / 連続日数算出用の最終記録日
      t.date :last_recorded_on
      # 将来のレトロ系分岐用。今回は値を使わない (0=未確定)
      t.integer :branch_axis, null: false, default: 0

      t.timestamps
    end

    add_index :pets, :voter_token, unique: true
  end
end
