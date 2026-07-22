{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs }:
    let
      envUser = builtins.getEnv "DOTFILES_USER";
      envHostPlatform = builtins.getEnv "DOTFILES_HOST_PLATFORM";
      envHomeDirectory = builtins.getEnv "DOTFILES_HOME";

      # Defaults keep `nix flake check` and local builds useful without --impure.
      # setup.sh/rebuild.sh pass the actual values with --impure on each machine.
      user = if envUser != "" then envUser else "gary";
      hostPlatform =
        if envHostPlatform != "" then envHostPlatform else "aarch64-darwin";
      isDarwin = builtins.match ".*-darwin" hostPlatform != null;
      homeDirectory =
        if envHomeDirectory != "" then envHomeDirectory
        else if isDarwin then "/Users/${user}"
        else "/home/${user}";
      darwinHostPlatform = if isDarwin then hostPlatform else "aarch64-darwin";
      darwinHomeDirectory =
        if isDarwin then homeDirectory else "/Users/${user}";

      linuxPkgs = import nixpkgs {
        system = hostPlatform;
        config.allowUnfree = true;
      };
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit user;
          hostPlatform = darwinHostPlatform;
          homeDirectory = darwinHomeDirectory;
        };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit user;
              homeDirectory = darwinHomeDirectory;
            };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { inherit user homeDirectory; };
        modules = [
          ./home.nix
          {
            home.enableNixpkgsReleaseCheck = false;
          }
        ];
      };
    };
}
