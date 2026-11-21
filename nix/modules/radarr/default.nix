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
        coreutils # for its mtime, setup-secrets' same command
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
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-storage.nixosModules.postgresql
    (import ../servarr-config.nix { inherit inputs; } {
      app = "radarr";
      port = 7878;
    })
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
      radarr.backup.enable = lib.mkDefault true;
      radarr-log = {
        namespace = "radarr";
        username = "radarr";
      };
    };
    assertions = [
      {
        assertion = config.homelab.postgresql.enable;
        message = "Radarr depends on the PostgreSQL service. Enable with `homelab.postgresql.enable=true`";
      }
    ];
    setup-secrets.sources.RADARR_API_KEY = hllib.setup-secrets.kubeExecSource pkgs {
      description = "Radarr API Key";
      namespace = "radarr";
      workload = "deploy/radarr";
      container = "radarr";
      command = "xq -q 'Config>ApiKey' /data/config.xml";
      same = "stat -c %Y /data/config.xml";
    };
    homelab.cluster.backup.volumes.radarr.radarr = [ "/Backups" ];
    homelab.cluster.images = [ image ];
    homelab.kubernetes.submodules.instances.radarr = {
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
          # PostgreSQL in place of SQLite on /data, whose I/O at a node shutdown kept a thread in uninterruptible sleep
          # past SIGKILL and held up the drain
          env.RADARR__POSTGRES__HOST.value = "postgresql.postgresql";
          env.RADARR__POSTGRES__USER.value = "radarr";
          env.RADARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
            name = "postgresql-password";
            key = "password";
          };
          env.RADARR__POSTGRES__MAINDB.value = "radarr";
          env.RADARR__POSTGRES__LOGDB.value = "radarr-log";
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
