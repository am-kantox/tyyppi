# config/.credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      checks: [
        {Credo.Check.Consistency.TabsOrSpaces},
        {Credo.Check.Consistency.SpaceAroundOperators, ignore: [:"::", :*]},
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Refactor.LongQuoteBlocks, max_line_count: 250},
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Design.AliasUsage,
         exit_status: 0, if_called_more_often_than: 1, if_nested_deeper_than: 1, excluded_namespaces: ["String"]},
        {Credo.Check.Design.TagTODO, exit_status: 0},
        {Credo.Check.Design.TagFIXME, exit_status: 0},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 13}
      ]
    }
  ]
}
