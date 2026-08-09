{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.sonarr;
  hllib = inputs.homelab-shared.lib;
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/sonarr";
    copyToRoot =
      with pkgs;
      [
        sonarr
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
      groupadd -r -g ${toString config.kubetree.workload-macros.securityContext.runAsUser} sonarr
      useradd -r -u ${toString config.kubetree.workload-macros.securityContext.runAsGroup} -g sonarr -d /data sonarr
    '';
    config.Entrypoint = [ (pkgs.lib.getExe pkgs.sonarr) ];
  };
in
{
  options.homelab.sonarr = {
    enable = lib.mkEnableOption "sonarr";
    debug = lib.mkEnableOption "debug mode";
    mountPaths = lib.mkOption {
      description = "Paths from the host to mirror into the container";
      type = lib.types.listOf lib.types.path;
      default = [ ];
    };
    volumes = lib.mkOption {
      description = "Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec). rtorrent & usenet download volumes are added automatically.";
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  imports = [ inputs.setup-secrets.nixosModules.default ] ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.SONARR_API_KEY = {
      description = "Sonarr API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''kubectl exec -n sonarr -c sonarr deploy/sonarr -- xq -q 'Config>ApiKey' "/data/config.xml"'';
    };
    homelab.cluster.backup.volumes.sonarr.sonarr = [ "/Backups" ];
    services.k3s.images = [ image ];
    kubetree.resources.sonarr.content = {
      apiVersion = "cluster.local";
      kind = "WorkloadMacro";
      metadata.name = "sonarr";
      spec = {
        allowEgress = [
          "internet"
          "plex"
          "prowlarr"
          "flood"
          "sabnzbd"
        ];
        ingressPort = 8989;
        dataPath = "/data";
        podSpecMacro = {
          mainContainer = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            args = [ "-data=/data" ];
            workingDir = "/data";
            addCapabilities = [ "CHOWN" ];
            envByName.SONARR__AUTH__ENABLED = "false";
            envByName.SONARR__AUTH__METHOD = "External";
            envByName.SONARR__APP__LAUNCHBROWSER = "false";
            envByName.SONARR__UPDATE__MECHANISM = "external";
            portsByName.web = 8989;
            livenessProbe.httpGet = {
              port = "web";
              path = "/ping";
            };
            readinessProbe.httpGet = {
              port = "web";
              path = "/ping";
            };
            volumeMountsByPath = {
              "/tmp" = "tmp";
            }
            // lib.mapAttrs' (name: value: {
              inherit name;
              value = (hllib.k8s.pathToMountName name);
            }) cfg.volumes
            // lib.optionalAttrs config.homelab.rtorrent.enable {
              "/torrents" = "torrents";
            }
            // lib.optionalAttrs config.homelab.sabnzbd.enable {
              "/usenet" = "usenet";
            };
          };
          volumesByName = {
            tmp.emptyDir = { };
          }
          // lib.mapAttrs' (name: value: {
            name = (hllib.k8s.pathToMountName name);
            inherit value;
          }) cfg.volumes
          // lib.optionalAttrs config.homelab.rtorrent.enable {
            torrents = config.homelab.rtorrent.downloadsVolume;
          }
          // lib.optionalAttrs config.homelab.sabnzbd.enable {
            usenet = config.homelab.sabnzbd.downloadsVolume;
          };
        };
      };
    };
  };
}
