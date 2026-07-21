#!/usr/bin/env bash
# stimulus-check: Stimulus コントローラと HTML data-* 属性の整合性検査
# 実装は Python (check.py) に委譲する

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

exec python3 "$(dirname "${BASH_SOURCE[0]}")/check.py" "$@"
