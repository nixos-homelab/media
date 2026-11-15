# The metrics of Plex: prometheus-plex-exporter as a sidecar while Alloy runs, and its monitor
{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.plex;
  # Its published image (alpine and the binary; no releases, so main by digest), pinned in the Dockerfile here
  image =
    (inputs.homelab-shared.lib.images.pinned pkgs ./Dockerfile)
    ."ghcr.io/jsclayton/prometheus-plex-exporter";
  # The exporter takes the admin token in PLEX_TOKEN. Plex keeps it in Preferences.xml once claimed, on the data
  # volume the sidecar mounts read-only: wait until it's there, then exec the exporter. Waiting keeps the pod Ready,
  # so an unclaimed Plex stays reachable to be claimed; when the exporter exits, the kubelet restarts it
  start = ''
    prefs='/Library/Application Support/Plex Media Server/Preferences.xml'
    trap 'exit 0' TERM INT
    until PLEX_TOKEN=$(sed -n 's/.*PlexOnlineToken="\([^"]*\)".*/\1/p' "$prefs" 2>/dev/null) && [ -n "$PLEX_TOKEN" ]; do
      sleep 10 &
      wait $!
    done
    export PLEX_TOKEN
    exec /prometheus-plex-exporter
  '';
  # Where it listens, fixed in the exporter
  port = 9000;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.plex.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes Plex's metrics, and runs its prometheus-plex-exporter sidecar.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) (
    lib.mkMerge [
      { homelab.alloy.monitors.plex.podPort = port; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.plex.config.submodules.instances.plex.config.kubernetes.resources =
          {
            # After the main container: kubectl logs and exec still go to Plex without -c
            deployments.plex.spec.template.spec.containers.plex-exporter = {
              image = image.ref;
              imagePullPolicy = "Never";
              command = [
                "/bin/sh"
                "-c"
                start
              ];
              env.PLEX_SERVER.value = "http://127.0.0.1:32400";
              ports = [
                {
                  name = "metrics";
                  containerPort = port;
                }
              ];
              securityContext = {
                allowPrivilegeEscalation = false;
                readOnlyRootFilesystem = true;
                capabilities.drop = [ "ALL" ];
              };
              volumeMounts."/Library" = {
                name = "data";
                readOnly = true;
              };
            };
            services.plex.spec.ports.metrics.port = port;
          };
      })
    ]
  );
}
