# frozen_string_literal: true

namespace :maintenance do
  desc "Delete VoteSummary and Vote records older than N days (default: 30)"
  task :cleanup_old_votes, [:days] => :environment do |_t, args|
    $stdout.sync = true
    days = (args[:days] || 30).to_i
    cutoff = Date.current - days

    puts "=== Cleanup: deleting data older than #{cutoff} (#{days} days) ==="

    # VoteSummary
    summary_count = VoteSummary.where("target_date < ?", cutoff).count
    puts "VoteSummary to delete: #{summary_count}"
    if summary_count > 0
      deleted = VoteSummary.where("target_date < ?", cutoff).delete_all
      puts "  -> Deleted #{deleted} VoteSummary records"
    end

    # Vote (skip callbacks for bulk delete)
    vote_count = Vote.where("voted_on < ?", cutoff).count
    puts "Vote to delete: #{vote_count}"
    if vote_count > 0
      deleted = Vote.where("voted_on < ?", cutoff).delete_all
      puts "  -> Deleted #{deleted} Vote records"
    end

    puts "=== Cleanup complete ==="
  end
end
