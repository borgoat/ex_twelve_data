# Credo's defaults, plus the opt-in checks that matter for a published library.
%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          # TODO tags are reported without failing the build.
          {Credo.Check.Design.TagTODO, [exit_status: 0]},
          # Every public function is typed: Dialyzer checks the specs, ExDoc publishes them.
          {Credo.Check.Readability.Specs, []},
          # Atoms are never collected: no atoms from data the library does not control.
          {Credo.Check.Warning.UnsafeToAtom, []},
          # A library is compiled into someone else's release, without Mix and without a console.
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Refactor.IoPuts, []}
        ]
      }
    }
  ]
}
