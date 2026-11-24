{
  description = "Homelab NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    pkgs = import nixpkgs {
      inherit system;

      config.allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "minecraft-server"
        ];
    };

    unstable = import nixpkgs-unstable {
      inherit system;
    };

    nixosConfiguration = lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit unstable;
      };

      modules = [
        ./hosts/homelab
        sops-nix.nixosModules.sops
      ];
    };

    syntheticConfiguration = lib.nixosSystem {
      inherit system;

      modules = [
        ./hosts/synthetic
      ];
    };
  in
  {
    nixosConfigurations = {
      homelab = nixosConfiguration;
      synthetic = syntheticConfiguration;
    };

    checks.${system}.configuration =
      import ./tests/configuration.nix {
        inherit pkgs lib unstable;
        config = nixosConfiguration.config;
      };

    checks.${system}.multi-host =
      import ./tests/multi-host.nix {
        inherit pkgs lib;
        homelab = nixosConfiguration;
        synthetic = syntheticConfiguration;
      };
  };
}
