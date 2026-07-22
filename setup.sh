#!/usr/bin/env bash
set -euo pipefail

usage() {
  sed -n '1,120p' "$0" | sed -n '/^# Usage:/,/^$/p' | sed 's/^# //'
}

# Usage:
#   ./setup.sh [--user USER] [--host-platform aarch64-darwin|x86_64-darwin] [--install-nix] [--no-switch] [--no-nvim-sync]
#
# Fresh-machine bootstrap for this dotfiles repo.
#
# What it does:
#   1. Detects macOS username and CPU architecture.
#   2. Optionally installs Determinate Nix when Nix is missing.
#   3. Creates ~/.dotfiles -> this repo for a stable local path.
#   4. Builds the nix-darwin/Home Manager system.
#   5. Applies it with darwin-rebuild switch unless --no-switch is passed.
#   6. Syncs Neovim plugins with Lazy unless --no-nvim-sync is passed.
#
# Notes:
#   - This repo is macOS-focused. Linux/WSL are intentionally not handled here.
#   - If Nix is missing, pass --install-nix to run the official Determinate installer.
#   - Existing Home Manager-managed file conflicts are backed up with .hm-backup.

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dotfiles_user="${USER:-$(id -un)}"
host_platform=""
install_nix=0
do_switch=1
do_nvim_sync=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      dotfiles_user="${2:?missing value for --user}"
      shift 2
      ;;
    --host-platform)
      host_platform="${2:?missing value for --host-platform}"
      shift 2
      ;;
    --install-nix)
      install_nix=1
      shift
      ;;
    --no-switch)
      do_switch=0
      shift
      ;;
    --no-nvim-sync)
      do_nvim_sync=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This setup currently supports macOS only." >&2
  exit 1
fi

if [ -z "$host_platform" ]; then
  case "$(uname -m)" in
    arm64) host_platform="aarch64-darwin" ;;
    x86_64) host_platform="x86_64-darwin" ;;
    *)
      echo "Unsupported macOS architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
fi

case "$host_platform" in
  aarch64-darwin|x86_64-darwin) ;;
  *)
    echo "Unsupported host platform: $host_platform" >&2
    exit 1
    ;;
esac

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Command Line Tools are missing. Run this, then rerun setup:"
  echo "  xcode-select --install"
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  if [ "$install_nix" -ne 1 ]; then
    echo "Nix is not installed."
    echo "Rerun with --install-nix to install Determinate Nix:"
    echo "  ./setup.sh --install-nix"
    exit 1
  fi

  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "nix is still not on PATH. Open a new terminal and rerun setup." >&2
  exit 1
fi

ln -sfn "$repo_dir" "/Users/${dotfiles_user}/.dotfiles"

export DOTFILES_USER="$dotfiles_user"
export DOTFILES_HOST_PLATFORM="$host_platform"

echo "Dotfiles repo:       $repo_dir"
echo "User:                $DOTFILES_USER"
echo "Host platform:       $DOTFILES_HOST_PLATFORM"
echo "Stable symlink:      /Users/${dotfiles_user}/.dotfiles -> $repo_dir"

nix --extra-experimental-features 'nix-command flakes' flake check "$repo_dir" --impure

if command -v darwin-rebuild >/dev/null 2>&1; then
  darwin_rebuild=(darwin-rebuild)
else
  darwin_rebuild=(nix --extra-experimental-features 'nix-command flakes' run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild --)
fi

"${darwin_rebuild[@]}" build --flake "$repo_dir#mac" --impure

if [ "$do_switch" -eq 1 ]; then
  sudo "${darwin_rebuild[@]}" switch --flake "$repo_dir#mac" --impure
else
  echo "Skipped switch because --no-switch was passed."
fi

if [ "$do_nvim_sync" -eq 1 ]; then
  if command -v nvim >/dev/null 2>&1; then
    nvim --headless '+Lazy! sync' '+qa'
  else
    echo "nvim is not on PATH yet. Open a new terminal after switch, then run:"
    echo "  nvim --headless '+Lazy! sync' '+qa'"
  fi
fi

echo "Setup complete."
