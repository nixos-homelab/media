# An *arr app's alert rule, from exportarr's metrics: a problem its own health checks report (an indexer down, a root
# folder missing) for 6 hours. Info: it shows in Home's Firing list and notifies no one. `app` is the module, its
# namespace and its scrape job (sonarr, radarr)
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
      query = ''max by (source, type, message) (${app}_system_health_issues{job="${app}"})'';
      above = 0;
      for = "6h";
      severity = "info";
      summary = "${title}: {{ $labels.message }} ({{ $labels.source }})";
      dashboardUid = "media";
    };
  };
}
