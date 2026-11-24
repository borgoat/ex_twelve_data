# Credo's defaults, but TODO tags are reported without failing the build.
%{
  configs: [
    %{
      name: "default",
      checks: %{extra: [{Credo.Check.Design.TagTODO, [exit_status: 0]}]}
    }
  ]
}
