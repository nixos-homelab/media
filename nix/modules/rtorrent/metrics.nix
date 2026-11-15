# The metrics of rtorrent: rtorrent_exporter and an SCGI bridge as sidecars while Alloy runs, and their monitor
{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.rtorrent;
  metricsPort = 9135;
  # rtorrent speaks SCGI on 5000, rtorrent_exporter XML-RPC over HTTP only (its client, go-rtorrent, POSTs to a URL):
  # nginx bridges the two, in the pod and on localhost only
  bridgePort = 8000;
  rtorrentExporter = pkgs.buildGoModule rec {
    pname = "rtorrent_exporter";
    version = "1.3.2";
    src = pkgs.fetchFromGitHub {
      owner = "thde";
      repo = pname;
      rev = "e79ce427fd812cb1e9d1b0e3be0a9180f8e69cca";
      hash = "sha256-DqXAAIGc8KBy0YOZA7LbEzeS8C+9CYFh5f7qskAFDT4=";
    };
    vendorHash = "sha256-IubJ1PbjaPBE2jvEIOPIjCa8FcQjRDoi5I9LhlevFEg=";
    # Its scrape returns 1 for rtorrent_up when it fails and 0 when it succeeds: swapped back
    postPatch = ''
      sed -i -e 's/return 1$/return 2/' -e 's/return 0$/return 1/' -e 's/return 2$/return 0/' exporter/exporter.go
    '';
    ldflags = [ "-X github.com/prometheus/common/version.Version=${version}" ];
    meta.mainProgram = "rtorrent_exporter";
  };
  # Pid and temp paths under /tmp, an emptyDir: the root filesystem is read-only
  bridgeConfig = pkgs.writeTextDir "etc/nginx/scgi-bridge.conf" ''
    daemon off;
    worker_processes 1;
    pid /tmp/nginx.pid;
    error_log stderr warn;
    events {}
    http {
      access_log off;
      client_body_temp_path /tmp/client_body;
      proxy_temp_path /tmp/proxy;
      fastcgi_temp_path /tmp/fastcgi;
      uwsgi_temp_path /tmp/uwsgi;
      scgi_temp_path /tmp/scgi;
      server {
        listen 127.0.0.1:${toString bridgePort};
        location = /RPC2 {
          include ${pkgs.nginx}/conf/scgi_params;
          scgi_pass 127.0.0.1:5000;
        }
      }
    }
  '';
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/rtorrent-exporter";
    copyToRoot = [
      rtorrentExporter
      pkgs.nginx
      bridgeConfig
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
  };
  securityContext = {
    allowPrivilegeEscalation = false;
    readOnlyRootFilesystem = true;
    capabilities.drop = [ "ALL" ];
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.rtorrent.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes rtorrent's metrics, and runs its rtorrent_exporter and SCGI bridge sidecars.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) (
    lib.mkMerge [
      { homelab.alloy.monitors.rtorrent.podPort = metricsPort; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances = {
          rtorrent.config.submodules.instances.rtorrent.config.kubernetes.resources.services.rtorrent.spec.ports.metrics.port =
            metricsPort;
          # Both sort after rtorrent, which portmap-rtorrent patches as the first container
          rtorrent-deployment.config.kubernetes.resources.deployments.rtorrent.spec.template.spec = {
            containers = {
              rtorrent-exporter = {
                image = "${image.buildArgs.name}:${image.imageTag}";
                imagePullPolicy = "Never";
                # The copy at the image's root: buildImage copies the package's files there, and its store path isn't in
                # the image (the binary doesn't reference itself), so getExe's path doesn't exist in the container
                command = [ "/bin/rtorrent_exporter" ];
                args = [
                  "--web.listen-address=:${toString metricsPort}"
                  "--rtorrent.scrape-uri=http://127.0.0.1:${toString bridgePort}/RPC2"
                ];
                ports = [
                  {
                    name = "metrics";
                    containerPort = metricsPort;
                  }
                ];
                inherit securityContext;
              };
              rtorrent-scgi-bridge = {
                image = "${image.buildArgs.name}:${image.imageTag}";
                imagePullPolicy = "Never";
                command = [
                  (lib.getExe pkgs.nginx)
                  "-e"
                  "stderr"
                  "-c"
                  "/etc/nginx/scgi-bridge.conf"
                ];
                inherit securityContext;
                volumeMounts."/tmp".name = "bridge-tmp";
              };
            };
            volumes.bridge-tmp.emptyDir = { };
          };
        };
      })
    ]
  );
}
