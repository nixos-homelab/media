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
  options.homelab.radarr.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes Radarr's metrics, and runs its exportarr sidecar.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf (config.homelab.radarr.enable && config.homelab.radarr.metrics.enable) (
    lib.mkMerge [
      {
        homelab.alloy.monitors.radarr = {
          podPort = exportarr.port;
          # Its instance is a workload, which can't hold the policy (kubenix nesting): a manifest of its own
          manifest = null;
        };
      }
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
