defmodule CliMate do
  defmacro __using__(_) do
    cli_mod = __CALLER__.module |> IO.inspect(label: "__CALLER__.module")

    quote bind_quoted: [cli_mod: cli_mod] do
      # Defining the shell.
      #
      # Here we just basically rewrite what mix does, because we do not want to
      # rely on Mix to be started if we build escripts.

      def shell(module) do
        :persistent_term.put({__MODULE__, :shell}, module)
      end

      def shell do
        :persistent_term.get({__MODULE__, :shell}, __MODULE__)
      end

      def error(iodata) do
        shell().print(:stderr, :error, iodata)
      end

      defmodule ProcessShell do
        def cli_mod, do: unquote(cli_mod)

        def print(output \\ :stdio, kind, iodata) do
          send(message_target(), {cli_mod(), kind, format_message(iodata)})
        end

        def format_message(iodata) do
          iodata
          |> IO.ANSI.format(false)
          |> :erlang.iolist_to_binary()
        end

        defp message_target() do
          case Process.get(:"$callers") do
            [parent | _] -> parent
            _ -> self()
          end
        end
      end
    end
  end
end
