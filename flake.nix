{
  description = "Elixir client for Twelve Data";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.beamPackages.erlang
              pkgs.beamPackages.elixir_1_20
            ];

            # Keep Hex/Mix state inside the project instead of $HOME.
            shellHook = ''
              export MIX_HOME="$PWD/.nix-mix"
              export HEX_HOME="$PWD/.nix-hex"
              export MIX_ARCHIVES="$MIX_HOME/archives"
              export ERL_AFLAGS="-kernel shell_history enabled"
              mix local.hex --force --if-missing >/dev/null
              mix local.rebar --force --if-missing >/dev/null
            '';
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
