{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  hllib = inputs.homelab-shared.lib;
  cfg = config.homelab.plex;
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/plex";
    copyToRoot =
      with pkgs;
      [
        plexRaw
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
      groupadd -r -g ${toString config.homelab.workloads.securityContext.runAsGroup} plex
      useradd -r -u ${toString config.homelab.workloads.securityContext.runAsUser} -g plex -d / plex
      # https://github.com/NixOS/nixpkgs/blob/3f40c4f8c496308680d71d9e17bce452928a2e17/pkgs/servers/plex/default.nix#L57
      cat "${pkgs.plexRaw.basedb}" >/db
    '';
    config.Entrypoint = [
      "${pkgs.plexRaw}/lib/plexmediaserver/Plex Media Server"
    ];
  };
in
{
  options.homelab.plex = {
    # Run `kubectl port-forward -n plex plex-... 32400` after startup to set it up
    # The setup procedure is only enabled when accessing the server via localhost:32400/web
    enable = lib.mkEnableOption "Plex Media Server";
    debug = lib.mkEnableOption "debug mode";
    reservedIPs = lib.mkOption {
      description = "Reserved IPs for the Plex loadbalancer";
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    allowIngress = lib.mkOption {
      description = "Which services and groups should be allowed to access Plex";
      type = lib.types.listOf lib.types.str;
      default = [ "local-lan" ];
      defaultText = ''The "local-lan" group'';
      example = lib.literalExpression ''["local-lan" "internet"]'';
    };
    tlsDomains = lib.mkOption {
      description = "List of domains the plex serving certificate should contain";
      type = lib.types.listOf lib.types.str;
      default = [ "plex.${config.homelab.workloads.domain}" ];
      defaultText = lib.literalExpression ''[ "plex.''${config.homelab.workloads.domain}"]'';
      example = lib.literalExpression ''["plex.''${config.homelab.workloads.domain}" "plex.external.''${config.homelab.workloads.domain}"]'';
    };
    volumes = lib.mkOption {
      description = "Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec).";
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
  ]
  ++ self.lib.importsApply [
    ./integration.nix
    ./homepage.nix
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.PLEX_API_KEY = {
      description = "Plex API Key";
      cmd = hllib.setup-secrets.mkScript pkgs ''
        kubectl exec -n plex -c plex deploy/plex -- \
          xq -x '//Preferences/@PlexOnlineToken' "/Library/Application Support/Plex Media Server/Preferences.xml"
      '';
    };
    homelab.cluster.backup.volumes.plex.plex = [ "/Application Support/Plex Media Server" ];
    services.k3s.images = [ image ];
    setup-secrets.destinations = [
      {
        logPrefix = "Plex API key";
        requires = [ "PLEX_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret plex plex-api-key \
            PLEX_API_KEY "''${PLEX_API_KEY:?}"
        '';
      }
    ];
    homelab.kubernetes.submodules.instances.plex =
      let
        domain = "plex.${config.homelab.workloads.domain}";
        keystorePassword = "plex";
        labels."app.kubernetes.io/name" = "plex";
        ipFamilies = {
          ipFamilies = (lib.optional ccfg.enableIPv4 "IPv4") ++ (lib.optional ccfg.enableIPv6 "IPv6");
        }
        // (lib.optionalAttrs (ccfg.enableIPv4 && ccfg.enableIPv6) {
          ipFamilyPolicy = "RequireDualStack";
        });
      in
      {
        submodule = "manifest";
        config = {
          kubernetes.resources = {
            certificates.plex = {
              metadata = { inherit labels; };
              spec = {
                secretName = "plex-tls";
                commonName = domain;
                dnsNames = cfg.tlsDomains;
                issuerRef = {
                  group = "cert-manager.io";
                  kind = "ClusterIssuer";
                  name = config.homelab.workloads.acmeProvider;
                };
                keystores.pkcs12 = {
                  create = true;
                  password = keystorePassword;
                  profile = "Modern2023";
                };
              };
            };
            services.plex-external = {
              metadata = {
                inherit labels;
                annotations = {
                  "external-dns.alpha.kubernetes.io/hostname" = domain;
                }
                // lib.optionalAttrs (builtins.length cfg.reservedIPs > 0) {
                  "lbipam.cilium.io/ips" = lib.join "," cfg.reservedIPs;
                };
              };
              spec = ipFamilies // {
                type = "LoadBalancer";
                selector = labels;
                ports = {
                  web = {
                    port = 443;
                    targetPort = 32400;
                  };
                  plex = {
                    port = 32400;
                    targetPort = 32400;
                  };
                };
              };
            };
          };
          submodules.instances = {
            configure =
              let
                apiUrl = "https://plex.plex:32400/:/prefs";
                queryParams = {
                  IPNetworkType =
                    {
                      "10" = "v4only";
                      "01" = "v6only";
                      "11" = "dualstack";
                    }
                    .${
                      lib.concatMapStrings (on: if on then "1" else "0") [
                        ccfg.enableIPv4
                        ccfg.enableIPv6
                      ]
                    };
                  secureConnections = "1"; # "Preferred", needed for Arr stack connectivity
                  DisableTLSv1_0 = "1";
                  customConnections = "https://${domain}:443/";
                  customCertificatePath = "/tls/keystore.p12";
                  customCertificateKey = keystorePassword;
                  customCertificateDomain = domain;
                };
                queryString = lib.join "&" (
                  lib.mapAttrsToList (name: value: "${name}=${lib.escapeURL value}") queryParams
                );
              in
              {
                submodule = "script";
                args = {
                  allowEgress = [ "plex" ];
                  script = ''
                    set -eo pipefail
                    echo "Configuring Plex" >&2
                    if curl --insecure -sfX PUT '${apiUrl}?${queryString}' \
                      -H "X-Plex-Token: ''${PLEX_API_KEY:?}"; then
                      echo "Successfully configured Plex" >&2
                    else
                      echo "Failed to configure Plex" >&2
                      exit 1
                    fi
                  '';
                  container.envFrom = [ { secretRef.name = "plex-api-key"; } ];
                };
              };
            plex = {
              submodule = "workload";
              args = {
                allowIngress = cfg.allowIngress;
                allowEgress = [ "internet" ];
                dataPath = "/Library";
                ports.web = 32400;
                container = {
                  image = "${image.buildArgs.name}:${image.imageTag}";
                  imagePullPolicy = "Never";
                  livenessProbe.httpGet = {
                    scheme = "HTTPS";
                    port = "web";
                    path = "/identity";
                  };
                  readinessProbe.httpGet = {
                    scheme = "HTTPS";
                    port = "web";
                    path = "/identity";
                  };
                  volumeMounts = {
                    "/tls".name = "tls";
                    "/var/tmp".name = "var-tmp";
                    "/tmp".name = "tmp";
                  }
                  // lib.mapAttrs (path: _: {
                    name = hllib.k8s.pathToMountName path;
                    readOnly = true;
                  }) cfg.volumes;
                };
              };
              config.kubernetes.resources = {
                services.plex.spec = ipFamilies;
                deployments.plex.spec.template.spec = {
                  initContainers.rm-lock = {
                    image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
                    imagePullPolicy = "Never";
                    args = [
                      ''rm -f "/Library/Application Support/Plex Media Server/plexmediaserver.pid"''
                    ];
                    securityContext.readOnlyRootFilesystem = true;
                    volumeMounts."/Library".name = "data";
                  };
                  volumes = {
                    tls.secret.secretName = "plex-tls";
                    var-tmp.emptyDir = { };
                    tmp.emptyDir = { };
                  }
                  // lib.mapAttrs' (
                    path: source: lib.nameValuePair (hllib.k8s.pathToMountName path) source
                  ) cfg.volumes;
                };
              };
            };
          };
        };
      };
  };
}
