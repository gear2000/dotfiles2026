#!/usr/bin/env bash
# The nvim-local hook: no directory, a valid local.lua, and a broken local.lua.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/config"
ln -s "$repo_dir/.dotfiles/config/nvim" "$tmp_root/config/nvim"

run_nvim() {
	XDG_CONFIG_HOME="$tmp_root/config" \
		XDG_DATA_HOME="${NVIM_TEST_DATA_HOME:-$tmp_root/data}" \
		XDG_STATE_HOME="$tmp_root/state" XDG_CACHE_HOME="$tmp_root/cache" \
		nvim --headless '+qa' 2>"$tmp_root/stderr"
}

# Plugins must already be present, otherwise lazy.nvim bootstraps and writes to
# stderr. check.sh passes its synced data dir; standalone runs sync once here.
if [[ -z "${NVIM_TEST_DATA_HOME:-}" ]]; then
	XDG_CONFIG_HOME="$tmp_root/config" XDG_DATA_HOME="$tmp_root/data" \
		XDG_STATE_HOME="$tmp_root/state" XDG_CACHE_HOME="$tmp_root/cache" \
		nvim --headless '+Lazy! sync' '+qa' >/dev/null 2>&1
fi

run_nvim
[[ ! -s "$tmp_root/stderr" ]] || { echo "ERROR: stderr not empty without nvim-local:"; cat "$tmp_root/stderr"; exit 1; } >&2

mkdir -p "$tmp_root/config/nvim-local/lua"
echo 'vim.g.nvim_local_loaded = true' >"$tmp_root/config/nvim-local/lua/local.lua"
run_nvim
[[ ! -s "$tmp_root/stderr" ]] || { echo "ERROR: stderr not empty with valid nvim-local:"; cat "$tmp_root/stderr"; exit 1; } >&2

echo 'error("boom")' >"$tmp_root/config/nvim-local/lua/local.lua"
run_nvim
grep -q 'nvim-local: ' "$tmp_root/stderr" || { echo "ERROR: broken local.lua did not warn" >&2; exit 1; }

echo "nvim-local: ok"
