defmodule Test.Tyyppi.Stats do
  use ExUnit.Case

  alias Tyyppi.{Stats, T}

  doctest Tyyppi.Stats

  setup_all do
    {:ok, pid} = Stats.start_link(callback: &Test.Tyyppi.rehashed/2)
    [stats: pid]
  end

  test "returns types" do
    assert %T{module: String, name: :t, params: [], type: :type} = Stats.type({String, :t})
  end

  test "calls rehashed callback" do
    ast =
      quote do
        use Boundary
        @type t :: any()
      end

    case Code.ensure_compiled(T1) do
      {:module, T1} ->
        :ok

      _ ->
        {:module, mod, beam, _} = Module.create(T1, ast, Macro.Env.location(__ENV__))

        with path when not is_nil(path) <- System.tmp_dir() do
          Mix.Project.app_path()
          |> Path.join("ebin")
          |> Path.join(to_string(mod) <> ".beam")
          |> File.write(beam)
        end

        Stats.rehash!()
    end

    assert %T{module: T1, name: :t, params: []} = Stats.type({T1, :t})

    :code.purge(T1)
    :code.delete(T1)
  end
end
