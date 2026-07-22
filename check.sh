#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s):$(uname -m)" in
  Darwin:arm64) default_host_platform="aarch64-darwin" ;;
  Darwin:x86_64) default_host_platform="x86_64-darwin" ;;
  Linux:x86_64) default_host_platform="x86_64-linux" ;;
  Linux:aarch64|Linux:arm64) default_host_platform="aarch64-linux" ;;
  *) default_host_platform="aarch64-darwin" ;;
esac

export DOTFILES_USER="${DOTFILES_USER:-${USER:-gary}}"
export DOTFILES_HOST_PLATFORM="${DOTFILES_HOST_PLATFORM:-$default_host_platform}"
export DOTFILES_HOME="${DOTFILES_HOME:-$HOME}"

nix --extra-experimental-features 'nix-command flakes' flake check "$repo_dir" --impure

case "$DOTFILES_HOST_PLATFORM" in
  *-darwin)
    darwin-rebuild build --flake "$repo_dir#mac" --impure
    ;;
  *-linux)
    nix --extra-experimental-features 'nix-command flakes' run github:nix-community/home-manager/release-26.05 -- \
      --flake "$repo_dir#$DOTFILES_USER" --impure --no-out-link build
    ;;
  *)
    echo "Unsupported DOTFILES_HOST_PLATFORM: $DOTFILES_HOST_PLATFORM" >&2
    exit 1
    ;;
esac

tmp_root="$(mktemp -d)"
XDG_CONFIG_HOME="$repo_dir/.dotfiles/config" \
XDG_DATA_HOME="$tmp_root/data" \
XDG_STATE_HOME="$tmp_root/state" \
XDG_CACHE_HOME="$tmp_root/cache" \
  nvim --headless '+Lazy! sync' '+qa'
