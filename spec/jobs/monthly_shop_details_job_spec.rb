require "rails_helper"

RSpec.describe MonthlyShopDetailsJob, type: :job do
  subject(:job) { described_class.new }

  let!(:pref_a) { create(:prefecture, name: "A県", slug: "a") }
  let!(:pref_b) { create(:prefecture, name: "B県", slug: "b") }

  # rake タスクの実体は叩かず、どのタスクがどの引数で呼ばれたかだけ記録する。
  # 検証対象は時間予算とチェックポイントの制御であり、スクレイピング本体ではない。
  let(:invoked) { [] }

  before do
    allow(Rails.application).to receive(:load_tasks)
    allow(job).to receive(:invoke_task) { |name, *args| invoked << [ name, *args ] }

    MonthlySyncProgress.current_cycle.update!(shops_imported: true, machines_imported: true, details_imported: true)
  end

  def create_shops(prefecture, count)
    count.times { create(:shop, prefecture: prefecture, ptown_shop_id: rand(10_000..99_999)) }
  end

  describe "時間予算" do
    it "残り予算に収まる都道府県だけ同期し、残りは次回に回す" do
      create_shops(pref_a, 2)   # 推定14秒
      create_shops(pref_b, 10)  # 推定70秒
      stub_const("#{described_class}::JOB_TIME_BUDGET", 20.seconds)

      job.perform

      expect(invoked).to eq([ [ "ptown:sync_shop_machines", "a" ] ])
      expect(MonthlySyncProgress.current_cycle.last_synced_prefecture_id).to eq(pref_a.id)
      expect(MonthlySyncProgress.current_cycle).not_to be_completed
    end

    it "推定所要が残り予算を超える都道府県で打ち切り、後続の都道府県に飛ばさない" do
      create_shops(pref_a, 10)  # 推定70秒
      create_shops(pref_b, 1)   # 推定7秒（予算内だがA県で打ち切るため実行されない）
      stub_const("#{described_class}::JOB_TIME_BUDGET", 20.seconds)

      job.perform

      expect(invoked).to be_empty
      expect(MonthlySyncProgress.current_cycle.last_synced_prefecture_id).to be_nil
    end

    it "予算を使い切っていれば未処理フェーズを開始しない" do
      MonthlySyncProgress.current_cycle.update!(details_imported: false)
      stub_const("#{described_class}::JOB_TIME_BUDGET", 0.seconds)

      job.perform

      expect(invoked).to be_empty
      expect(MonthlySyncProgress.current_cycle).not_to be_details_imported
    end
  end

  describe "サイクル完了" do
    it "全都道府県を処理したら後続フェーズを実行して完了フラグを立てる" do
      create_shops(pref_a, 1)
      create_shops(pref_b, 1)

      job.perform

      expect(invoked).to eq([
        [ "ptown:sync_shop_machines", "a" ],
        [ "ptown:sync_shop_machines", "b" ],
        [ "geocode:shops" ],
        [ "ptown:merge_duplicates" ]
      ])
      expect(MonthlySyncProgress.current_cycle).to be_completed
    end

    it "完了済みサイクルでは何もしない" do
      MonthlySyncProgress.current_cycle.update!(completed: true)

      job.perform

      expect(invoked).to be_empty
    end
  end

  describe "未処理フェーズ" do
    it "フラグの立っていないフェーズを実行しフラグを更新する" do
      MonthlySyncProgress.current_cycle.update!(shops_imported: false, machines_imported: false, details_imported: false)

      job.perform

      expect(invoked.first(3)).to eq([
        [ "ptown:import_shops" ],
        [ "ptown:import_machines" ],
        [ "ptown:import_details" ]
      ])
      progress = MonthlySyncProgress.current_cycle
      expect(progress).to be_shops_imported
      expect(progress).to be_machines_imported
      expect(progress).to be_details_imported
    end
  end

  describe "FORCE 環境変数" do
    it "同期中に例外が出ても後続ジョブに漏らさない" do
      create_shops(pref_a, 1)
      allow(job).to receive(:invoke_task).and_raise("boom")

      job.perform

      expect(ENV["FORCE"]).to be_nil
    end
  end
end
