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
              case __MODULE__.update(data, [{unquote(key), update_value}]) do
                {:ok, data} ->
                  {get_value, data}

                {:error, reason} ->
                  raise(ArgumentError,
                    message:
                      "could not put/update key :#{unquote(key)} with value #{
                        inspect(update_value)
                      }; reason: validation failed (#{inspect(reason)})"
                  )
              end
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
