#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate

# Seed only on first deploy (when prefectures table is empty)
if bundle exec rails runner "exit(Prefecture.count == 0 ? 0 : 1)" 2>/dev/null; then
  bundle exec rails db:seed
fi
