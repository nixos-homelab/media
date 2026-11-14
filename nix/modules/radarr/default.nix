{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.radarr;
  hllib = inputs.homelab-shared.lib;
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/radarr";
    copyToRoot =
      with pkgs;
      [
        radarr
        cacert
        xq-xml # for extracting the API token
      ]
      ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Env = [
      "CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    runAsRoot = ''
      #!${pkgs.runtimeShell}
      ${pkgs.dockerTools.shadowSetup}
      groupadd -r -g ${toString config.homelab.workloads.securityContext.runAsGroup} radarr
      useradd -r -u ${toString config.homelab.workloads.securityContext.runAsUser} -g radarr -d /data radarr
    '';
    config.Entrypoint = [ (pkgs.lib.getExe pkgs.radarr) ];
  };
in
{
  options.homelab.radarr = {
    enable = lib.mkEnableOption "radarr";
    debug = lib.mkEnableOption "debug mode";
    volumes = lib.mkOption {
      description = "Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec). rtorrent & usenet download volumes are added automatically.";
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  imports = [ inputs.setup-secrets.nixosModules.default ] ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.RADARR_API_KEY = {
      description = "Radarr API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''kubectl exec -n radarr -c radarr deploy/radarr -- xq -q 'Config>ApiKey' "/data/config.xml"'';
    };
    homelab.cluster.backup.volumes.radarr.radarr = [ "/Backups" ];
    homelab.cluster.images = [ image ];
    homelab.kubernetes.submodules.instances.radarr = {
      submodule = "workload";
      args = {
        allowEgress = [
          "internet"
          "plex"
          "prowlarr"
          "flood"
          "sabnzbd"
        ];
        ingressPort = 7878;
        dataPath = "/data";
        ports.web = 7878;
        container = {
          image = "${image.buildArgs.name}:${image.imageTag}";
          imagePullPolicy = "Never";
          args = [ "-data=/data" ];
          workingDir = "/data";
          securityContext.capabilities.add = [ "CHOWN" ];
          env.RADARR__AUTH__ENABLED.value = "false";
          env.RADARR__AUTH__METHOD.value = "External";
          env.RADARR__APP__LAUNCHBROWSER.value = "false";
          env.RADARR__UPDATE__MECHANISM.value = "external";
          # It doesn't answer for seconds at a time while busy (RSS sync, imports), and the 1 s default timeout
          # had it restarted many times a day
          livenessProbe = {
            httpGet = {
              port = "web";
              path = "/ping";
            };
            timeoutSeconds = 10;
          };
          readinessProbe = {
            httpGet = {
              port = "web";
              path = "/ping";
            };
            timeoutSeconds = 10;
          };
          startupProbe = {
            httpGet = {
              port = "web";
              path = "/ping";
            };
            timeoutSeconds = 10;
            failureThreshold = 30;
          };
          volumeMounts = {
            "/tmp".name = "tmp";
          }
          // lib.mapAttrs (path: _: { name = hllib.k8s.pathToMountName path; }) cfg.volumes
          // lib.optionalAttrs config.homelab.rtorrent.enable {
            "/torrents".name = "torrents";
          }
          // lib.optionalAttrs config.homelab.sabnzbd.enable {
            "/usenet".name = "usenet";
          };
        };
      };
      config.kubernetes.resources.deployments.radarr.spec.template.spec.volumes = {
        tmp.emptyDir = { };
      }
      // lib.mapAttrs' (
        path: source: lib.nameValuePair (hllib.k8s.pathToMountName path) source
      ) cfg.volumes
      // lib.optionalAttrs config.homelab.rtorrent.enable {
        torrents = config.homelab.rtorrent.downloadsVolume;
      }
      // lib.optionalAttrs config.homelab.sabnzbd.enable {
        usenet = config.homelab.sabnzbd.downloadsVolume;
      };
    };
  };
}
