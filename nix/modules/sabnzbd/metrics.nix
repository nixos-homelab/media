# The metrics of SABnzbd: an exportarr sidecar while Alloy runs, and its monitor
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
  config = lib.mkIf config.homelab.sabnzbd.enable (
    lib.mkMerge [
      { homelab.alloy.monitors.sabnzbd.podPort = exportarr.port; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ exportarr.image ];
        homelab.kubernetes.submodules.instances.sabnzbd.config.submodules.instances.sabnzbd.config = {
          kubernetes.resources = {
            deployments.sabnzbd.spec.template = {
              # The sidecar sorts first, where kubectl logs and exec would go without -c
              metadata.annotations."kubectl.kubernetes.io/default-container" = "sabnzbd";
              spec.containers.exportarr = exportarr.container {
                app = "sabnzbd";
                url = "http://127.0.0.1:8080";
                dataPath = "/data";
                config = "sabnzbd.ini";
              };
            };
            services.sabnzbd.spec.ports.metrics.port = exportarr.port;
          };
        };
      })
    ]
  );
}
