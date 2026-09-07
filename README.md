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

## ClaudeX (Claude Code through Codex OAuth)

Home Manager installs [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
and three wrappers. It also starts a per-user proxy on `127.0.0.1:8317`.
Remote management and the management control panel are disabled. The committed
configuration contains no upstream credentials. Its fixed client marker is not
a secret; the loopback bind is the access boundary. OAuth state is created only
in `~/.cli-proxy-api/`.

After rebuilding, authorize CLIProxyAPI with Codex:

```sh
claudex-login             # device code; works locally and over SSH
claudex-login --browser   # optional local-browser callback flow
```

The default prints a short-lived code to enter at OpenAI's device-login page,
so the shell and browser do not need to be on the same machine. Never copy the
resulting files, terminal output, tokens, or account details into this
repository. Check the service and required model afterward:

```sh
claudex-doctor                 # checks gpt-5.6-sol
claudex-doctor another-model   # checks an explicit model
```

Use ClaudeX with its default model or an optional first model argument. All
remaining arguments are passed to Claude Code unchanged; put `--` first when a
positional prompt should use the default model:

```sh
claudex --dangerously-skip-permissions
claudex gpt-5.6-sol --effort max -p "Summarize this repository"
claudex -- "Start with README.md"
```

`claudex` refuses to launch if `claude` is missing, the proxy is stopped, or
the selected model is absent from `/v1/models`. It sets the loopback gateway,
main model, subagent model, proxy effort support, tool concurrency of three, and
upfront tool loading only for the child process. It adds `--effort high` when no
effort flag was supplied, then uses `exec`. A native flag such as `--effort max`
is forwarded once and remains effective. The raw `claude` command and shell
environment are unchanged and continue to use Anthropic normally.

To stop the proxy temporarily:

```sh
systemctl --user stop cli-proxy-api                    # Linux
launchctl bootout "gui/$UID/org.nix-community.home.cli-proxy-api" # macOS
```

A later Home Manager activation starts it again. To disable ClaudeX
persistently, remove `./modules/claudex.nix` from `home.nix`'s `imports`, rebuild,
and remove local state separately if desired. Never add that state to Git.

## Machine-local overrides

Home Manager owns `~/.zshrc`, `~/.zshenv`, `~/.bash_aliases` (Linux), and all of
`~/.config/nvim`. On every switch it replaces those with store symlinks and keeps
a pre-existing file as `<file>.hm-backup`, which nothing sources afterwards.
Keep per-machine aliases, functions, and settings in these files instead. They are
never declared in `home.nix`, so a switch never touches them:

| File | Loaded by |
|------|-----------|
| `~/.zshrc.local` | last line of the managed `.zshrc`, after repo aliases, so local definitions win |
| `~/.bash_aliases.local` | last line of the managed `.bash_aliases` (Linux) |
| `~/.config/nvim-local/lua/local.lua` | end of `init.lua`, after plugins load; options and keymaps only, no new plugins |

After each switch, `setup.sh` prints any newly created `.hm-backup` file with a
restore hint. Blind spot: if the same path is backed up twice, the second backup
overwrites the first and is not reported. `tests/local-overrides.sh` fails the
build if the source lines disappear or a managed entry claims one of these paths.

To recover something a past switch hid, look in the backup and move it over:

```sh
grep -n awsuse ~/.zshrc.hm-backup ~/.zshenv.hm-backup 2>/dev/null
# then paste the function into ~/.zshrc.local and open a new shell
```

## Repo layout

```text
.
├── flake.nix
├── configuration.nix
├── home.nix
├── modules/
│   ├── claudex.nix
│   └── scripts/
├── tests/
│   ├── backup-report.sh
│   ├── claudex.sh
│   ├── local-overrides.sh
│   └── nvim-local.sh
├── setup.sh
├── rebuild.sh
├── check.sh
└── .dotfiles/
    └── config/
        ├── cmux/
        ├── git/
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
- on Ubuntu/Debian, manages shared Bash aliases through the `~/.bash_aliases` file sourced by the default `~/.bashrc`
- manages Zsh config, Starship, autosuggestions, and syntax highlighting
- manages shared `~/.config` files
- does not configure system-level services, NixOS modules, display managers, drivers, sudo, or distro package managers

That keeps `./setup.sh --linux` safe to run on ordinary Linux distributions with Nix installed.
