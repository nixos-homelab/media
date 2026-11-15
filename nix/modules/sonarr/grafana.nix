# Sonarr's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.sonarr;
  rows = import ../arr-grafana.nix { inherit g; } {
    app = "sonarr";
    title = "Sonarr";
    missing = "sonarr_episode_missing_total";
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.sonarr.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Sonarr's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.sonarr.enable && config.homelab.sonarr.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.sonarr = {
        order = 600;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.sonarr = {
      workload = "sonarr";
      row = rows.drilldown;
    };
  };
}
