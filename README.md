# dotfiles2026

Portable macOS dotfiles managed with nix-darwin, Home Manager, nix-homebrew, and a repo-backed `.dotfiles/config` tree.

## Fresh machine

```sh
git clone git@github.com:gear2000/dotfiles2026.git ~/dotfiles2026
cd ~/dotfiles2026
./setup.sh --install-nix
```

If Nix is already installed:

```sh
./setup.sh
```

The setup script detects:

- current macOS username
- Apple Silicon vs Intel Mac
- whether Nix and `darwin-rebuild` are available

It then:

- creates `~/.dotfiles -> <repo>`
- builds the flake with `DOTFILES_USER` and `DOTFILES_HOST_PLATFORM`
- applies nix-darwin/Home Manager
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
DOTFILES_HOST_PLATFORM="aarch64-darwin" # or x86_64-darwin
```

and invoke Nix with `--impure` so the same committed flake can be used across Macs.
