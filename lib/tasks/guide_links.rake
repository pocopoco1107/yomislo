# frozen_string_literal: true

namespace :guide_links do
  desc "全アクティブ機種の攻略リンクを Google CSE で取得 (rake guide_links:fetch / rake guide_links:fetch[machine_slug])"
  task :fetch, [:machine_slug] => :environment do |_task, args|
    $stdout.sync = true

    dry_run = ENV["DRY_RUN"] == "1"
    limit   = ENV["LIMIT"]&.to_i

    fetcher = GuideLinkFetcher.new(dry_run: dry_run)

    if args[:machine_slug].present?
      fetcher.fetch_by_slug(args[:machine_slug])
    else
      fetcher.fetch_all(limit: limit)
    end
  end
end
