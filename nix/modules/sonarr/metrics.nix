# The metrics of Sonarr: an exportarr sidecar while Alloy runs, and its monitor
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
  config = lib.mkIf config.homelab.sonarr.enable (
    lib.mkMerge [
      {
        homelab.alloy.monitors.sonarr = {
          podPort = exportarr.port;
          # Its instance is a workload, which can't hold the policy (kubenix nesting): a manifest of its own
          manifest = null;
        };
      }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ exportarr.image ];
        homelab.kubernetes.submodules.instances.sonarr.config = {
          kubernetes.resources = {
            deployments.sonarr.spec.template = {
              # The sidecar sorts first, where kubectl logs and exec would go without -c
              metadata.annotations."kubectl.kubernetes.io/default-container" = "sonarr";
              spec.containers.exportarr = exportarr.container {
                app = "sonarr";
                url = "http://127.0.0.1:8989";
                dataPath = "/data";
                config = "config.xml";
              };
            };
            services.sonarr.spec.ports.metrics.port = exportarr.port;
          };
        };
      })
    ]
  );
}
