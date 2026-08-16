## homelab\.flood\.enable



Whether to enable flood\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/flood/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/default.nix)



## homelab\.flood\.debug

Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/flood/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/default.nix)



## homelab\.flood\.integrations\.prowlarr\.enable



Whether to integrate Flood with Prowlarr



*Type:*
boolean



*Default:*
` config.homelab.flood.enable && config.homelab.prowlarr.enable `

*Declared by:*
 - [nix/modules/flood/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/integration.nix)



## homelab\.flood\.integrations\.radarr\.enable



Whether to integrate Flood with Radarr



*Type:*
boolean



*Default:*
` config.homelab.flood.enable && config.homelab.radarr.enable `

*Declared by:*
 - [nix/modules/flood/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/integration.nix)



## homelab\.flood\.integrations\.sonarr\.enable



Whether to integrate Flood with Sonarr



*Type:*
boolean



*Default:*
` config.homelab.flood.enable && config.homelab.sonarr.enable `

*Declared by:*
 - [nix/modules/flood/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/integration.nix)



## homelab\.homepage\.integrations\.flood\.enable



integration of flood with homepage



*Type:*
boolean



*Default:*
` config.homelab.flood.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/flood/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/flood/homepage.nix)



## homelab\.homepage\.integrations\.plex\.enable



integration of Plex with homepage



*Type:*
boolean



*Default:*
` config.homelab.plex.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/plex/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/homepage.nix)



## homelab\.homepage\.integrations\.prowlarr\.enable



Whether to integrate Prowlarr with homepage



*Type:*
boolean



*Default:*
` config.homelab.prowlarr.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/prowlarr/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/prowlarr/homepage.nix)



## homelab\.homepage\.integrations\.radarr\.enable



integration of radarr with homepage



*Type:*
boolean



*Default:*
` config.homelab.radarr.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/radarr/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/radarr/homepage.nix)



## homelab\.homepage\.integrations\.sabnzbd\.enable



integration of sabnzbd with homepage



*Type:*
boolean



*Default:*
` config.homelab.sabnzbd.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/sabnzbd/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/homepage.nix)



## homelab\.homepage\.integrations\.sonarr\.enable



integration of sonarr with homepage



*Type:*
boolean



*Default:*
` config.homelab.sonarr.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/sonarr/homepage\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sonarr/homepage.nix)



## homelab\.plex\.enable



Whether to enable Plex Media Server\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/plex/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/default.nix)



## homelab\.plex\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/plex/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/default.nix)



## homelab\.plex\.integrations\.radarr\.enable



Whether to integrate Plex with Radarr



*Type:*
boolean



*Default:*
` config.homelab.plex.enable && config.homelab.radarr.enable `

*Declared by:*
 - [nix/modules/plex/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/integration.nix)



## homelab\.plex\.integrations\.sonarr\.enable



Whether to integrate Plex with Sonarr



*Type:*
boolean



*Default:*
` config.homelab.plex.enable && config.homelab.sonarr.enable `

*Declared by:*
 - [nix/modules/plex/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/integration.nix)



## homelab\.plex\.reservedIPs



Reserved IPs for the Plex loadbalancer



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [nix/modules/plex/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/default.nix)



## homelab\.plex\.volumes



Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec)\.



*Type:*
attribute set of anything



*Default:*
` { } `

*Declared by:*
 - [nix/modules/plex/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/plex/default.nix)



## homelab\.prowlarr\.enable



Whether to enable prowlarr\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/prowlarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/prowlarr/default.nix)



## homelab\.prowlarr\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/prowlarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/prowlarr/default.nix)



## homelab\.prowlarr\.integrations\.radarr\.enable



Whether to integrate Prowlarr with Radarr



*Type:*
boolean



*Default:*
` config.homelab.prowlarr.enable && config.homelab.radarr.enable `

*Declared by:*
 - [nix/modules/prowlarr/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/prowlarr/integration.nix)



## homelab\.prowlarr\.integrations\.sonarr\.enable



Whether to integrate Prowlarr with Sonarr



*Type:*
boolean



*Default:*
` config.homelab.prowlarr.enable && config.homelab.sonarr.enable `

*Declared by:*
 - [nix/modules/prowlarr/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/prowlarr/integration.nix)



## homelab\.radarr\.enable



Whether to enable radarr\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/radarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/radarr/default.nix)



## homelab\.radarr\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/radarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/radarr/default.nix)



## homelab\.radarr\.volumes



Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec)\. rtorrent \& usenet download volumes are added automatically\.



*Type:*
attribute set of anything



*Default:*
` { } `

*Declared by:*
 - [nix/modules/radarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/radarr/default.nix)



## homelab\.rtorrent\.enable



Whether to enable rtorrent\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/rtorrent/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/rtorrent/default.nix)



## homelab\.rtorrent\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/rtorrent/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/rtorrent/default.nix)



## homelab\.rtorrent\.downloadsVolume



Volume source (as specificed on the pod spec) to place downloads in



*Type:*
attribute set of anything

*Declared by:*
 - [nix/modules/rtorrent/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/rtorrent/default.nix)



## homelab\.sabnzbd\.enable



Whether to enable sabnzbd\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/sabnzbd/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/default.nix)



## homelab\.sabnzbd\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/sabnzbd/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/default.nix)



## homelab\.sabnzbd\.downloadsVolume



Volume source (as specificed on the pod spec) to place downloads in



*Type:*
attribute set of anything

*Declared by:*
 - [nix/modules/sabnzbd/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/default.nix)



## homelab\.sabnzbd\.integrations\.prowlarr\.enable



Whether to integrate SABNzbd with Prowlarr



*Type:*
boolean



*Default:*
` config.homelab.sabnzbd.enable && config.homelab.sonarr.enable `

*Declared by:*
 - [nix/modules/sabnzbd/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/integration.nix)



## homelab\.sabnzbd\.integrations\.radarr\.enable



Whether to integrate SABNzbd with Radarr



*Type:*
boolean



*Default:*
` config.homelab.sabnzbd.enable && config.homelab.radarr.enable `

*Declared by:*
 - [nix/modules/sabnzbd/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/integration.nix)



## homelab\.sabnzbd\.integrations\.sonarr\.enable



Whether to integrate SABNzbd with Sonarr



*Type:*
boolean



*Default:*
` config.homelab.sabnzbd.enable && config.homelab.sonarr.enable `

*Declared by:*
 - [nix/modules/sabnzbd/integration\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sabnzbd/integration.nix)



## homelab\.sonarr\.enable



Whether to enable sonarr\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/sonarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sonarr/default.nix)



## homelab\.sonarr\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/sonarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sonarr/default.nix)



## homelab\.sonarr\.mountPaths



Paths from the host to mirror into the container



*Type:*
list of absolute path



*Default:*
` [ ] `

*Declared by:*
 - [nix/modules/sonarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sonarr/default.nix)



## homelab\.sonarr\.volumes



Volumes to mount into the container expressed as a map of mountpath to volume source (as specificed on the pod spec)\. rtorrent \& usenet download volumes are added automatically\.



*Type:*
attribute set of anything



*Default:*
` { } `

*Declared by:*
 - [nix/modules/sonarr/default\.nix](https://github.com/nixos-homelab/media/blob/main/nix/modules/sonarr/default.nix)


