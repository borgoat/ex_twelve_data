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

          # `beam` gives Erlang, and `elixir` names the Elixir of that set.
          shell =
            beam: elixir:
            pkgs.mkShell {
              packages = [
                beam.erlang
                beam.${elixir}
                # Linters of `mix ci` and the git hooks (lefthook.yml).
                pkgs.typos
                pkgs.actionlint
                pkgs.zizmor
                pkgs.lefthook
              ];

              # Keep Hex/Mix state inside the project instead of $HOME, one Mix home per Elixir:
              # an archive compiled by one release does not load in another.
              shellHook = ''
                export MIX_HOME="$PWD/.nix-mix/${elixir}"
                export HEX_HOME="$PWD/.nix-hex"
                export MIX_ARCHIVES="$MIX_HOME/archives"
                export ERL_AFLAGS="-kernel shell_history enabled"
                mix local.hex --force --if-missing >/dev/null
                mix local.rebar --force --if-missing >/dev/null
                # Not in CI, which runs the whole gate anyway.
                [ -n "''${CI:-}" ] || lefthook install >/dev/null
              '';
            };
        in
        {
          default = shell pkgs.beamPackages "elixir_1_20";
          # The oldest Elixir that mix.exs allows, on the newest OTP it supports: CI runs the tests on it.
          min = shell pkgs.beam.packages.erlang_27 "elixir_1_17";
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
