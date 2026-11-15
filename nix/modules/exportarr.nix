# exportarr as a sidecar in the pod of the app it exports, reading the app's API key from the app's data volume, mounted
# read-only: no secret to set up. Every pod gets the same image; the image links of the node are named after it, so it
# lands there once.
{ pkgs, lib }:
let
  port = 9707;
  # The app writes its config at its first start. A sidecar that exits takes its pod out of the Service until it
  # restarts, so this waits for the key instead
  wrapper = pkgs.writeShellApplication {
    name = "exportarr-sidecar";
    runtimeInputs = [
      pkgs.exportarr
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      app=$1 config=$2
      shift 2
      trap 'exit 0' TERM INT
      case $app in
        sabnzbd)
          # exportarr takes no sabnzbd.ini, but reads API_KEY as --api-key: in the environment, it's not on a command
          # line
          until API_KEY=$(sed -n 's/^api_key = \(.\+\)$/\1/p' "$config" 2>/dev/null) && [[ -n $API_KEY ]]; do
            sleep 5 &
            wait $!
          done
          export API_KEY
          ;;
        *)
          until grep -qs '<ApiKey>.\+</ApiKey>' "$config"; do
            sleep 5 &
            wait $!
          done
          set -- --config "$config" "$@"
          ;;
      esac
      exec exportarr "$app" "$@"
    '';
  };
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/exportarr";
    copyToRoot = [ wrapper ];
    config.Entrypoint = [ (lib.getExe wrapper) ];
  };
in
{
  inherit image port;
  # The container of the sidecar. `config` is the app's config file on its data volume `data`, mounted at `dataPath`
  container =
    {
      app,
      url,
      dataPath,
      config,
    }:
    {
      image = "${image.buildArgs.name}:${image.imageTag}";
      imagePullPolicy = "Never";
      args = [
        app
        "${dataPath}/${config}"
        "--url=${url}"
        "--port=${toString port}"
        # At info it logs every request of every scrape
        "--log-level=warn"
      ];
      ports = [
        {
          name = "metrics";
          containerPort = port;
        }
      ];
      securityContext = {
        allowPrivilegeEscalation = false;
        readOnlyRootFilesystem = true;
        capabilities.drop = [ "ALL" ];
      };
      volumeMounts.${dataPath} = {
        name = "data";
        readOnly = true;
      };
    };
}
