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
      groupadd -r -g ${toString config.kubetree.workloadMacros.securityContext.runAsUser} plex
      useradd -r -u ${toString config.kubetree.workloadMacros.securityContext.runAsGroup} -g plex -d / plex
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
    volumes = lib.mkOption {
      description = "Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec).";
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  imports = [ inputs.setup-secrets.nixosModules.default ] ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    setup-secrets.sources.PLEX_API_KEY = {
      description = "Plex API Key";
      cmd = inputs.homelab-shared.lib.setup-secrets.mkScript pkgs ''
        kubectl exec -n plex -c plex deploy/plex -- \
          xq -x '//Preferences/@PlexOnlineToken' "/Library/Application Support/Plex Media Server/Preferences.xml"
      '';
    };
    homelab.cluster.backup.volumes.plex.plex = [ "/Application Support/Plex Media Server" ];
    services.k3s.images = [ image ];
    kubetree.resources.plex = {
      certificate = {
        apiVersion = "cert-manager.io/v1";
        kind = "Certificate";
        metadata = {
          namespace = "plex";
          name = "plex";
          labels."app.kubernetes.io/name" = "plex";
        };
        spec = {
          secretName = "plex-tls";
          commonName = "plex.${ccfg.domain}";
          dnsNames = [ "plex.${ccfg.domain}" ];
          issuerRef = {
            group = "cert-manager.io";
            kind = "ClusterIssuer";
            name = config.kubetree.workloadMacros.acmeProvider;
          };
          keystores.pkcs12 = {
            create = true;
            password = "plex";
            profile = "Modern2023";
          };
        };
      };
      external-service = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          namespace = "plex";
          name = "plex-external";
          labels."app.kubernetes.io/name" = "plex";
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = "plex.${ccfg.domain}";
          }
          // lib.optionalAttrs (builtins.length cfg.reservedIPs > 0) ({
            "lbipam.cilium.io/ips" = lib.join "," cfg.reservedIPs;
          });
        };
        spec = {
          type = "LoadBalancer";
          selector."app.kubernetes.io/name" = "plex";
          ipFamilies = (lib.optional ccfg.enableIPv4 "IPv4") ++ (lib.optional ccfg.enableIPv6 "IPv6");
          ports = [
            {
              name = "web";
              port = 443;
              targetPort = 32400;
            }
          ];
        }
        // (lib.optionalAttrs (ccfg.enableIPv4 && ccfg.enableIPv6) {
          ipFamilyPolicy = "RequireDualStack";
        });
      };
      workload = {
        apiVersion = "cluster.local";
        kind = "WorkloadMacro";
        metadata.name = "plex";
        spec = {
          allowIngress = [ "local-lan" ];
          allowEgress = [ "internet" ];
          dataPath = "/Library";
          podSpecMacro = {
            initContainersByName.rm-lock = {
              image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
              imagePullPolicy = "Never";
              args = [
                ''rm -f "/Library/Application Support/Plex Media Server/plexmediaserver.pid"''
              ];
              securityContext.readOnlyRootFilesystem = true;
              volumeMountsByPath."/Library" = "data";
            };
            mainContainer = {
              image = "${image.buildArgs.name}:${image.imageTag}";
              imagePullPolicy = "Never";
              portsByName.web = 32400;
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
              volumeMountsByPath = {
                "/tls" = "tls";
                "/var/tmp" = "var-tmp";
                "/tmp" = "tmp";
              }
              // lib.mapAttrs' (name: value: {
                inherit name;
                value = {
                  name = (hllib.k8s.pathToMountName name);
                  readOnly = true;
                };
              }) cfg.volumes;
            };
            volumesByName = {
              tls.secret.secretName = "plex-tls";
              var-tmp.emptyDir = { };
              tmp.emptyDir = { };
            }
            // lib.mapAttrs' (name: value: {
              name = (hllib.k8s.pathToMountName name);
              inherit value;
            }) cfg.volumes;
          };
        };
      };
    };
  };
}
