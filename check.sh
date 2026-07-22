#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -m)" in
  arm64) default_host_platform="aarch64-darwin" ;;
  x86_64) default_host_platform="x86_64-darwin" ;;
  *) default_host_platform="aarch64-darwin" ;;
esac

export DOTFILES_USER="${DOTFILES_USER:-${USER:-gary}}"
export DOTFILES_HOST_PLATFORM="${DOTFILES_HOST_PLATFORM:-$default_host_platform}"

nix --extra-experimental-features 'nix-command flakes' flake check "$repo_dir" --impure
darwin-rebuild build --flake "$repo_dir#mac" --impure

tmp_root="$(mktemp -d)"
XDG_CONFIG_HOME="$repo_dir/.dotfiles/config" \
XDG_DATA_HOME="$tmp_root/data" \
XDG_STATE_HOME="$tmp_root/state" \
XDG_CACHE_HOME="$tmp_root/cache" \
  nvim --headless '+Lazy! sync' '+qa'
