# An *arr app's alert rule, from exportarr's metrics: a problem its own health checks report (an indexer down, a root
# folder missing) for 6 hours. Info: it shows in Home's Firing list and notifies no one. `app` is the module, its
# namespace and its scrape job (sonarr, radarr).
#
# UpdateCheck is left out: Nix updates the apps, so "New update is available" says nothing. The apps can't turn it off,
# the update mechanism set to external only skips the checks for the built-in updater: the warning comes whenever the
# build is over 14 days old and the update server has a newer one (src/NzbDrone.Core/HealthCheck/Checks/UpdateCheck.cs,
# lines 92-107 in Radarr v6.4.4.10685, 89-103 in Sonarr v4.0.20.3014)
{ inputs, ... }:
{ app, title }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.${app};
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.${app}.alerts.enable = lib.mkOption {
    description = "Whether Grafana shows ${title}'s health issues as alerts.";
    type = lib.types.bool;
    default =
      cfg.enable
      && cfg.metrics.enable
      && config.homelab.alloy.enable
      && config.homelab.grafana.alerting.enable;
    defaultText = lib.literalExpression ''
      config.homelab.${app}.enable && config.homelab.${app}.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.alerting.enable
    '';
  };
  config = lib.mkIf cfg.alerts.enable {
    homelab.grafana.alerting.groups.${app}.rules.health = g.alert {
      title = "${title} health issue";
      query = ''max by (source, type, message) (${app}_system_health_issues{job="${app}", source!="UpdateCheck"})'';
      above = 0;
      for = "6h";
      severity = "info";
      summary = "${title}: {{ $labels.message }} ({{ $labels.source }})";
      dashboardUid = "media";
    };
  };
}
