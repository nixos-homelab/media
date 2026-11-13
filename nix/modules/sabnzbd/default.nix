{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.sabnzbd;
  hllib = inputs.homelab-shared.lib;
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
  # Without notify2 (desktop notifications, optional in sabnzbd), which drags in dbus, glib and their -dev outputs
  sabnzbd = pkgs.sabnzbd.override {
    python3 = pkgs.python3 // {
      withPackages = f: pkgs.python3.withPackages (ps: lib.remove ps.notify2 (f ps));
    };
  };
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/sabnzbd";
    copyToRoot = [
      sabnzbd
      pkgs.cacert
      pkgs.coreutils
      pkgs.gnugrep
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Env = [
      "CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    # TODO: Is this necessary?
    # runAsRoot = ''
    #   #!${pkgs.runtimeShell}
    #   ${pkgs.dockerTools.shadowSetup}
    #   groupadd -r -g ${toString config.kubetree.workload-macros.securityContext.runAsGroup} sabnzbd
    #   useradd -r -u ${toString config.kubetree.workload-macros.securityContext.runAsUser} -g sabnzbd -d /data sabnzbd
    # '';
    config.Entrypoint = [ (lib.getExe sabnzbd) ];
  };
in
{
  options.homelab.sabnzbd = {
    enable = lib.mkEnableOption "sabnzbd";
    debug = lib.mkEnableOption "debug mode";
    downloadsVolume = lib.mkOption {
      description = "Volume source (as specificed on the pod spec) to place downloads in";
      type = lib.types.attrsOf lib.types.anything;
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-networking.nixosModules.privacy-vpn
  ]
  ++ self.lib.importsApply [
    ./integration.nix
    ./homepage.nix
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.SABNZBD_API_KEY = {
      description = "SABnzbd API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''
        ${lib.getExe pkgs.kubectl} exec -n sabnzbd -c sabnzbd deploy/sabnzbd -- ${lib.getExe pkgs.gnugrep} '^api_key = ' "/data/sabnzbd.ini" | \
          cut -d ' ' -f3
      '';
    };
    homelab.cluster.backup.volumes.sabnzbd.sabnzbd = [ "/backups" ];
    services.k3s.images = [ image ];
    homelab.kubernetes.submodules.instances.sabnzbd = {
      submodule = "manifest";
      config.submodules.instances.sabnzbd = {
        submodule = "workload";
        args = {
          allowEgress = [ "internet" ];
          ingressPort = 8080;
          dataPath = "/data";
          ports.web = 8080;
          container = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            args = [
              "--disable-file-log"
              "--console"
              "--config-file"
              "/data/sabnzbd.ini"
            ];
            workingDir = "/data";
            livenessProbe.httpGet.port = "web";
            readinessProbe.httpGet.port = "web";
            volumeMounts = {
              "/usenet".name = "downloads";
              "/tmp".name = "tmp";
            };
          };
        };
        config.kubernetes.resources.deployments.sabnzbd.spec.template = {
          metadata.labels = lib.optionalAttrs config.homelab.privacy-vpn.enable {
            "cluster.local/egress-gateway" = "privacy-vpn";
          };
          spec = {
            initContainers.setup-config = {
              image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
              imagePullPolicy = "Never";
              args = [
                ''
                  [[ -f "/data/sabnzbd.ini" ]] || cat >"/data/sabnzbd.ini" <<'EOF'
                  [misc]
                  host = 0.0.0.0
                  port = 8080
                  host_whitelist = sabnzbd.${ccfg.domain},sabnzbd.sabnzbd,
                  download_dir = /usenet/incomplete
                  complete_dir = /usenet/complete
                  schedlines = "1 0 21 7 create_backup ",
                  backup_dir = "/data/backups"
                  permissions = 775
                  EOF
                ''
              ];
              securityContext.readOnlyRootFilesystem = true;
              volumeMounts."/data".name = "data";
            };
            volumes = {
              downloads = cfg.downloadsVolume;
              tmp.emptyDir = { };
            };
          };
        };
      };
    };
  };
}
