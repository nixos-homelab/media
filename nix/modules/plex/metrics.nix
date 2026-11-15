# The metrics of Plex: prometheus-plex-exporter as a sidecar while Alloy runs, and its monitor
{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.plex;
  exporter = pkgs.buildGoModule {
    pname = "prometheus-plex-exporter";
    # No releases: main as of 2024-08-21
    version = "0-unstable-2024-08-21";
    src = pkgs.fetchFromGitHub {
      owner = "jsclayton";
      repo = "prometheus-plex-exporter";
      rev = "041ea971fadc6db467ef8f792b6f4f824cc3034e";
      hash = "sha256-hKscZpuBXV0fJ3uAdzfFqyByvOaJNjJTJd8Ey+tD/CQ=";
    };
    # Vendored in the repo
    vendorHash = null;
    subPackages = [ "cmd/prometheus-plex-exporter" ];
    meta.mainProgram = "prometheus-plex-exporter";
  };
  # The exporter takes the admin token in PLEX_TOKEN. Plex keeps the token of the account that claimed it in
  # Preferences.xml, on the data volume the sidecar mounts read-only: no secret to set up. It exits when Plex isn't up
  # at its start or its event stream drops, and a sidecar that restarts takes the pod out of the Service, so this
  # runs it again instead, and waits for the token while the server isn't claimed yet
  wrapper = pkgs.writeShellApplication {
    name = "plex-exporter";
    runtimeInputs = [
      exporter
      pkgs.xq-xml
      pkgs.coreutils
    ];
    text = ''
      prefs=$1
      pid=
      trap 'kill "$pid" 2>/dev/null; wait "$pid" || true; exit 0' TERM INT
      while :; do
        if PLEX_TOKEN=$(xq -x '//Preferences/@PlexOnlineToken' "$prefs" 2>/dev/null) && [[ -n $PLEX_TOKEN ]]; then
          export PLEX_TOKEN
          prometheus-plex-exporter &
          pid=$!
          wait "$pid" || true
        fi
        sleep 10 &
        pid=$!
        wait "$pid" || true
      done
    '';
  };
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/plex-exporter";
    copyToRoot = [ wrapper ] ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Entrypoint = [ (lib.getExe wrapper) ];
  };
  # Where it listens, fixed in the exporter
  port = 9000;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { homelab.alloy.monitors.plex.podPort = port; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.plex.config.submodules.instances.plex.config.kubernetes.resources =
          {
            # After the main container: kubectl logs and exec still go to Plex without -c
            deployments.plex.spec.template.spec.containers.plex-exporter = {
              image = "${image.buildArgs.name}:${image.imageTag}";
              imagePullPolicy = "Never";
              args = [ "/Library/Application Support/Plex Media Server/Preferences.xml" ];
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
