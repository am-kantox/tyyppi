global_settings = "~/.iex.exs"
if File.exists?(global_settings), do: Code.require_file(global_settings)

Application.put_env(:elixir, :ansi_enabled, true)

IEx.configure(
  inspect: [limit: :infinity, charlists: :as_lists],
  colors: [
    eval_result: [:cyan, :bright],
    eval_error: [[:red, :bright, "\n▶▶▶\n"]],
    eval_info: [:yellow, :bright],
    syntax_colors: [
      number: :red,
      atom: :blue,
      string: :green,
      boolean: :magenta,
      nil: :magenta,
      list: :white
    ]
  ],
  default_prompt:
    [
      # cursor ⇒ column 1
      "\e[G",
      :blue,
      "%prefix",
      :red,
      "|tyyppi|",
      :blue,
      "%counter",
      " ",
      :yellow,
      "▶",
      :reset
    ]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
)

unless match?({:module, _}, Code.ensure_compiled(Tyyppi)),
  do: IO.puts("\n✗ Tyyppi features are not set. Run `iex -S mix` to enable.")

use Tyyppi
