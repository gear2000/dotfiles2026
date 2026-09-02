{ config, lib, pkgs, ... }:

let
  cliProxyApiPackage = pkgs.llm-agents.cli-proxy-api;
  proxyHost = "127.0.0.1";
  proxyPort = 8317;
  configPath = "${config.xdg.configHome}/cli-proxy-api/config.yaml";

  claudex = pkgs.writeShellApplication {
    name = "claudex";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = builtins.readFile ./scripts/claudex;
  };
  claudexDoctor = pkgs.writeShellApplication {
    name = "claudex-doctor";
    runtimeInputs = [ pkgs.curl pkgs.jq cliProxyApiPackage ];
    text = builtins.readFile ./scripts/claudex-doctor;
  };
  claudexLogin = pkgs.writeShellApplication {
    name = "claudex-login";
    runtimeInputs = [ cliProxyApiPackage ];
    text = builtins.readFile ./scripts/claudex-login;
  };
in
{
  home.packages = [
    cliProxyApiPackage
    claudex
    claudexDoctor
    claudexLogin
  ];

  # This file contains only portable policy. OAuth sessions and generated
  # provider state remain outside the Nix store in ~/.cli-proxy-api/.
  xdg.configFile."cli-proxy-api/config.yaml".text = ''
    host: "${proxyHost}"
    port: ${toString proxyPort}
    tls:
      enable: false
      cert: ""
      key: ""
    remote-management:
      allow-remote: false
      secret-key: ""
      disable-control-panel: true
      disable-auto-update-panel: true
    auth-dir: "~/.cli-proxy-api"
    # Non-secret local client marker, not an upstream credential. The proxy
    # rejects requests that omit it; loopback binding is the access boundary.
    api-keys:
      - "claudex-loopback"
    debug: false
    pprof:
      enable: false
      addr: "127.0.0.1:8316"
    logging-to-file: false
    usage-statistics-enabled: false
  '';

  systemd.user.services.cli-proxy-api = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Loopback-only CLIProxyAPI for ClaudeX";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${cliProxyApiPackage}/bin/cli-proxy-api --config ${configPath}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  launchd.agents.cli-proxy-api = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "org.nix-community.home.cli-proxy-api";
      ProgramArguments = [
        "${cliProxyApiPackage}/bin/cli-proxy-api"
        "--config"
        configPath
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
    };
  };
}
