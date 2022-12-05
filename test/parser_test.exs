defmodule CliMate.ParserTest do
  use ExUnit.Case, async: true

  defmodule CLI do
    use CliMate
  end

  test "options can be parsed" do
    opts = [options: [doit: [type: :boolean, short: :d]]]
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(~w(--doit), opts)
    assert {:ok, %{options: %{doit: true}}} = CLI.parse(~w(-d), opts)
    assert {:ok, %{options: %{doit: false}}} = CLI.parse(~w(--no-doit), opts)
  end

  test "boolean option always default to false" do
    opts = [options: [doit: [type: :boolean]]]
    assert {:ok, %{options: %{doit: false}}} = CLI.parse([], opts)
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
    CLI.put_shell(CLI.ProcessShell)
    opts = [arguments: [lang: [required: true]]]
    assert {:error, :halted} = CLI.parse_or_halt!([], opts)
    assert_receive {CLI, :halt, 1}
  end
end
