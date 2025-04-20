defmodule CliMate.CLI.ShellTest do
  alias CliMate.CLI
  alias CliMate.CLI.ProcessShell
  use ExUnit.Case, async: false

  setup do
    CLI.put_shell(ProcessShell)
    :ok
  end

  test "the shell can be set" do
    CLI.error("this is an error")
    assert_receive {:cli_mate_shell, :error, "this is an error"}

    CLI.debug("this is a debug message")
    assert_receive {:cli_mate_shell, :debug, "this is a debug message"}

    CLI.warn("this is a warning")
    assert_receive {:cli_mate_shell, :warn, "this is a warning"}

    CLI.writeln("this is a normal message")
    assert_receive {:cli_mate_shell, :info, "this is a normal message"}
  end

  test "the default shell will not emit messages" do
    CLI.put_shell(CLI)
    assert CLI = CLI.shell()

    stderr =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        CLI.error("this is an error")
        refute_receive {:cli_mate_shell, :error, "this is an error"}

        CLI.warn("this is a warning")
        refute_receive {:cli_mate_shell, :warn, "this is a warning"}
      end)

    stdout =
      ExUnit.CaptureIO.capture_io(fn ->
        CLI.debug("this is a debug message")
        refute_receive {:cli_mate_shell, :debug, "this is a debug message"}

        CLI.writeln("this is a normal message")
        refute_receive {:cli_mate_shell, :info, "this is a normal message"}
      end)

    assert stderr =~ "this is an error"
    assert stderr =~ "this is a warning"
    assert stdout =~ "this is a debug message"
    assert stdout =~ "this is a normal message"
  end

  test "the shell can abort" do
    CLI.halt(0)
    assert_receive {:cli_mate_shell, :halt, 0}

    CLI.halt_success("It worked!")
    assert_receive {:cli_mate_shell, :info, "It worked!"}
    assert_receive {:cli_mate_shell, :halt, 0}

    CLI.halt_error("Actually, no…")
    assert_receive {:cli_mate_shell, :error, "Actually, no…"}
    assert_receive {:cli_mate_shell, :halt, 1}

    CLI.halt_error(250, "Failing, again")
    assert_receive {:cli_mate_shell, :error, "Failing, again"}
    assert_receive {:cli_mate_shell, :halt, 250}
  end
end
