defmodule Mix.Tasks.Tyyppi.Dump do
  @shortdoc "Dumps the types to the file to be used in runtime"
  @moduledoc since: "0.10.0"
  @moduledoc """
  Mix task to dump the content of the `Tyyppi.Stats` to disk.

  ## Command line options
    * `-t` - the type pf the storage, `dets` or `process`; default is `ets`
    * `-f` - the name of the file to dump to; default is `tyyppi.dets`

  If the types are stored as `-t process`, the application using it must start
  the `Tyyppi.Stats` process with `Tyyppi.Stats.load/3` specifying `:process` as
  the first parameter.

  For `-t ets` (default,) `Tyyppi.Stats.load(:ets, file)` should have been called.
  """

  use Mix.Task
  use Boundary, deps: [Tyyppi]
  alias Tyyppi.Stats

  @switches [
    type: :string,
    file: :string
  ]
  @aliases for {k, _} <- @switches,
               do: {k |> to_string |> String.at(0) |> String.to_atom(), k}

  @impl Mix.Task
  @doc false
  def run(args) do
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, strict: @switches)

    type = Keyword.get(opts, :type, "ets")
    file = Keyword.get(opts, :file, "tyyppi.dets")

    Mix.shell().info("Storing the types as #{type} into #{file}")

    case type do
      "process" ->
        case Stats.start_link() do
          {:ok, pid} ->
            Stats.dump(file)
            GenServer.stop(pid)

          error ->
            Mix.raise("Cannot start a process, response: #{inspect(error)}.")
        end

      "ets" ->
        Stats.dump(file)

      other ->
        Mix.raise("Unknown storage type #{other}, expected `ets` or `process`.")
    end

    __MODULE__
    |> Mix.Task.task_name()
    |> Mix.Task.reenable()
  end
end
