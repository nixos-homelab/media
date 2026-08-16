{
  description = "NixOS Homelab Media Workloads";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    kube-generators.url = "github:farcaller/nix-kube-generators";
    docs.url = "github:andsens/nix-docs";
    kubetree = {
      url = "github:andsens/nix-kubetree";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    setup-secrets = {
      url = "github:andsens/nixos-setup-secrets";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    homelab-shared = {
      url = "github:nixos-homelab/shared";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kubetree.follows = "kubetree";
      inputs.kube-generators.follows = "kube-generators";
    };
    homelab-networking = {
      url = "github:nixos-homelab/networking";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kubetree.follows = "kubetree";
      inputs.kube-generators.follows = "kube-generators";
    };
  };
  outputs =
    {
      systems,
      flake-parts,
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        self,
        inputs,
        lib,
        ...
      }:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        systems = import systems;
        flake = {
          lib = {
            importsApply = map (path: importApply path { inherit self inputs; });
            integration = import ./nix/lib/integration.nix { inherit lib inputs; };
          };
          nixosModules = {
            flood = importApply ./nix/modules/flood { inherit self inputs; };
            plex = importApply ./nix/modules/plex { inherit self inputs; };
            prowlarr = importApply ./nix/modules/prowlarr { inherit self inputs; };
            radarr = importApply ./nix/modules/radarr { inherit self inputs; };
            rtorrent = importApply ./nix/modules/rtorrent { inherit self inputs; };
            sabnzbd = importApply ./nix/modules/sabnzbd { inherit self inputs; };
            sonarr = importApply ./nix/modules/sonarr { inherit self inputs; };
          };
        };
        perSystem =
          { pkgs, system, ... }:
          let
            lib-docs = inputs.docs.lib.docs.lib {
              inherit pkgs;
              paths.lib = ./nix/lib;
            };
            options-docs = inputs.docs.lib.docs.options {
              inherit pkgs;
              modules = lib.attrValues self.nixosModules;
              repoPath = toString self;
              repoLinkPrefix = "https://github.com/nixos-homelab/media/blob/main";
            };
          in
          {
            apps.update-docs.program = inputs.docs.lib.docs.updateRepo {
              inherit pkgs;
              paths."docs/lib" = "${lib-docs}/lib";
              paths."docs/options.md" = options-docs.optionsCommonMark;
            };
            packages = {
              lib-docs = lib-docs;
              options-docs = options-docs.optionsCommonMark;
            };
          };
      }
    );
}
