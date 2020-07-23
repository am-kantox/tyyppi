defmodule Tyyppi.Access do
  @moduledoc false

  defmacro __using__(fields) do
    quote bind_quoted: [fields: fields] do
      @behaviour Elixir.Access

      Enum.each(fields, fn key ->
        @impl Elixir.Access
        def fetch(%__MODULE__{unquote(key) => value}, unquote(key)),
          do: {:ok, value}

        @impl Elixir.Access
        def pop(%__MODULE__{unquote(key) => value} = data, unquote(key)),
          do: {value, data}

        @impl Elixir.Access
        def get_and_update(%type{unquote(key) => value} = data, unquote(key), fun) do
          case fun.(value) do
            :pop ->
              pop(data, unquote(key))

            {get_value, update_value} ->
              {get_value, Tyyppi.Struct.put!(data, unquote(key), update_value)}
          end
        end
      end)

      @impl Elixir.Access
      def fetch(%__MODULE__{}, _), do: :error

      @impl Elixir.Access
      def pop(%__MODULE__{} = data, key),
        do: raise(BadStructError, struct: __MODULE__, term: key)

      @impl Elixir.Access
      def get_and_update(%_{} = data, key, _),
        do: raise(BadStructError, struct: __MODULE__, term: key)
    end
  end
end
