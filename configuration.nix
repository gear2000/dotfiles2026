{ user, hostPlatform, homeDirectory, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = hostPlatform;

  system.primaryUser = user;
  users.users.${user} = {
    home = homeDirectory;
  };
  system.stateVersion = 6;

  # macOS 26 protects /etc/pam.d from third-party modifications.
  security.pam.services.sudo_local.enable = false;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    # Keep Homebrew synced to this list without zapping app data/settings.
    onActivation.cleanup = "uninstall";
    onActivation.autoUpdate = true;
    taps = [
      "datadog-labs/pack"
    ];
    brews = [
      "ack"
      "argocd"
      "datadog-labs/pack/pup"
      "gh"
      "go"
      "helm"
      "herdr"
      "infracost"
      "just"
      "kubie"
      "node"
      "opentofu"
      "pipx"
      "tmux"
      "tree"
      "uv"
      "watch"
    ];
    casks = [
      "claude-code"
      "keka"
      "microsoft-remote-desktop"
      "wezterm"
      "xquartz"
    ];
  };
}
