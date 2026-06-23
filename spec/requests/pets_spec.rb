require "rails_helper"

# 記録フロー (Vote / PlayRecord) からペットが成長するかの統合テスト
RSpec.describe "Pet growth via record flows", type: :request do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }
  let(:machine2) { create(:machine_model) }
  let(:token) { "pet_flow_token" }

  def pet
    Pet.find_by(voter_token: token)
  end

  describe "POST /votes" do
    it "hatches the pet on the first vote (egg→baby, exp 1)" do
      cookies[:voter_token] = token
      post votes_path, params: {
        vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, reset_vote: 1 }
      }
      expect(pet).to be_present
      expect(pet.stage).to eq("baby")
      expect(pet.exp).to eq(1)
    end

    it "does not double-count when toggling another field on the same vote row" do
      cookies[:voter_token] = token
      post votes_path, params: {
        vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, reset_vote: 1 }
      }
      # 同じ店舗/機種/日へ setting を追記 → 既存行の更新なので exp は増えない
      post votes_path, params: {
        vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, setting_vote: 4 }
      }
      expect(pet.exp).to eq(1)
    end

    it "counts a separate machine on the same day as another record" do
      cookies[:voter_token] = token
      post votes_path, params: {
        vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, reset_vote: 1 }
      }
      post votes_path, params: {
        vote: { shop_id: shop.id, machine_model_id: machine2.id, voted_on: Date.current, reset_vote: 1 }
      }
      expect(pet.exp).to eq(2)
    end
  end

  describe "POST /play_records (single)" do
    it "grows the pet by one record" do
      cookies[:voter_token] = token
      post play_records_path, params: {
        play_record: {
          shop_id: shop.id, machine_model_id: machine.id,
          played_on: Date.current.to_s, result_amount: 3000
        }
      }
      expect(pet).to be_present
      expect(pet.exp).to eq(1)
      expect(pet.stage).to eq("baby")
    end
  end

  describe "POST /play_records (multiple)" do
    it "grows the pet by play records + newly created votes" do
      cookies[:voter_token] = token
      post play_records_path, params: {
        shop_id: shop.id,
        played_on: Date.current.to_s,
        entries: {
          "0" => { machine_model_id: machine.id, result_amount: "1000", setting_vote: "4" },
          "1" => { machine_model_id: machine2.id, result_amount: "-2000" }
        }
      }
      # 収支2件 + 新規Vote1件 = exp 3
      expect(pet).to be_present
      expect(pet.exp).to eq(3)
    end
  end

  describe "GET /voter/status (display)" do
    it "renders the pet card with stage image / mood / evolution progress" do
      cookies[:voter_token] = token
      create(:voter_profile, voter_token: token, total_votes: 5)
      create(:pet, voter_token: token, stage: :child, exp: 10, streak_days: 2, last_recorded_on: Date.current)

      get voter_status_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("companions/child")          # 段階画像
      expect(response.body).to include("成長期・ごきげん")            # alt (段階+mood)
      expect(response.body).to include("よく記録してるね！")          # mood メッセージ (genki)
      expect(response.body).to include("次の姿まで")                 # 進化進捗ラベル
    end

    it "auto-creates an egg for a user with no records" do
      cookies[:voter_token] = token

      expect { get voter_status_path }.to change { Pet.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("companions/egg")
      expect(response.body).to include("卵・しょんぼり")              # alt (egg は未記録 = lonely)
    end
  end

  describe "GET / (home user card pet)" do
    it "renders the pet in the user card when the visitor has one" do
      cookies[:voter_token] = token
      create(:pet, voter_token: token, stage: :baby, last_recorded_on: Date.current)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("companions/baby")
    end

    it "auto-creates an egg on home when cookie exists" do
      cookies[:voter_token] = token

      expect { get root_path }.to change { Pet.count }.by(1)

      expect(response.body).to include("companions/egg")
    end

    it "does not create a pet for visitors without a cookie" do
      expect { get root_path }.not_to change { Pet.count }
    end
  end
end
