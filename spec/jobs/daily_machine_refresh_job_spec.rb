require "rails_helper"

RSpec.describe DailyMachineRefreshJob, type: :job do
  subject(:job) { described_class.new }

  let(:invoked) { [] }

  before do
    allow(Rails.application).to receive(:load_tasks)
    allow(job).to receive(:invoke_task) { |name, *args| invoked << [ name, *args ] }
  end

  # yomislo-monthly は UTC 1〜5日 18:00 起動 = JST 2〜6日 03:00。
  # daily も同時刻に起動するため、この期間に月次サイクルが未完了なら DMMぱちタウンへの
  # 同時アクセスを避けて休止する。
  describe "月次ジョブとの排他" do
    it "JST 2〜6日で月次サイクルが未完了なら休止する" do
      travel_to Time.zone.parse("2026-08-06 03:00:00") do
        MonthlySyncProgress.current_cycle.update!(completed: false)

        job.perform

        expect(invoked).to be_empty
      end
    end

    it "JST 2〜6日でも月次サイクルが完了していれば実行する" do
      travel_to Time.zone.parse("2026-08-06 03:00:00") do
        MonthlySyncProgress.current_cycle.update!(completed: true)

        job.perform

        expect(invoked).to include([ "ptown:sync_shop_machines" ])
      end
    end

    it "月次ジョブが動かない JST 7日以降は未完了でも実行する" do
      travel_to Time.zone.parse("2026-08-07 03:00:00") do
        MonthlySyncProgress.current_cycle.update!(completed: false)

        job.perform

        expect(invoked).to include([ "ptown:sync_shop_machines" ])
      end
    end

    it "月次ジョブが動かない JST 1日は未完了でも実行する" do
      travel_to Time.zone.parse("2026-08-01 03:00:00") do
        MonthlySyncProgress.current_cycle.update!(completed: false)

        job.perform

        expect(invoked).to include([ "ptown:sync_shop_machines" ])
      end
    end
  end

  describe "フェーズ" do
    it "機種同期・設置機種同期・ジオコードを順に実行する" do
      travel_to Time.zone.parse("2026-08-10 03:00:00") do
        job.perform

        expect(invoked).to eq([
          [ "ptown:import_machines" ],
          [ "ptown:sync_shop_machines" ],
          [ "geocode:shops" ]
        ])
      end
    end
  end
end
