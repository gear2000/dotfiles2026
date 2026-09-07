#!/usr/bin/env bash
# Fixture test for setup.sh's report_new_backups.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# shellcheck disable=SC1091
SETUP_SH_LIB_ONLY=1 source "$repo_dir/setup.sh"

printf '%s\n' /h/.config/git/ignore.hm-backup >"$tmp_dir/before"
printf '%s\n' /h/.config/git/ignore.hm-backup /h/.zshrc.hm-backup >"$tmp_dir/after"
out="$(report_new_backups "$tmp_dir/before" "$tmp_dir/after")"
grep -Fq '/h/.zshrc.hm-backup' <<<"$out"
! grep -Fq 'git/ignore' <<<"$out"
grep -Fq '.zshrc.local' <<<"$out"

# unchanged and empty cases print nothing
[[ -z "$(report_new_backups "$tmp_dir/after" "$tmp_dir/after")" ]]
: >"$tmp_dir/empty"
[[ -z "$(report_new_backups "$tmp_dir/empty" "$tmp_dir/empty")" ]]

echo "backup-report: ok"
