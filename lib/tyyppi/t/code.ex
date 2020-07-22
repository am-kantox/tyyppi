defmodule Tyyppi.Code do
  @moduledoc false

  @spec module!(module(), Macro.t()) ::
          :ok | {:error, :embedded | :badfile | :nofile | :on_load_failure | :unavailable}
  case Code.ensure_compiled(Mix) do
    {:module, Mix} ->
      def module!(module, ast) do
        case Code.ensure_compiled(module) do
          {:module, ^module} ->
            {:module, module}

          _ ->
            {:module, module, beam, _} = Module.create(module, ast, Macro.Env.location(__ENV__))

            Mix.Project.app_path()
            |> Path.join("ebin")
            |> Path.join(to_string(module) <> ".beam")
            |> File.write(beam)

            Tyyppi.Stats.rehash!()
        end
      end

    error ->
      def module!(_module, _ast), do: unquote(error)
  end
end
