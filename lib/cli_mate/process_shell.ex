defmodule CliMate.ProcessShell do
  @tag :cli_mate_shell

  @moduledoc """
  An output shell implementation allowing your CLI commands to send their
  output as messages to themselves. This is most useful for tests.

  The process that will receive the messages is found by looking up the first
  pid in the `:"$callers"` key of the process dictionary, or `self()` if there
  is no caller.

  Use `CliMate.put_shell(#{inspect(__MODULE__)})` to enable this shell.
  """

  IO.warn("@todo document that process shell will always tag messages with CliMate.CLI")

  @doc false
  def _print(_output, kind, iodata) do
    send(message_target(), {@tag, kind, format_message(iodata)})
  end

  defp format_message(iodata) do
    iodata
    |> IO.ANSI.format(false)
    |> :erlang.iolist_to_binary()
  end

  @doc """
  Returns the pid of the process that will receive output messages.
  """
  def message_target do
    case Process.get(:"$callers") do
      [parent | _] -> parent
      _ -> self()
    end
  end

  def _halt(n) do
    send(message_target(), {@tag, :halt, n})
  end
end
