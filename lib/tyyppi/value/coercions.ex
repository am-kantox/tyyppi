defmodule Tyyppi.Value.Coercions do
  @moduledoc false

  @spec any(any()) :: Tyyppi.Valuable.either()
  def any(value), do: {:ok, value}

  @spec atom(value :: any()) :: Tyyppi.Valuable.either()
  def atom(atom) when is_atom(atom), do: {:ok, atom}
  def atom(binary) when is_binary(binary), do: {:ok, String.to_atom(binary)}
  def atom(charlist) when is_list(charlist), do: {:ok, :erlang.list_to_atom(charlist)}

  def atom(_not_atom),
    do: {:error, "Expected atom(), charlist() or binary()"}

  @spec string(value :: any()) :: Tyyppi.Valuable.either()
  def string(value) do
    case String.Chars.impl_for(value) do
      nil -> {:error, "protocol String.Chars must be implemented for the target"}
      impl -> {:ok, impl.to_string(value)}
    end
  end

  @spec boolean(value :: any()) :: Tyyppi.Valuable.either()
  def boolean(bool) when is_boolean(bool), do: {:ok, bool}
  def boolean(nil), do: {:ok, false}
  def boolean(_not_nil), do: {:ok, true}

  @spec integer(value :: any()) :: Tyyppi.Valuable.either()
  def integer(i) when is_integer(i), do: {:ok, i}
  def integer(n) when is_number(n), do: {:ok, round(n)}

  def integer(binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {i, ""} -> {:ok, i}
      {i, tail} -> {:error, ~s|Trailing symbols while parsing integer [#{i}]: "#{tail}"|}
      :error -> {:error, ~s|Error parsing integer: "#{binary}"|}
    end
  end

  def integer(_not_integer),
    do: {:error, "Expected number() or binary()"}

  @spec float(value :: any()) :: Tyyppi.Valuable.either()
  def float(n) when is_integer(n), do: {:ok, n / 1}
  def float(n) when is_number(n), do: {:ok, n}

  def float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {f, ""} -> {:ok, f}
      {f, tail} -> {:error, ~s|Trailing symbols while parsing float [#{f}]: "#{tail}"|}
      :error -> {:error, ~s|Error parsing float: "#{binary}"|}
    end
  end

  def float(_not_float),
    do: {:error, "Expected number() or binary()"}

  @spec date(value :: any()) :: Tyyppi.Valuable.either()
  def date(%Date{} = d), do: {:ok, d}

  def date({_, _, _} = value) do
    with {:error, reason} <- Date.from_erl(value),
         do: {:error, "Expected Date() or binary() or erlang date tuple. Reason: [#{reason}]."}
  end

  def date(<<value::binary-size(10), _::binary>>) do
    with {:error, reason} <- Date.from_iso8601(value),
         do: {:error, "Expected Date() or binary() or erlang date tuple. Reason: [#{reason}]."}
  end

  def date(_), do: {:error, "Expected Date() or binary() or erlang date tuple."}

  @spec date_time(value :: any()) :: Tyyppi.Valuable.either()
  def date_time(%DateTime{} = dt), do: {:ok, dt}

  def date_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, reason} ->
        {:error, "Expected DateTime() or binary() or integer(). Reason: [#{reason}]."}
    end
  end

  def date_time(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, dt} ->
        {:ok, dt}

      {:error, reason} ->
        {:error, "Expected DateTime() or binary() or integer(). Reason: [#{reason}]."}
    end
  end

  def date_time(_), do: {:error, "Expected DateTime() or binary() or integer()."}

  @spec timeout(value :: any()) :: Tyyppi.Valuable.either()
  def timeout(:infinity), do: {:ok, :infinity}

  def timeout(value) do
    case integer(value) do
      {:ok, value} -> {:ok, value}
      {:error, _message} -> {:error, "Expected timeout()"}
    end
  end

  @spec pid(value :: any()) :: Tyyppi.Valuable.either()
  def pid(pid) when is_pid(pid), do: {:ok, pid}
  def pid("#PID" <> maybe_pid), do: pid(maybe_pid)
  def pid([_, _, _] = list), do: list |> Enum.join(".") |> pid()
  def pid(value) when is_binary(value), do: value |> to_charlist() |> pid()
  def pid([?< | value]), do: value |> List.delete_at(-1) |> pid()
  def pid(value) when is_list(value), do: {:ok, :erlang.list_to_pid('<#{value}>')}

  def pid(_value), do: {:error, "Expected a value that can be converted to pid()"}

  @spec mfa(value :: any()) :: Tyyppi.Valuable.either()
  def mfa(fun) when is_function(fun) do
    info = Function.info(fun)

    case info[:type] do
      :external -> {:ok, {info[:module], info[:name], info[:arity]}}
      :local -> {:error, "Cannot capture local functions"}
      other -> {:error, "Cannot capture #{other} functions"}
    end
  end

  def mfa({m, f, a}) when is_atom(m) and is_atom(f) and is_integer(a) and a >= 0,
    do: {:ok, {m, f, a}}

  def mfa(_), do: {:error, "Unexpected value for a function"}
end
