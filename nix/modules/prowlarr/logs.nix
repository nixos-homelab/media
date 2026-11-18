# How Prowlarr's logs are parsed
{ self, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = self.lib.importsApply [ ../servarr-logs.nix ];
  config = lib.mkIf config.homelab.prowlarr.enable {
    homelab.alloy.logs.pods.prowlarr = {
      format = "servarr";
      examples = [
        {
          lines = [
            "[Info] ReleaseSearchService: Searching indexer(s): [The Pirate Bay] for Term: [], Offset: 0, Limit: 100, Categories: [2000, 2020] "
          ];
          expect = [
            {
              message = "Searching indexer(s): [The Pirate Bay] for Term: [], Offset: 0, Limit: 100, Categories: [2000, 2020]";
              level = "info";
              fields.component = "ReleaseSearchService";
            }
          ];
        }
      ];
    };
  };
}
