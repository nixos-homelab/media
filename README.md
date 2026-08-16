# nixos-homelab-media

A self-hosted media stack on top of [nixos-homelab](https://github.com/nixos-homelab/shared):
Plex plus the usual *Arr suite for automated acquisition, wired together
with API keys and download-client registrations handled automatically.

For the full list of module options, see [docs/options.md](docs/options.md).

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
