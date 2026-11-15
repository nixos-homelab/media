# The metrics of Prowlarr: an exportarr sidecar while Alloy runs, and its monitor
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
  config = lib.mkIf config.homelab.prowlarr.enable (
    lib.mkMerge [
      { homelab.alloy.monitors.prowlarr.podPort = exportarr.port; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ exportarr.image ];
        homelab.kubernetes.submodules.instances.prowlarr.config.submodules.instances.prowlarr.config = {
          kubernetes.resources = {
            deployments.prowlarr.spec.template = {
              # The sidecar sorts first, where kubectl logs and exec would go without -c
              metadata.annotations."kubectl.kubernetes.io/default-container" = "prowlarr";
              spec.containers.exportarr = exportarr.container {
                app = "prowlarr";
                url = "http://127.0.0.1:9696";
                dataPath = "/data";
                config = "config.xml";
              };
            };
            services.prowlarr.spec.ports.metrics.port = exportarr.port;
          };
        };
      })
    ]
  );
}
