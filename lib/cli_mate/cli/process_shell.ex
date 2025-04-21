defmodule CliMate.CLI.ProcessShell do
  @tag :cli_mate_shell

  @moduledoc """
  An output shell implementation allowing your CLI commands to send their output
  as messages to themselves. This is most useful for tests.

  The process that will receive the messages is found by looking up the first
  pid in the `:"$callers"` key of the process dictionary, or `self()` if there
  is no caller.

  Use `#{inspect(CliMate.CLI)}.put_shell(#{inspect(__MODULE__)})` to enable this shell.

  This shell is called when calling one of:

  * `#{inspect(CliMate.CLI)}.error/1
  * `#{inspect(CliMate.CLI)}.warn/1
  * `#{inspect(CliMate.CLI)}.debug/1
  * `#{inspect(CliMate.CLI)}.success/1
  * `#{inspect(CliMate.CLI)}.writeln/1
  * `#{inspect(CliMate.CLI)}.halt_success/1
  * `#{inspect(CliMate.CLI)}.halt_error/1
  * `#{inspect(CliMate.CLI)}.halt_error/2

  A message of type `t:shell_message/0` will be sent to `self()`, or the caller
  process for `Task.async/1` and similar task functions.
  """

  @type kind :: :error | :warn | :debug | :info
  @type shell_message :: {unquote(@tag), kind, iodata()}

  @doc false
  def _print(_output, kind, iodata) do
    send(message_target(), build_message(kind, format_message(iodata)))
  end

  @spec build_message(kind, iodata) :: {unquote(@tag), kind, iodata()}
  def build_message(kind, iodata) do
    {@tag, kind, format_message(iodata)}
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
