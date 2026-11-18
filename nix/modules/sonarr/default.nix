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
      groupadd -r -g ${toString config.homelab.workloads.securityContext.runAsGroup} sonarr
      useradd -r -u ${toString config.homelab.workloads.securityContext.runAsUser} -g sonarr -d /data sonarr
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
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-storage.nixosModules.postgresql
  ]
  ++ self.lib.importsApply [
    ./logs.nix
    ./homepage.nix
    ./grafana.nix
    ./metrics.nix
  ];
  config = lib.mkIf cfg.enable {
    # A main and a log database: both migrate with one version table, so they can't share a database
    homelab.postgresql.databases = {
      sonarr.backup.enable = lib.mkDefault true;
      sonarr-log = {
        namespace = "sonarr";
        username = "sonarr";
      };
    };
    assertions = [
      {
        assertion = config.homelab.postgresql.enable;
        message = "Sonarr depends on the PostgreSQL service. Enable with `homelab.postgresql.enable=true`";
      }
    ];
    setup-secrets.sources.SONARR_API_KEY = {
      description = "Sonarr API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''kubectl exec -n sonarr -c sonarr deploy/sonarr -- xq -q 'Config>ApiKey' "/data/config.xml"'';
    };
    homelab.cluster.backup.volumes.sonarr.sonarr = [ "/Backups" ];
    homelab.cluster.images = [ image ];
    homelab.kubernetes.submodules.instances.sonarr = {
      submodule = "workload";
      args = {
        allowEgress = [
          "internet"
          "postgresql"
          "plex"
          "prowlarr"
          "flood"
          "sabnzbd"
        ];
        ingressPort = 8989;
        dataPath = "/data";
        ports.web = 8989;
        container = {
          image = "${image.buildArgs.name}:${image.imageTag}";
          imagePullPolicy = "Never";
          args = [ "-data=/data" ];
          workingDir = "/data";
          securityContext.capabilities.add = [ "CHOWN" ];
          env.SONARR__AUTH__ENABLED.value = "false";
          env.SONARR__AUTH__METHOD.value = "External";
          env.SONARR__APP__LAUNCHBROWSER.value = "false";
          env.SONARR__UPDATE__MECHANISM.value = "external";
          # PostgreSQL in place of SQLite on /data, whose I/O at a node shutdown kept a thread in uninterruptible sleep
          # past SIGKILL and held up the drain
          env.SONARR__POSTGRES__HOST.value = "postgresql.postgresql";
          env.SONARR__POSTGRES__USER.value = "sonarr";
          env.SONARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
            name = "postgresql-password";
            key = "password";
          };
          env.SONARR__POSTGRES__MAINDB.value = "sonarr";
          env.SONARR__POSTGRES__LOGDB.value = "sonarr-log";
          # SIGTERM stops the ASP.NET Core host, which waits up to its shutdown timeout (30 s by default) for the
          # requests in flight. At a node shutdown the kubelet gives pods 20 s, so a request that hung had it killed and
          # held up the drain. The web host reads the host setting shutdownTimeoutSeconds from its ASPNETCORE_ variables
          env.ASPNETCORE_SHUTDOWNTIMEOUTSECONDS.value = "10";
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
      config.kubernetes.resources.deployments.sonarr.spec.template.spec.volumes = {
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
