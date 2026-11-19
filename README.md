# nixos-homelab-media

A self-hosted media stack on top of [nixos-homelab](https://github.com/nixos-homelab/shared):
Plex plus the usual *Arr suite for automated acquisition, wired together
with API keys and download-client registrations handled automatically.

For the full list of module options, see [the documentation](https://nixos-homelab.github.io/media/), under Options.

## Setup

```nix
{
  inputs = {
    ...
    homelab-media = {
      url = "github:nixos-homelab/media";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ...
  };
}
```

```nix
{ inputs, ... }:
{
  imports = [
    inputs.homelab-media.nixosModules.sonarr
    inputs.homelab-media.nixosModules.radarr
  ];
  config = {
    homelab.sonarr.enable = true;
    homelab.radarr.enable = true;
  };
}
```

## Modules

- **plex**: Plex Media Server.
- **sonarr** / **radarr**: TV and movie collection management.
- **prowlarr**: indexer management, auto-registered with Sonarr/Radarr.
- **flood**: web UI and download client for `rtorrent`, auto-registered
  with Sonarr/Radarr/Prowlarr.
- **rtorrent**: the torrent daemon `flood` drives, optionally routed
  through `homelab-networking`'s `privacy-vpn`.
- **sabnzbd**: Usenet download client, auto-registered the same way as
  `flood`.
- **flaresolverr**: solves Cloudflare challenges for Prowlarr, registered as
  its indexer proxy under the tag `flaresolverr`. Give that tag to the
  indexers behind Cloudflare.

## Metrics

With `homelab-monitoring`'s Alloy enabled, Plex, Sonarr, Radarr, Prowlarr,
SABnzbd and rtorrent get scraped through an exporter in their pod
([exportarr](https://github.com/onedr0p/exportarr) for the *Arrs and SABnzbd,
[prometheus-plex-exporter](https://github.com/jsclayton/prometheus-plex-exporter),
[rtorrent_exporter](https://github.com/thde/rtorrent_exporter)). The exporters
read the API keys and the Plex token from the apps' own data volumes, so there
is nothing to configure. Flood has no exporter.
