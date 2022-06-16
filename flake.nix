{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };
  outputs = { self, nixpkgs, flake-compat }@inputs:
    let
      systems = nixpkgs.lib.platforms.linux;
      lib = nixpkgs.lib;
      packagePaths = lib.mapAttrs (n: v: "${./packages}/${n}") (lib.filterAttrs (n: v: v == "directory" && (builtins.readDir "${./packages}/${n}") ? "default.nix") (builtins.readDir ./packages));
    in rec {
      packages = lib.genAttrs systems (system: lib.mapAttrs (n:  v: lib.callPackageWith ((lib.recursiveUpdate packages.${system} nixpkgs.legacyPackages.${system}) // { inherit inputs; inherit system; }) v {}) packagePaths);
      legacyPackages = packages;
      overlay = final: prev: (lib.mapAttrs (n: v: prev.callPackage v { }) packagePaths);
      nixosModules = { linuxcnc = import ./modules/linuxcnc.nix; };
    };
}
