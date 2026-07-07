require "rails_helper"

RSpec.describe "PlayRecords", type: :request do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }
  let(:voter_token) { "test_token_123" }

  describe "GET /play_records" do
    it "returns 200 even without pre-existing voter_token (auto-created)" do
      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with voter_token cookie" do
      cookies[:voter_token] = voter_token
      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "displays records for the current month" do
      cookies[:voter_token] = voter_token
      PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 5000
      )

      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "accepts month param" do
      cookies[:voter_token] = voter_token
      get play_records_path, params: { month: Date.current.strftime("%Y-%m") }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /play_records" do
    it "creates a record even without pre-existing voter_token (auto-created)" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            played_on: Date.current.to_s,
            result_amount: 3000
          }
        }
      }.to change(PlayRecord, :count).by(1)
    end

    it "creates a record with valid data" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            played_on: Date.current.to_s,
            result_amount: 3000
          }
        }
      }.to change(PlayRecord, :count).by(1)

      expect(response).to redirect_to(play_records_path(month: Date.current.strftime("%Y-%m")))
    end

    it "redirects to return_to when provided" do
      cookies[:voter_token] = voter_token

      post play_records_path, params: {
        play_record: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          played_on: Date.current.to_s,
          result_amount: 5000
        },
        return_to: "/shops/test-shop"
      }

      expect(response).to redirect_to("/shops/test-shop")
    end

    it "redirects with alert for invalid data" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: "",
            result_amount: ""
          }
        }
      }.not_to change(PlayRecord, :count)

      expect(response).to redirect_to(play_records_path)
      expect(flash[:alert]).to be_present
    end

    it "rejects result_amount out of range" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: 9_999_999
          }
        }
      }.not_to change(PlayRecord, :count)
    end

    it "機種なしの単一収支を turbo_stream で作成しても 500 にならない" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path,
             params: { play_record: { shop_id: shop.id, played_on: Date.current.to_s, result_amount: 1000 } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(PlayRecord, :count).by(1)

      # 機種に紐づかない記録は Turbo Frame 行が無いため 204 を返す(500にならない)
      expect(response).to have_http_status(:no_content)
      expect(PlayRecord.last.machine_model_id).to be_nil
    end
  end

  describe "POST /play_records (一括 entries)" do
    it "creates records and votes for multiple entries" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          shop_id: shop.id,
          played_on: Date.current.to_s,
          entries: {
            "0" => {
              machine_model_id: machine.id,
              result_amount: 3000,
              setting_vote: "6",
              confirmed_setting: [ "6確" ]
            }
          }
        }
      }.to change(PlayRecord, :count).by(1).and change(Vote, :count).by(1)
    end

    it "同一バッチ内で同じ機種が重複しても 500 にならず 有効な記録も消えない" do
      cookies[:voter_token] = voter_token

      # 同じ機種を2行に入れる → 一意制約違反で全ROLLBACKされていたバグの回帰テスト
      expect {
        post play_records_path, params: {
          shop_id: shop.id,
          played_on: Date.current.to_s,
          entries: {
            "0" => { machine_model_id: machine.id, result_amount: 3000 },
            "1" => { machine_model_id: machine.id, result_amount: -1000 }
          }
        }
      }.not_to change(PlayRecord, :count)

      expect(response).to redirect_to(play_records_path)
      expect(flash[:alert]).to include("重複")
    end

    it "異なる機種2件は今まで通り両方保存できる" do
      cookies[:voter_token] = voter_token
      machine2 = create(:machine_model)

      expect {
        post play_records_path, params: {
          shop_id: shop.id,
          played_on: Date.current.to_s,
          entries: {
            "0" => { machine_model_id: machine.id, result_amount: 3000 },
            "1" => { machine_model_id: machine2.id, result_amount: -1000 }
          }
        }
      }.to change(PlayRecord, :count).by(2)

      expect(response).to have_http_status(:redirect)
    end

    it "handles confirmed_setting arriving as a String (name振り直しで[]欠落しても落ちない)" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          shop_id: shop.id,
          played_on: Date.current.to_s,
          entries: {
            "0" => {
              machine_model_id: machine.id,
              result_amount: 1500,
              confirmed_setting: "6確" # 配列ではなく文字列
            }
          }
        }
      }.to change(PlayRecord, :count).by(1).and change(Vote, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(Vote.last.confirmed_setting).to eq([ "6確" ])
    end
  end

  describe "DELETE /play_records/:id" do
    it "deletes own record" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: -2000
      )

      expect {
        delete play_record_path(record)
      }.to change(PlayRecord, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end

    it "収支indexからの削除(context=index)は play_records_body フレームを再描画する" do
      cookies[:voter_token] = voter_token
      machine2 = create(:machine_model, name: "残す機種")
      deleted = PlayRecord.create!(
        voter_token: voter_token, shop: shop, machine_model: machine,
        played_on: Date.current, result_amount: 2000
      )
      PlayRecord.create!(
        voter_token: voter_token, shop: shop, machine_model: machine2,
        played_on: Date.current, result_amount: -1000
      )

      delete play_record_path(deleted), params: { context: "index" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      # machine_vote_ ではなく play_records_body フレームの置換ストリームを返す
      expect(response.body).to include('target="play_records_body"')
      # 削除した機種は消え、残した機種は表示される (再描画でリストが最新化)
      expect(response.body).to include("残す機種")
      expect(response.body).not_to include(machine.name)
    end

    it "店舗詳細ページからの削除(contextなし)は machine_vote_ 行を置換する" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 2000
      )

      delete play_record_path(record),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("machine_vote_#{machine.id}")
    end

    it "公開記録を削除すると集計キャッシュからも除外される" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 5000,
        is_public: true
      )
      # 作成時の after_commit (test は inline) で集計され total_records=1
      summary = PlayRecordSummary.find_by(scope_type: "shop", scope_id: shop.id, period_type: :all_time)
      expect(summary.total_records).to eq(1)

      delete play_record_path(record)

      # 削除後も集計が更新され、消えたレコードが残らない
      expect(summary.reload.total_records).to eq(0)
    end

    it "cannot delete another user's record" do
      cookies[:voter_token] = voter_token
      other_record = PlayRecord.create!(
        voter_token: "other_user_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      expect {
        delete play_record_path(other_record)
      }.not_to change(PlayRecord, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /play_records/:id" do
    it "updates own record" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      patch play_record_path(record), params: {
        play_record: { result_amount: 5000 }
      }

      expect(response).to redirect_to(play_records_path(month: Date.current.strftime("%Y-%m")))
      expect(record.reload.result_amount).to eq(5000)
    end

    it "cannot update another user's record" do
      cookies[:voter_token] = voter_token
      other_record = PlayRecord.create!(
        voter_token: "other_user_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      expect {
        patch play_record_path(other_record), params: {
          play_record: { result_amount: 9999 }
        }
      }.not_to change { other_record.reload.result_amount }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /play_records with invalid parameters" do
    before { cookies[:voter_token] = voter_token }

    it "rejects future dates" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: (Date.current + 1.day).to_s,
            result_amount: 1000
          }
        }
      }.not_to change(PlayRecord, :count)

      expect(response).to redirect_to(play_records_path)
      expect(flash[:alert]).to include("未来")
    end

    it "rejects result_amount below -999,999" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: -1_000_000
          }
        }
      }.not_to change(PlayRecord, :count)
    end

    it "rejects result_amount above 999,999" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: 1_000_000
          }
        }
      }.not_to change(PlayRecord, :count)
    end
  end

  describe "access without voter_token" do
    it "auto-creates voter_token and creates record for POST /play_records" do
      expect {
        post play_records_path, params: {
          play_record: { shop_id: shop.id, played_on: Date.current.to_s, result_amount: 1000 }
        }
      }.to change(PlayRecord, :count).by(1)
    end

    it "returns 404 for PATCH /play_records/:id with another user's record" do
      record = PlayRecord.create!(
        voter_token: "some_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )
      patch play_record_path(record), params: { play_record: { result_amount: 2000 } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for DELETE /play_records/:id with another user's record" do
      record = PlayRecord.create!(
        voter_token: "some_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )
      delete play_record_path(record)
      expect(response).to have_http_status(:not_found)
    end
  end
end
