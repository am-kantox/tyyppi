defmodule Tyyppi.Value.Encodings do
  @moduledoc false

  @spec pid(value :: pid(), opts :: keyword()) :: binary()
  def pid(pid, _opts \\ []), do: inspect(:erlang.pid_to_list(pid))
end
