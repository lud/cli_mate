defmodule CliMate.ParserTest do
  use ExUnit.Case, async: true
  alias CliMate.CLI

  setup do
    CLI.put_shell(CLI.ProcessShell)
    :ok
  end

  test "options can be parsed" do
    opts = [options: [doit: [type: :boolean, short: :d]]]
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(~w(--doit), opts)
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(~w(-d), opts)
    assert {:ok, %{options: %{doit: false}}} = CLI.parse(~w(--no-doit), opts)
  end

  test "options can have default values" do
    opts = [options: [msg: [short: :m, default: "byebye"]]]
    assert {:ok, %{options: %{msg: "hello"}}} = CLI.parse(~w(--msg hello), opts)
    assert {:ok, %{options: %{msg: "hello"}}} = CLI.parse(~w(-m hello), opts)
    assert {:ok, %{options: %{msg: "byebye"}}} = CLI.parse([], opts)
  end

  test "unknown options generate errors" do
    assert {:error, {:invalid, [{"--msg", _}]}} = CLI.parse(~w(--msg hello), [])
  end

  test "boolean option can be missing" do
    opts = [options: [doit: [type: :boolean]]]
    assert {:ok, %{options: %{help: false}, arguments: %{}}} == CLI.parse([], opts)
  end

  test "boolean option can default to false" do
    opts = [options: [doit: [type: :boolean, default: false]]]
    assert {:ok, %{options: %{doit: false}}} = CLI.parse([], opts)
    assert {:ok, %{options: %{doit: false}}} = CLI.parse(["--no-doit"], opts)
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(["--doit"], opts)
  end

  test "boolean option can default to true" do
    opts = [options: [doit: [type: :boolean, default: true]]]
    assert {:ok, %{options: %{doit: true}}} = CLI.parse([], opts)
    assert {:ok, %{options: %{doit: false}}} = CLI.parse(["--no-doit"], opts)
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(["--doit"], opts)
  end

  test "integer option should be enforced" do
    opts = [options: [num: [type: :integer]]]
    assert {:ok, %{options: %{num: 2}}} = CLI.parse(~w(--num 2), opts)
    assert {:error, {:invalid, [{"--num", _}]}} = CLI.parse(~w(--num bad), opts)
  end

  test "a command can have arguments optional arguments" do
    opts = [arguments: [lang: [required: false]]]
    assert {:ok, %{arguments: %{lang: "elixir"}}} = CLI.parse(~w(elixir), opts)
    assert {:ok, %{arguments: args}} = CLI.parse([], opts)
    assert 0 = map_size(args)
  end

  test "arguments can be required" do
    opts = [arguments: [lang: [required: true]]]
    assert {:ok, %{arguments: %{lang: "erlang"}}} = CLI.parse(~w(erlang), opts)

    opts = [arguments: [lang: [required: true]]]
    assert {:error, {:missing_argument, :lang}} = CLI.parse([], opts)
  end

  test "arguments are required by default" do
    opts = [arguments: [lang: []]]
    assert {:error, {:missing_argument, :lang}} = CLI.parse([], opts)
  end

  test "extra arguments are an error" do
    opts = [arguments: [lang: [required: true]]]
    assert {:error, {:extra_argument, "elixir"}} = CLI.parse(~w(erlang elixir), opts)
  end

  test "the parse_or_halt! shortcut words" do
    opts = [arguments: [lang: [required: true]]]
    assert :halt = CLI.parse_or_halt!([], opts)
    assert_receive {CLI, :halt, 1}
  end

  test "the --help option is always defined" do
    assert {:ok, %{options: %{help: false}}} = CLI.parse(~w(), [])
    assert {:ok, %{options: %{help: true}}} = CLI.parse(~w(--help), [])
  end

  test "the --help option will halt(0) with parse_or_halt!" do
    assert :halt = CLI.parse_or_halt!(~w(--help), [])
    {_, _, text} = assert_receive {CLI, :info, _text}
    assert text =~ "Usage"
    assert_receive {CLI, :halt, 0}
  end

  test "the --help option ignore parsing of arguments" do
    assert :halt = CLI.parse_or_halt!(~w(--help), arguments: [some_arg: []])
    {_, _, text} = assert_receive {CLI, :info, _text}
    assert text =~ "Usage"
    assert_receive {CLI, :halt, 0}
  end

  test "the --help option cannot be overriden" do
    assert {:error, {:invalid, _}} = CLI.parse(~w(--help), options: [help: [type: :integer]])
  end

  test "the arguments can be casted" do
    opts = [arguments: [one: [cast: fn v -> {:ok, String.to_integer(v) + 1} end]]]
    assert {:ok, %{arguments: %{one: 2}}} = CLI.parse(~w(1), opts)

    opts = [arguments: [one: [cast: {__MODULE__, :cast_add_int, []}]]]
    assert {:ok, %{arguments: %{one: 2}}} = CLI.parse(~w(1), opts)

    opts = [arguments: [one: [cast: {__MODULE__, :cast_add_int, [10]}]]]
    assert {:ok, %{arguments: %{one: 11}}} = CLI.parse(~w(1), opts)
  end

  def cast_add_int(v, add \\ 1) do
    {:ok, String.to_integer(v) + add}
  end

  test "default values can be provided by anonymous functions" do
    opts = [options: [msg: [short: :m, default: fn -> "hello" end]]]
    assert {:ok, %{options: %{msg: "hello"}}} = CLI.parse([], opts)
  end

  defp my_default_port, do: 4000

  test "default values can be provided by function refs" do
    opts = [options: [port: [short: :p, default: &my_default_port/0]]]
    assert {:ok, %{options: %{port: 4000}}} = CLI.parse([], opts)
  end

  test "default values can be provided by fn/1" do
    provider = fn
      :port -> 4000
      :scheme -> "http"
    end

    opts = [options: [port: [default: provider], scheme: [default: provider]]]

    assert {:ok, %{options: %{port: 4000, scheme: "http"}}} = CLI.parse([], opts)
  end

  defp my_default_opt(:port), do: 3000
  defp my_default_opt(:scheme), do: "https"

  test "default values can be provided by &f/1" do
    opts = [options: [port: [default: &my_default_opt/1], scheme: [default: &my_default_opt/1]]]

    assert {:ok, %{options: %{port: 3000, scheme: "https"}}} = CLI.parse([], opts)
  end
end
