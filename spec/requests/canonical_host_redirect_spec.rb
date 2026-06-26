require "rails_helper"

RSpec.describe "Canonical host redirect", type: :request do
  describe "GET / with CANONICAL_HOST" do
    context "ENV CANONICAL_HOST が未設定のとき" do
      before { ENV["CANONICAL_HOST"] = nil }

      it "リダイレクトせず 200 を返す" do
        get "/", headers: { "HOST" => "yomislo.onrender.com" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "ENV CANONICAL_HOST=yomislo.com 設定時" do
      before { ENV["CANONICAL_HOST"] = "yomislo.com" }
      after  { ENV["CANONICAL_HOST"] = nil }

      it "別ホスト(yomislo.onrender.com)から来たら 301 で新ホストにリダイレクト" do
        get "/?q=test", headers: { "HOST" => "yomislo.onrender.com" }
        expect(response).to have_http_status(:moved_permanently)
        expect(response.location).to eq("https://yomislo.com/?q=test")
      end

      it "正しいホスト(yomislo.com)で来たらリダイレクトせず 200" do
        get "/", headers: { "HOST" => "yomislo.com" }
        expect(response).to have_http_status(:ok)
      end

      it "/up はヘルスチェックなのでリダイレクトしない" do
        get "/up", headers: { "HOST" => "yomislo.onrender.com" }
        expect(response).not_to have_http_status(:moved_permanently)
      end

      it "クエリ文字列を保ったままリダイレクト" do
        get "/shops/foo?page=2", headers: { "HOST" => "yomislo.onrender.com" }
        expect(response.location).to eq("https://yomislo.com/shops/foo?page=2")
      end
    end
  end
end
