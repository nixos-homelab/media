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
  # dist/ is a self-contained bundle; node_modules holds only devDependencies
  flood = pkgs.flood.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm -r $out/lib/node_modules/flood/node_modules
    '';
  });
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/flood";
    copyToRoot = [
      flood
      pkgs.mediainfo
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Entrypoint = [
      (lib.getExe flood)
    ];
  };
in
{
  options.homelab.flood = {
    enable = lib.mkEnableOption "flood";
    debug = lib.mkEnableOption "debug mode";
  };
  imports = self.lib.importsApply [
    ./homepage.nix
    ./integration.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.rtorrent.enable;
        message = "The rtorrent service must be enabled in order for flood to work (homelab.rtorrent.enable)";
      }
    ];
    homelab.cluster.images = [ image ];
    homelab.kubernetes.submodules.instances.flood = {
      submodule = "manifest";
      config.submodules.instances.flood = {
        submodule = "workload";
        args = {
          allowEgress = [ "rtorrent" ];
          ingressPort = 3000;
          dataPath = "/data";
          ports.web = 3000;
          container = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            args = [
              "--host=0.0.0.0"
              "--rthost=rtorrent.rtorrent"
              "--rtport=5000"
              "--rundir=/data"
              "--auth=none"
            ];
            livenessProbe.httpGet.port = "web";
            readinessProbe.httpGet.port = "web";
            volumeMounts."/torrents".name = "downloads";
          };
        };
        config.kubernetes.resources.deployments.flood.spec.template.spec.volumes.downloads =
          config.homelab.rtorrent.downloadsVolume;
      };
    };
  };
}
