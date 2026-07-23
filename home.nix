{ lib, pkgs, user, homeDirectory, ... }:

{
  home.username = user;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.11";
  home.packages = (with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # terminal fonts
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ]) ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.wezterm
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"

      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      main = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
      ca = "agent --yolo";
    };
  };

  # Ubuntu's default ~/.bashrc sources this file, so Bash gets the same
  # shortcuts without Home Manager replacing the machine-specific ~/.bashrc.
  home.file.".bash_aliases" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      alias main='git switch main'
      alias cc='claude --dangerously-skip-permissions'
      alias co='codex --full-auto'
      alias ca='agent --yolo'
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  home.file.".config/wezterm/wezterm.lua".source = ./.dotfiles/config/wezterm/wezterm.lua;
  home.file.".config/nvim".source = ./.dotfiles/config/nvim;
  home.file.".config/git/ignore".source = ./.dotfiles/config/git/ignore;
  home.file.".config/cmux/cmux.json".source = ./.dotfiles/config/cmux/cmux.json;
  home.file.".config/herdr/config.toml".source = ./.dotfiles/config/herdr/config.toml;
  home.file.".config/karabiner/karabiner.json".source = ./.dotfiles/config/karabiner/karabiner.json;
  home.file.".config/opencode/commands/plannotator-annotate.md".source = ./.dotfiles/config/opencode/commands/plannotator-annotate.md;
  home.file.".config/opencode/commands/plannotator-last.md".source = ./.dotfiles/config/opencode/commands/plannotator-last.md;
  home.file.".config/opencode/commands/plannotator-review.md".source = ./.dotfiles/config/opencode/commands/plannotator-review.md;
  home.file.".config/sunshine/apps.json".source = ./.dotfiles/config/sunshine/apps.json;
  home.file.".config/sunshine/sunshine.conf".source = ./.dotfiles/config/sunshine/sunshine.conf;
}
