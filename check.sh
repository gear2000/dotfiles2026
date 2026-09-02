#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s):$(uname -m)" in
Darwin:arm64) default_host_platform="aarch64-darwin" ;;
Darwin:x86_64) default_host_platform="x86_64-darwin" ;;
Linux:x86_64) default_host_platform="x86_64-linux" ;;
Linux:aarch64 | Linux:arm64) default_host_platform="aarch64-linux" ;;
*) default_host_platform="aarch64-darwin" ;;
esac

export DOTFILES_USER="${DOTFILES_USER:-${USER:-gary}}"
export DOTFILES_HOST_PLATFORM="${DOTFILES_HOST_PLATFORM:-$default_host_platform}"
export DOTFILES_HOME="${DOTFILES_HOME:-$HOME}"

"$repo_dir/tests/claudex.sh"

# Ownership guard: LLM-harness config paths belong to llm-config-setup, never
# home-manager — HM force-replaces managed paths on every switch and would
# clobber files that kit deploys (e.g. ~/.claude/settings.json, herdr config).
if grep -nE '\.claude|\.pi/|\.codex|\.agents/skills|herdr' "$repo_dir/home.nix"; then
	echo "ERROR: home.nix declares an LLM-harness path owned by llm-config-setup (see matches above)" >&2
	exit 1
fi

nix --extra-experimental-features 'nix-command flakes' flake check "$repo_dir" --impure

# The upstream package flake does not publish x86_64-darwin directly. We use its
# shared-nixpkgs overlay, so evaluate both macOS architectures here to keep that
# portability contract from regressing unnoticed on a Linux development host.
for darwin_platform in aarch64-darwin x86_64-darwin; do
	DOTFILES_HOST_PLATFORM="$darwin_platform" \
	DOTFILES_HOME="/Users/$DOTFILES_USER" \
		nix --extra-experimental-features 'nix-command flakes' eval "$repo_dir#darwinConfigurations.mac.pkgs.llm-agents.cli-proxy-api.meta.mainProgram" \
		--impure --raw >/dev/null
done

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
