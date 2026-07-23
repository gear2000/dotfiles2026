# dotfiles2026

Portable dotfiles managed with Nix.

- macOS: nix-darwin + Home Manager + nix-homebrew
- Linux: standalone Home Manager for user-level packages and config
- Shared config: repo-backed `.dotfiles/config` tree

## Fresh macOS machine

```sh
git clone git@github.com:gear2000/dotfiles2026.git ~/dotfiles2026
cd ~/dotfiles2026
./setup.sh --macos --install-nix
```

If Nix is already installed:

```sh
./setup.sh --macos
```

## Fresh Linux machine

```sh
git clone git@github.com:gear2000/dotfiles2026.git ~/dotfiles2026
cd ~/dotfiles2026
./setup.sh --linux --install-nix
```

If Nix is already installed:

```sh
./setup.sh --linux
```

The setup script detects:

- current OS
- current username
- current home directory
- CPU architecture / Nix host platform
- whether Nix and `darwin-rebuild` are available

It then:

- creates `~/.dotfiles -> <repo>`
- builds the flake with `DOTFILES_USER`, `DOTFILES_HOME`, and `DOTFILES_HOST_PLATFORM`
- applies nix-darwin/Home Manager on macOS
- applies standalone Home Manager on Linux
- syncs Neovim plugins with Lazy

## Update an existing machine

```sh
cd ~/.dotfiles
git pull
./rebuild.sh
```

## Validate without changing system state

```sh
./check.sh
```

## Repo layout

```text
.
├── flake.nix
├── configuration.nix
├── home.nix
├── setup.sh
├── rebuild.sh
├── check.sh
└── .dotfiles/
    └── config/
        ├── cmux/
        ├── git/
        ├── herdr/
        ├── karabiner/
        ├── nvim/
        ├── opencode/
        ├── sunshine/
        └── wezterm/
```

## Important safety rule

Do not copy all of `~/.config` into this repo. Only copy portable config files. Avoid logs, state, sessions, tokens, host credentials, and generated caches.

The repo includes `.dotfiles/.gitignore` rules for common risky files, but review changes before committing.

## Nix portability details

The flake defaults to `gary` and `aarch64-darwin` so plain local evaluation remains useful. The setup/rebuild scripts pass machine-specific values through:

```sh
DOTFILES_USER="$USER"
DOTFILES_HOME="$HOME"
DOTFILES_HOST_PLATFORM="aarch64-darwin" # x86_64-darwin, x86_64-linux, or aarch64-linux
```

and invoke Nix with `--impure` so the same committed flake can be used across Macs.

## Linux scope

Linux support is intentionally user-level:

- installs Home Manager packages such as `neovim`, `wezterm`, `ripgrep`, `fd`, `fzf`, `jq`, and `lazygit`
- manages shared Bash aliases through `~/.bash_aliases`, plus Zsh config, Starship, autosuggestions, and syntax highlighting
- manages shared `~/.config` files
- does not configure system services, NixOS modules, display managers, drivers, sudo, or distro package managers

That keeps `./setup.sh --linux` safe to run on ordinary Linux distributions with Nix installed.
