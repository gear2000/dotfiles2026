{ pkgs, ... }:

let
  # Keep in step with the version llm-config-setup expects
  # (PINNED in its tools/install-herdr.sh). Digests are the official release
  # SHA-256 values published on the GitHub release.
  version = "0.9.5";
  assets = {
    "aarch64-darwin" = {
      name = "herdr-macos-aarch64";
      sha256 = "fb77c2232a05a8035421382c894392f4174e4e38a18e48af3dd0290157c3a7e2";
    };
    "x86_64-darwin" = {
      name = "herdr-macos-x86_64";
      sha256 = "5fb0a908ec7f6745e3e245738b06bfad56c46391c391ab3c0955fbead01f1369";
    };
    "aarch64-linux" = {
      name = "herdr-linux-aarch64";
      sha256 = "17d7536f2da50859523680ef279dffcac8e4a235f4e46fe8da6c2ec44141897c";
    };
    "x86_64-linux" = {
      name = "herdr-linux-x86_64";
      sha256 = "14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d";
    };
  };
  system = pkgs.stdenv.hostPlatform.system;
  asset = assets.${system} or (throw "herdr ${version}: no release binary for ${system}");

  herdr = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${version}/${asset.name}";
      inherit (asset) sha256;
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm755 "$src" "$out/bin/herdr"
    '';
  };
in
{
  # The binary only. Herdr's config and integrations stay with llm-config-setup.
  home.packages = [ herdr ];
}
