{ self, inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
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
  imports = [
    inputs.homelab-networking.nixosModules.privacy-vpn
    # The Cilium types, for world-to-rtorrent
    inputs.homelab-networking.nixosModules.cilium-crds
  ];
  config = lib.mkIf cfg.enable {
    # With the privacy VPN, peers come in through its port mapping
    networking.firewall =
      if config.homelab.privacy-vpn.enable then
        { interfaces.privacy-vpn.allowedTCPPorts = [ bittorrentPort ]; }
      else
        { allowedTCPPorts = [ bittorrentPort ]; };
    homelab.cluster.images = [ image ];
    homelab.cluster.manifests.rtorrent-deployment.enable = !config.homelab.privacy-vpn.enable;
    homelab.kubernetes.submodules.instances =
      let
        labels."app.kubernetes.io/name" = "rtorrent";
        toPorts = inputs.homelab-networking.lib.toPorts;
      in
      {
        # The runner applies it without the privacy VPN; with it, portmap-rtorrent does, with the ports the VPN maps
        rtorrent-deployment = {
          name = "rtorrent";
          submodule = "deployment";
          args = {
            allowEgress = [ "internet" ];
            container = {
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
              # Lists, not the `ports` arg: portmap-rtorrent patches them by index. No `ports` also means no
              # policies here; the rtorrent manifest has them
              env = [
                {
                  name = "EXTERNAL_IP";
                  value = "0.0.0.0";
                }
                {
                  name = "BITTORRENT_PORT";
                  value = toString bittorrentPort;
                }
                {
                  name = "DHT_PORT";
                  value = toString dhtPort;
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
              volumeMounts = {
                "/data".name = "data";
                "/torrents".name = "downloads";
                "/etc/rtorrent.rc" = {
                  name = "config";
                  subPath = "rtorrent.rc";
                };
                "/var/log".name = "log";
                "/var/run".name = "run";
              };
            };
          };
          config.kubernetes.resources.deployments.rtorrent.spec.template = {
            metadata.labels = lib.optionalAttrs config.homelab.privacy-vpn.enable {
              "cluster.local/egress-gateway" = "privacy-vpn";
            };
            spec = {
              terminationGracePeriodSeconds = 10;
              initContainers.rm-locks = {
                image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
                imagePullPolicy = "Never";
                args = [
                  ''rm -f "/data/rtorrent.pid" "/data/rtorrent.lock"''
                ];
                securityContext.readOnlyRootFilesystem = true;
                volumeMounts."/data".name = "data";
              };
              volumes = {
                data.persistentVolumeClaim.claimName = "rtorrent";
                downloads = cfg.downloadsVolume;
                config.configMap.name = "rtorrent";
                log.emptyDir = { };
                run.emptyDir = { };
              };
            };
          };
        };
        rtorrent = {
          submodule = "manifest";
          config = {
            kubernetes.resources = {
              # Cluster-scoped: no namespace, which kubenix gives every object by default
              namespaces.rtorrent.metadata.namespace = null;
              configMaps.rtorrent.data."rtorrent.rc" = builtins.readFile ./rtorrent.rc;
              persistentVolumeClaims.rtorrent.spec = {
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = "1Gi";
                volumeMode = "Filesystem";
              };
              ciliumNetworkPolicies.world-to-rtorrent = {
                metadata = { inherit labels; };
                spec = {
                  endpointSelector.matchLabels = labels;
                  ingress = [
                    {
                      fromEntities = [ "world" ];
                      toPorts = toPorts [
                        {
                          port = 5001;
                          endPort = 65535;
                        }
                      ];
                    }
                  ];
                };
              };
            };
            submodules.instances.rtorrent = {
              submodule = "service";
              args.ports.scgi = 5000;
            };
            # The pods of rtorrent-deployment, here since the runner doesn't always apply that manifest: pods labeled
            # `cluster.local/rtorrent-egress: allow` may reach 5000
            submodules.instances.rtorrent-pods = {
              name = "rtorrent";
              submodule = "pods";
              args.ports.scgi = 5000;
            };
          };
        };
      };

    systemd.timers."portmap-rtorrent" = lib.mkIf (config.homelab.privacy-vpn.enable) {
      description = "Request the privacy VPN server to forward a port for rtorrent";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "45";
        AccuracySec = "1";
      };
    };

    systemd.services."portmap-rtorrent" = lib.mkIf (config.homelab.privacy-vpn.enable) {
      description = "Request the privacy VPN server to forward a port for rtorrent and setup the rtorrent deployment";
      after = [
        config.homelab.cluster.unit
        "sys-devices-virtual-net-privacy-vpn.device"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
      script = ''
        set -eo pipefail
        # Prints field of the line matching pattern in natpmpc's output, and the whole output only when it fails
        natpmpcmd() {
          local pattern=$1 field=$2 out line
          shift 2
          out=$(${lib.getExe pkgs.libnatpmp} -g ${
            lib.maybeAttr "gatewayIP4" config.homelab.privacy-vpn.gatewayIP6 config.homelab.privacy-vpn
          } "$@" 2>&1) || true
          if ! line=$(grep -m1 "$pattern" <<<"$out"); then
            printf 'natpmpc %s failed:\n%s\n' "$*" "$out" >&2
            return 1
          fi
          cut -d ' ' -f "$field" <<<"$line"
        }
        main() {
          local external_ip bittorrent_port dht_port overlay_dir
          # As Proton documents it: UDP first, 60 s
          dht_port=$(natpmpcmd 'Mapped public port' 4 -a 0 ${builtins.toString dhtPort} udp 60)
          bittorrent_port=$(natpmpcmd 'Mapped public port' 4 -a 0 ${builtins.toString bittorrentPort} tcp 60)
          external_ip=$(natpmpcmd 'Public IP address : ' 5)
          overlay_dir=$(mktemp -d --suffix -rtorrent-deployment)
          trap "rm -rf \"$overlay_dir\"" EXIT

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
          cp "${
            kubelib.toYAMLFile (
              lib.findSingle (
                o: o.kind == "Deployment"
              ) null null config.homelab.cluster.manifests.rtorrent-deployment.content
            )
          }" "$overlay_dir/rtorrent.yaml"
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
