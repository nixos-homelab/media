{ self, inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  hllib = inputs.homelab-shared.lib;
  ccfg = config.homelab.cluster;
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
  cfg = config.homelab.rtorrent;
  kubelib = inputs.kube-generators.lib { inherit pkgs; };
  bittorrentPort = 6881;
  dhtPort = 6881;
  wrapper = pkgs.writeShellScriptBin "rtorrent-wrapper" ''
    set -eo pipefail
    cleanup() {
      set +e
      kill -$1 $RTORRENT_PID
      kill $TAIL_RTORRENT_PID
      kill $TAIL_EXECUTE_PID
      wait $RTORRENT_PID
      exit $?
    }

    main() {
      for signal in TERM HUP INT USR1 USR2 QUIT; do
        # shellcheck disable=2064
        trap "cleanup $signal" $signal
      done
      trap "cleanup TERM" EXIT

      rm -f /var/log/rtorrent.log /var/log/execute.log
      mkfifo /var/log/rtorrent.log /var/log/execute.log
      exec 3<>/var/log/rtorrent.log
      cat <&3 >&2 & TAIL_RTORRENT_PID=$!
      exec 4<>/var/log/execute.log
      cat <&4 >&2 & TAIL_EXECUTE_PID=$!
      rtorrent_opts=(-o system.daemon.set=true)
      [[ $EXTERNAL_IP = 0.0.0.0 ]] || rtorrent_opts+=(-i ''${EXTERNAL_IP})

      printf "Starting rtorrent: rtorrent %s %s\n" "''${rtorrent_opts[*]}" "$*" >&2
      "${pkgs.lib.getExe pkgs.rtorrent}" "''${rtorrent_opts[@]}" "$@" & RTORRENT_PID=$!

      wait $RTORRENT_PID
    }

    main "$@"
  '';
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/rtorrent";
    copyToRoot = [
      wrapper
      pkgs.cacert
      pkgs.rtorrent
      pkgs.bash
      pkgs.coreutils
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Env = [
      "RTORRENT_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
      "CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    config.Entrypoint = [ (pkgs.lib.getExe wrapper) ];
  };
  deployment = {
    apiVersion = "cluster.local";
    kind = "DeploymentMacro";
    metadata.name = "rtorrent";
    spec = {
      allowEgress = [ "internet" ];
      template.metadata.labels = lib.optionalAttrs (config.homelab.privacy-vpn.enable) {
        "cluster.local/egress-gateway" = "privacy-vpn";
      };
      podSpecMacro = {
        terminationGracePeriodSeconds = 10;
        initContainersByName.rm-locks = {
          image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
          imagePullPolicy = "Never";
          args = [
            ''rm -f "/data/rtorrent.pid" "/data/rtorrent.lock"''
          ];
          securityContext.readOnlyRootFilesystem = true;
          volumeMountsByPath."/data" = "data";
        };
        mainContainer = {
          image = "${image.buildArgs.name}:${image.imageTag}";
          imagePullPolicy = "Never";
          args = [
            "-n"
            "-d"
            "/torrents"
            "-s"
            "/data"
            "-p"
            "$(BITTORRENT_PORT)-$(BITTORRENT_PORT)"
            "-o"
            "dht.port.set=$(DHT_PORT)"
            "-o"
            "try_import=/etc/rtorrent.rc"
          ];
          livenessProbe.tcpSocket.port = "rpc";
          readinessProbe.tcpSocket.port = "rpc";
          # Not using createServicePod env arg, the ordering is significant when patching the deployment
          env = [
            {
              name = "EXTERNAL_IP";
              value = "0.0.0.0";
            }
            {
              name = "BITTORRENT_PORT";
              value = builtins.toString bittorrentPort;
            }
            {
              name = "DHT_PORT";
              value = builtins.toString dhtPort;
            }
          ];
          ports = [
            {
              name = "rpc";
              containerPort = 5000;
            }
            (
              {
                name = "bittorrent";
                protocol = "TCP";
                containerPort = bittorrentPort;
              }
              // (lib.optionalAttrs config.homelab.privacy-vpn.enable {
                hostPort = bittorrentPort;
                hostIP = lib.maybeAttr "clientIP4" config.homelab.privacy-vpn.clientIP6 config.homelab.privacy-vpn;
              })
            )
            (
              {
                name = "dht";
                protocol = "UDP";
                containerPort = dhtPort;
              }
              // (lib.optionalAttrs config.homelab.privacy-vpn.enable {
                hostPort = dhtPort;
                hostIP = lib.maybeAttr "clientIP4" config.homelab.privacy-vpn.clientIP6 config.homelab.privacy-vpn;
              })
            )
          ];
          volumeMountsByPath = {
            "/data" = "data";
            "/torrents" = "downloads";
            "/etc/rtorrent.rc" = {
              name = "config";
              subPath = "rtorrent.rc";
            };
            "/var/log" = "log";
            "/var/run" = "run";
          };
        };
        volumesByName = {
          data.persistentVolumeClaim.claimName = "rtorrent";
          downloads = cfg.downloadsVolume;
          config.configMap.name = "rtorrent";
          log.emptyDir = { };
          run.emptyDir = { };
        };
      };
    };
  };
