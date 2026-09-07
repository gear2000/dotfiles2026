#!/usr/bin/env bash
# Guard: managed rc files end by sourcing machine-local override files, and no
# managed entry ever claims a reserved local path. Evaluates the Linux
# configuration, which works from both macOS and Linux hosts.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
user="${DOTFILES_USER:-${USER:-gary}}"
nix_eval=(nix --extra-experimental-features 'nix-command flakes' eval --impure "$repo_dir#homeConfigurations.${user}.config.home.file")

eval_text() {
	DOTFILES_USER="$user" DOTFILES_HOST_PLATFORM=x86_64-linux DOTFILES_HOME="/home/$user" \
		"${nix_eval[0]}" "${nix_eval[@]:1}".\""$1"\".text --raw
}
last_line() {
	grep -v '^[[:space:]]*$' | tail -n 1 | sed 's/^[[:space:]]*//'
}

[[ "$(eval_text ./.zshrc | last_line)" == '[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"' ]] ||
	{ echo "ERROR: .zshrc does not end by sourcing ~/.zshrc.local" >&2; exit 1; }
[[ "$(eval_text .bash_aliases | last_line)" == '[ -r "$HOME/.bash_aliases.local" ] && . "$HOME/.bash_aliases.local"' ]] ||
	{ echo "ERROR: .bash_aliases does not end by sourcing ~/.bash_aliases.local" >&2; exit 1; }

names="$(DOTFILES_USER="$user" DOTFILES_HOST_PLATFORM=x86_64-linux DOTFILES_HOME="/home/$user" \
	nix --extra-experimental-features 'nix-command flakes' eval --impure --json \
	"$repo_dir#homeConfigurations.${user}.config.home.file" --apply builtins.attrNames)"
if printf '%s' "$names" | jq -e '
	map(sub("^\\./"; "")) | map(select(
		. == ".zshrc.local" or . == ".bash_aliases.local" or
		. == ".config/nvim-local" or startswith(".config/nvim-local/")
	)) | length > 0' >/dev/null; then
	echo "ERROR: home.file declares a reserved machine-local path: $names" >&2
	exit 1
fi
echo "local-overrides: ok"
