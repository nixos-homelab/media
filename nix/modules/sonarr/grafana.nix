# Sonarr's panels on the Media dashboard and Home, and its row on the Workload dashboard
# Its namespace counts toward the `media` area of the Home dashboard, whose CPU, memory and traffic graphs sum the
# containers by area
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.sonarr;
  rows = import ../arr-grafana.nix { inherit g lib; } {
    app = "sonarr";
    title = "Sonarr";
    missing = "sonarr_episode_missing_total";
    downloaded = "sonarr_episode_downloaded_total";
    item = "episodes";
    order = 10;
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.sonarr.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Sonarr's panels and row.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.sonarr.enable && config.homelab.sonarr.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkMerge [
    {
      homelab.grafana.home.areas.media = {
        color = "#b877d9";
        namespaces = lib.mkIf config.homelab.sonarr.enable [ "sonarr" ];
      };
    }
    (lib.mkIf cfg.grafana.enable {
      homelab.grafana.home.graphs.library = rows.home;
      homelab.grafana.overviews.media = {
        title = "Media";
        description = "The media stack: what's missing, downloading, streaming, and the apps' health";
        panels = rows.tiles // rows.panels;
      };
      homelab.grafana.drilldown.rows.sonarr = {
        workload = "sonarr";
        row = rows.drilldown;
      };
    })
  ];
}
