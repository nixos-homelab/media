# Radarr's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.radarr;
  rows = import ../arr-grafana.nix { inherit g; } {
    app = "radarr";
    title = "Radarr";
    missing = "radarr_movie_missing_total";
    wanted = "radarr_movie_wanted_total";
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.radarr.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Radarr's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.radarr.enable && config.homelab.radarr.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.home.tiles.radarr = {
      group = "Media";
      order = 401;
      panel = rows.home;
    };
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.radarr = {
        order = 610;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.radarr = {
      workload = "radarr";
      row = rows.drilldown;
    };
  };
}
