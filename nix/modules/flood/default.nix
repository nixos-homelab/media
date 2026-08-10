{ self, inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.flood;
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/flood";
    copyToRoot = [
      pkgs.flood
      pkgs.mediainfo
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Entrypoint = [
      (pkgs.lib.getExe pkgs.flood)
    ];
  };
in
{
  options.homelab.flood = {
    enable = lib.mkEnableOption "flood";
    debug = lib.mkEnableOption "debug mode";
  };
  imports = self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.rtorrent.enable;
        message = "The rtorrent service must be enabled in order for flood to work (homelab.rtorrent.enable)";
      }
    ];
    services.k3s.images = [ image ];
    kubetree.resources.flood.workload = {
      apiVersion = "cluster.local";
      kind = "WorkloadMacro";
      metadata.name = "flood";
      spec = {
        allowEgress = [ "rtorrent" ];
        ingressPort = 3000;
        dataPath = "/data";
        podSpecMacro.mainContainer = {
          image = "${image.buildArgs.name}:${image.imageTag}";
          imagePullPolicy = "Never";
          args = [
            "--host=0.0.0.0"
            "--rthost=rtorrent.rtorrent"
            "--rtport=5000"
            "--rundir=/data"
            "--auth=none"
          ];
          portsByName.web = 3000;
          livenessProbe.httpGet.port = "web";
          readinessProbe.httpGet.port = "web";
          volumeMountsByPath."/torrents" = "downloads";
        };
        podSpecMacro.volumesByName.downloads = config.homelab.rtorrent.downloadsVolume;
      };
    };
  };
}