in
{
  options.homelab.rtorrent = {
    enable = lib.mkEnableOption "rtorrent";
    debug = lib.mkEnableOption "debug mode";
    downloadsVolume = lib.mkOption {
      description = "Volume source (as specificed on the pod spec) to place downloads in";
      type = lib.types.attrsOf lib.types.anything;
    };
  };
  imports = [ inputs.homelab-networking.nixosModules.privacy-vpn ];
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ bittorrentPort ];
    services.k3s.images = [ image ];
    kubetree.resources.rtorrent-deployment.deployment = deployment;
    services.k3s.manifests.rtorrent-deployment.enable = !config.homelab.privacy-vpn.enable;
    kubetree.resources.rtorrent = {
      world-to-rtorrent = {
        apiVersion = "cilium.io/v2";
        kind = "CiliumNetworkPolicy";
        metadata = {
          namespace = "rtorrent";
          name = "world-to-rtorrent";
          labels."app.kubernetes.io/name" = "rtorrent";
        };
        spec.endpointSelector.matchLabels."app.kubernetes.io/name" = "rtorrent";
        spec.ingress = [
          {
            fromEntities = [ "world" ];
            toPortsFlattened = [
              {
                port = "5001";
                endPort = 65535;
              }
            ];
          }
        ];
      };
      config = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata.name = "rtorrent";
        metadata.namespace = "rtorrent";
        data."rtorrent.rc" = builtins.readFile ./rtorrent.rc;
      };
      namespace = (hllib.k8s.createNamespace { namespace = "rtorrent"; });
      data = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata.namespace = "rtorrent";
        metadata.name = "rtorrent";
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "1Gi";
          volumeMode = "Filesystem";
        };
      };
      service = {
        apiVersion = "cluster.local";
        kind = "ServiceMacro";
        metadata.name = "rtorrent";
        spec.portsByName.scgi = 5000;
      };
      netpols = {
        apiVersion = "cluster.local";
        kind = "NetpolMacro";
        metadata.name = "rtorrent";
        spec.ports = [ 5000 ];
      };
    };

    systemd.timers."portmap-rtorrent" = lib.mkIf (config.homelab.privacy-vpn.enable) {
      description = "Request the privacy VPN server to forward a port for rtorrent";
      wantedBy = [ "timers.target" ];
      # The gateway's mappings last 60 s: renewed every 30 s, one failed round leaves no gap
      timerConfig = {
        OnUnitActiveSec = "30";
        AccuracySec = "1";
      };
    };

    systemd.services."portmap-rtorrent" = lib.mkIf (config.homelab.privacy-vpn.enable) {
      description = "Request the privacy VPN server to forward a port for rtorrent and setup the rtorrent deployment";
      after = [
        "k3s.service"
        "sys-devices-virtual-net-privacy-vpn.device"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
      script = ''
        set -eo pipefail
        # A deadline per try: natpmpc's own retries run for half a minute
        natpmpcmd() { timeout 10 ${lib.getExe pkgs.libnatpmp} -g ${
          lib.maybeAttr "gatewayIP4" config.homelab.privacy-vpn.gatewayIP6 config.homelab.privacy-vpn
        } "$@" | tee >(cat >&2); }
        # The gateway answers out of order or not at all now and then: each request gets its own tries, and prints the
        # field asked for once it has it
        request() {
          local pattern=$1 field=$2 try out
          shift 2
          for try in 1 2 3; do
            if out=$(natpmpcmd "$@") && out=$(grep -m1 "$pattern" <<<"$out"); then
              cut -d ' ' -f "$field" <<<"$out"
              return 0
            fi
            printf 'natpmpc %s: try %d failed\n' "$*" "$try" >&2
            sleep 1
          done
          return 1
        }
        main() {
          local external_ip bittorrent_port dht_port overlay_dir
          # One after the other, the mappings first, each whatever the other did: the gateway refuses requests that
          # come in at the same time. As Proton documents it (UDP first, `1 0`, 60 s): the gateway hands out one port
          # per client for both and forwards it unchanged, so the ports asked for don't matter
          dht_port=$(request 'Mapped public port' 4 -a 1 0 udp 60) || true
          bittorrent_port=$(request 'Mapped public port' 4 -a 1 0 tcp 60) || true
          external_ip=$(request 'Public IP address : ' 5) || true
          if [[ -z $external_ip || -z $bittorrent_port || -z $dht_port ]]; then
            printf 'Mappings incomplete (ip=%s tcp=%s udp=%s), rtorrent left as it is\n' \
              "$external_ip" "$bittorrent_port" "$dht_port" >&2
            exit 1
          fi
          overlay_dir=$(mktemp -d --suffix -rtorrent-deployment)
          trap 'rm -rf "$overlay_dir"' EXIT

          cp "${
            kubelib.toYAMLFile {
              apiVersion = "kustomize.config.k8s.io/v1beta1";
              kind = "Kustomization";
              resources = [ "rtorrent.yaml" ];
              patches = [
                {
                  path = "ports.yaml";
                  target.kind = "Deployment";
                  target.name = "rtorrent";
                }
              ];
            }
          }" "$overlay_dir/kustomization.yaml"
          cp "${kubelib.toYAMLFile (inputs.kubetree.lib.transform.transformResource config.kubetree deployment)}" "$overlay_dir/rtorrent.yaml"
          cat >"$overlay_dir/ports.yaml" <<EOF
        - op: replace
          path: /spec/template/spec/containers/0/env/0/value
          value: "$external_ip"
        - op: replace
          path: /spec/template/spec/containers/0/env/1/value
          value: "$bittorrent_port"
        - op: replace
          path: /spec/template/spec/containers/0/env/2/value
          value: "$dht_port"
        - op: replace
          path: /spec/template/spec/containers/0/ports/1/containerPort
          value: $bittorrent_port
        - op: replace
          path: /spec/template/spec/containers/0/ports/2/containerPort
          value: $dht_port
        EOF
          ${lib.getExe pkgs.kubectl} apply -k "$overlay_dir"
        }

        main "$@"
      '';
    };
  };
}
