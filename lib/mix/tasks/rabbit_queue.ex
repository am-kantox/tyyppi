if match?({:module, AMQP.Channel}, Code.ensure_compiled(AMQP.Channel)) do
  defmodule Mix.Tasks.Rambla.Rabbit.Queue do
    @shortdoc "Operations with queues in RabbitMQ"
    @moduledoc since: "0.6.0"
    @moduledoc """
    Mix task to deal with queues in the target RabbitMQ.

    This is helpful to orchestrate target RabbitMQ when deploying
    to docker. Allows to create, delete, purge and query status of
    the queue. Also, `bind` and `unbind` commands are supported,
    both require `exchange:...` option to be passed.

    Loads the setting from `config :rambla, :amqp` if no connection
    is provided in parameters.

    ## Command line options
      * -c - the connection string
      * -o - the list of options without spaces, separated by comma

    ## Options

    ### Options for `create`
      * `durable` - If set, keeps the Queue between restarts
        of the broker. Defaults to false.
      * `auto_delete` - If set, deletes the Queue once all
        subscribers disconnect. Defaults to false.
      * `exclusive` - If set, only one subscriber can consume
        from the Queue. Defaults to false.
      * `passive` - If set, raises an error unless the queue
        already exists. Defaults to false.
      * `no_wait` - If set, the declare operation is asynchronous.
        Defaults to false.
      * `arguments` - A list of arguments to pass when declaring
        (of type AMQP.arguments/0). See the README for more information. Defaults to [].

    ### Options for `delete`

      * `if_unused` - If set, the server will only delete the queue
        if it has no consumers. If the queue has consumers, it’s
        not deleted and an error is returned.
      * `if_empty` - If set, the server will only delete the queue
        if it has no messages.
      * `no_wait` - If set, the delete operation is asynchronous.

    """

    @commands ~w|declare create delete purge bind unbind status|
    @type command :: :declare | :create | :delete | :purge | :bind | :unbind | :status

    use Mix.Task
    use Rambla.Tasks.Utils

    @spec do_command(
            chan :: AMQP.Channel.t(),
            command :: command(),
            name :: binary(),
            opts :: keyword()
          ) :: {:ok, any()} | {:error, any()}
    defp do_command(chan, :create, name, opts),
      do: do_command(chan, :declare, name, opts)

    defp do_command(chan, command, name, opts) do
      AMQP.Queue.__info__(:functions)
      |> Keyword.get_values(command)
      |> :lists.reverse()
      |> case do
        [4 | _] ->
          case Keyword.pop(opts, :exchange) do
            {nil, _} ->
              {:error, {:exchange_option_required, command}}

            {exchange, opts} ->
              {:ok, apply(AMQP.Queue, command, [chan, name, to_string(exchange), opts])}
          end

        [3 | _] ->
          {:ok, apply(AMQP.Queue, command, [chan, name, opts])}

        [2 | _] ->
          {:ok, apply(AMQP.Queue, command, [chan, name])}

        _other ->
          {:error, {:unknown_command, command}}
      end
    end
  end
end
