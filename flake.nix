{
  description = "SJMCL - SJMC Minecraft launcher, packaged from the upstream Linux portable build";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (system: {
        sjmcl = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = self.packages.${system}.sjmcl;
      });

      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/SJMCL";
          meta.description = "Launch SJMCL";
        };
      });

      overlays.default = final: _prev: {
        sjmcl = final.callPackage ./package.nix { };
      };
    };
}
