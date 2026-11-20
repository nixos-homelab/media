# The flaresolverr module's namespace in the `media` area of the Home dashboard, whose CPU, memory and traffic graphs
# sum the containers by area
{ inputs, ... }:
{ config, lib, ... }:
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  config.homelab.grafana.home.areas.media = {
    color = "#b877d9";
    namespaces = lib.mkIf config.homelab.flaresolverr.enable [ "flaresolverr" ];
  };
}
