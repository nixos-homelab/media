# The metrics of Radarr: an exportarr sidecar while Alloy runs, and its monitor
{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  exportarr = import ../exportarr.nix { inherit pkgs lib; };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.radarr.enable (
    lib.mkMerge [
      { homelab.alloy.monitors.radarr.podPort = exportarr.port; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ exportarr.image ];
        homelab.kubernetes.submodules.instances.radarr.config = {
          kubernetes.resources = {
            deployments.radarr.spec.template = {
              # The sidecar sorts first, where kubectl logs and exec would go without -c
              metadata.annotations."kubectl.kubernetes.io/default-container" = "radarr";
              spec.containers.exportarr = exportarr.container {
                app = "radarr";
                url = "http://127.0.0.1:7878";
                dataPath = "/data";
                config = "config.xml";
              };
            };
            services.radarr.spec.ports.metrics.port = exportarr.port;
          };
        };
      })
    ]
  );
}
