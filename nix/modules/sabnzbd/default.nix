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
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/sabnzbd";
    copyToRoot = [
      pkgs.sabnzbd
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
    #   groupadd -r -g ${toString config.kubetree.workloadMacros.securityContext.runAsUser} sabnzbd
    #   useradd -r -u ${toString config.kubetree.workloadMacros.securityContext.runAsGroup} -g sabnzbd -d /data sabnzbd
    # '';
    config.Entrypoint = [ (pkgs.lib.getExe pkgs.sabnzbd) ];
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
  ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.SABNZBD_API_KEY = {
      description = "SABnzbd API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''
        kubectl exec -n sabnzbd -c sabnzbd deploy/sabnzbd -- ${lib.getExe pkgs.gnugrep} '^api_key = ' "/data/sabnzbd.ini" | \
          cut -d ' ' -f3
      '';
    };
    homelab.cluster.backup.volumes.sabnzbd.sabnzbd = [ "/backups" ];
    services.k3s.images = [ image ];
    kubetree.resources.sabnzbd.workload = {
      apiVersion = "cluster.local";
      kind = "WorkloadMacro";
      metadata.name = "sabnzbd";
      spec = {
        allowEgress = [ "internet" ];
        template.metadata.labels = lib.optionalAttrs (config.homelab.privacyVPN.enable) {
          "cluster.local/egress-gateway" = "privacy-vpn";
        };
        ingressPort = 8080;
        dataPath = "/data";
        podSpecMacro = {
          name = "sabnzbd";
          initContainersByName.setup-config = {
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
            volumeMountsByPath."/data" = "data";
          };
          mainContainer = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            args = [
              "--disable-file-log"
              "--console"
              "--config-file"
              "/data/sabnzbd.ini"
            ];
            workingDir = "/data";
            portsByName.web = 8080;
            livenessProbe.httpGet.port = "web";
            readinessProbe.httpGet.port = "web";
            volumeMountsByPath = {
              "/usenet" = "downloads";
              "/tmp" = "tmp";
            };
          };
          volumesByName = {
            downloads = cfg.downloadsVolume;
            tmp.emptyDir = { };
          };
        };
      };
    };
  };
}
