# Root folders, media management and naming of Sonarr or Radarr, set through its API by a job that runs again when
# the settings change. Imported by their default.nix with the app and its port
{ inputs, ... }:
{ app, port }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.${app};
  hllib = inputs.homelab-shared.lib;
  title = lib.toUpper (builtins.substring 0 1 app) + builtins.substring 1 (-1) app;
  apiKeyVar = "${lib.toUpper app}_API_KEY";
  configured = cfg.rootFolders != [ ] || cfg.mediaManagement != { } || cfg.naming != { };
  # GET the section, merge the settings into it, PUT it back: what the settings leave out stays as it is
  mergeSection = section: settings: ''
    current=$(api GET config/${section} | jq -S .)
    merged=$(jq --argjson settings ${lib.escapeShellArg (builtins.toJSON settings)} -S '. * $settings' <<<"$current")
    if [[ $merged = "$current" ]]; then
      echo "${title} ${section} settings unchanged" >&2
    else
      api PUT "config/${section}/$(jq -r .id <<<"$current")" -d "$merged" >/dev/null
      echo "Updated the ${title} ${section} settings" >&2
    fi
  '';
  script = ''
    set -eo pipefail
    api() {
      local method=$1 path=$2
      shift 2
      curl -sfX "$method" "http://${app}.${app}:${toString port}/api/v3/$path" \
        -H 'Content-Type: application/json' \
        -H "X-Api-Key: ''${${apiKeyVar}:?}" "$@"
    }
    ${lib.optionalString (cfg.rootFolders != [ ]) ''
      # Added only: removing a root folder is for the UI
      existing=$(api GET rootfolder)
      for path in ${lib.escapeShellArgs cfg.rootFolders}; do
        if jq -e --arg path "$path" 'any(.[]; (.path | rtrimstr("/")) == ($path | rtrimstr("/")))' <<<"$existing" >/dev/null; then
          echo "${title} has the root folder $path" >&2
        else
          api POST rootfolder -d "$(jq -n --arg path "$path" '{path: $path}')" >/dev/null
          echo "Added the root folder $path to ${title}" >&2
        fi
      done
    ''}
    ${lib.optionalString (cfg.mediaManagement != { }) (
      mergeSection "mediamanagement" cfg.mediaManagement
    )}
    ${lib.optionalString (cfg.naming != { }) (mergeSection "naming" cfg.naming)}
  '';
in
{
  options.homelab.${app} = {
    rootFolders = lib.mkOption {
      description = ''
        Root folders ${title} keeps its media in, as paths in its container (a mount of `volumes`). The job adds the
        missing ones and never removes one.
      '';
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/mnt/media/${if app == "sonarr" then "tvshows" else "movies"}" ];
    };
    mediaManagement = lib.mkOption {
      description = ''
        Media management settings, as the fields of `/api/v3/config/mediamanagement` (`copyUsingHardlinks`,
        `recycleBin`, `importExtraFiles`, ...). Merged into the current settings; those left out stay as they are.
      '';
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        importExtraFiles = true;
        extraFileExtensions = "srt,ass";
      };
    };
    naming = lib.mkOption {
      description = ''
        Naming settings, as the fields of `/api/v3/config/naming` (`${
          if app == "sonarr" then
            "renameEpisodes`, `standardEpisodeFormat"
          else
            "renameMovies`, `standardMovieFormat"
        }`, ...). Merged into the current settings; those left out stay as they are.
      '';
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  config = lib.mkIf (cfg.enable && configured) {
    setup-secrets.destinations = [
      {
        logPrefix = "${title} configuration key";
        requires = [ apiKeyVar ];
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret ${app} ${app}-api-key \
            ${apiKeyVar} "''${${apiKeyVar}:?}"
        '';
      }
    ];
    homelab.kubernetes.submodules.instances.${app}.config.submodules.instances.configure = {
      submodule = "script";
      args = {
        inherit script;
        allowEgress = [ app ];
        container.envFrom = [ { secretRef.name = "${app}-api-key"; } ];
      };
    };
  };
}
