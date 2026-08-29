{ inputs, self, ... }:
{
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.flood;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.flood = {
    enable = lib.mkOption {
      description = "integration of flood with homepage";
      type = lib.types.bool;
      default = config.homelab.flood.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.flood.enable && config.homelab.homepage.enable";
    };
  };
  imports = [
    inputs.homelab-shared.nixosModules.homepage
    self.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    homelab.homepage = {
      sections.Media.enable = lib.mkDefault true;
      services.Media.Flood = {
        enable = lib.mkDefault true;
        icon = "flood.png";
        description = "rTorrent WebUI";
        href = "https://flood.${ccfg.domain}";
        widgets = [
          {
            type = "flood";
            url = hllib.workload-macros.workloadServiceUrl config.kubetree.resources.flood.workload;
            # Prevent issue where an empty body in the login API call causes an error
            username = " ";
            password = " ";
          }
        ];
      };
      allowEgress = [ "flood" ];
    };
  };
}
