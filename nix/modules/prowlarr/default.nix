{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.prowlarr;
  hllib = inputs.homelab-shared.lib;
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/prowlarr";
    copyToRoot =
      with pkgs;
      [
        prowlarr
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
      groupadd -r -g ${toString config.kubetree.workload-macros.securityContext.runAsGroup} prowlarr
      useradd -r -u ${toString config.kubetree.workload-macros.securityContext.runAsUser} -g prowlarr -d /data prowlarr
    '';
    config.Entrypoint = [ (pkgs.lib.getExe pkgs.prowlarr) ];
  };
in
{
  options.homelab.prowlarr = {
    enable = lib.mkEnableOption "prowlarr";
    debug = lib.mkEnableOption "debug mode";
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
  ]
  ++ self.lib.importsApply [
    ./homepage.nix
    ./integration.nix
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.PROWLARR_API_KEY = {
      description = "Prowlarr API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''kubectl exec -n prowlarr -c prowlarr deploy/prowlarr -- xq -q 'Config>ApiKey' "/data/config.xml"'';
    };
    homelab.cluster.backup.volumes.prowlarr.prowlarr = [ "/Backups" ];
    services.k3s.images = [ image ];
    homelab.kubernetes.submodules.instances.prowlarr = {
      submodule = "manifest";
      config.submodules.instances.prowlarr = {
        submodule = "workload";
        args = {
          allowEgress = [
            "internet"
            "sonarr"
            "radarr"
            "flood"
            "sabnzbd"
          ];
          ingressPort = 9696;
          dataPath = "/data";
          ports.web = 9696;
          container = {
            image = "${image.buildArgs.name}:${image.imageTag}";
            imagePullPolicy = "Never";
            args = [ "-data=/data" ];
            workingDir = "/data";
            env.PROWLARR__AUTH__ENABLED.value = "false";
            env.PROWLARR__AUTH__METHOD.value = "External";
            env.PROWLARR__APP__LAUNCHBROWSER.value = "false";
            env.PROWLARR__UPDATE__MECHANISM.value = "external";
            # It doesn't answer for seconds at a time while busy, and the 1 s default timeout had it restarted
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
            volumeMounts."/tmp".name = "tmp";
          };
        };
        config.kubernetes.resources.deployments.prowlarr.spec.template.spec.volumes.tmp.emptyDir = { };
      };
    };
  };
}
