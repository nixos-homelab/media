# FlareSolverr: solves Cloudflare challenges in a headless Chromium, for the indexers of Prowlarr behind Cloudflare
{ self, inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.flaresolverr;
  # Without a font configuration the Chromium renderer crashes as it starts
  fontsConf = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/flaresolverr";
    copyToRoot = [
      pkgs.flaresolverr
      pkgs.cacert
      # At /etc/fonts/fonts.conf, which also puts it and the fonts in the image
      (pkgs.runCommand "fonts-conf" { }
        "mkdir -p $out/etc/fonts && ln -s ${fontsConf} $out/etc/fonts/fonts.conf"
      )
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Env = [
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      # Chromium and Xvfb write their profile, locks and sockets here
      "HOME=/tmp"
      "FONTCONFIG_FILE=${fontsConf}"
    ];
    config.Entrypoint = [ (lib.getExe pkgs.flaresolverr) ];
  };
in
{
  options.homelab.flaresolverr = {
    enable = lib.mkEnableOption "FlareSolverr";
    debug = lib.mkEnableOption "debug mode";
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
  ]
  ++ self.lib.importsApply [
    ./home-area.nix
    ./logs.nix
    ../integration-logs.nix
    ./integration.nix
  ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.images = [ image ];
    homelab.kubernetes.submodules.instances.flaresolverr = {
      submodule = "manifest";
      config.submodules.instances.flaresolverr = {
        submodule = "workload";
        args = {
          allowEgress = [ "internet" ];
          ports.api = 8191;
          container = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            env.LOG_LEVEL.value = if cfg.debug then "debug" else "info";
            # It starts Chromium once at startup to find its user agent
            startupProbe = {
              httpGet = {
                port = "api";
                path = "/health";
              };
              failureThreshold = 30;
            };
            livenessProbe = {
              httpGet = {
                port = "api";
                path = "/health";
              };
              timeoutSeconds = 10;
            };
            readinessProbe = {
              httpGet = {
                port = "api";
                path = "/health";
              };
              timeoutSeconds = 10;
            };
            volumeMounts."/tmp".name = "tmp";
          };
        };
        config.kubernetes.resources.deployments.flaresolverr.spec.template.spec.volumes.tmp.emptyDir = { };
      };
    };
  };
}
