defmodule CliMateTest do
  use ExUnit.Case, async: true

  defmodule CLI do
    use CliMate
  end

  setup do
    CLI.put_shell(CLI.ProcessShell)
    :ok
  end

  @command [
    options: [
      gen_server: [
        type: :boolean,
        short: :g,
        doc: "bla bla bla",
        default: false
      ],
      supervisor: [
        type: :boolean,
        short: :s,
        doc: "bla bla bla",
        default: false
      ]
    ],
    arguments: [
      module: [
        required: true,
        cast: {Module, :concat, [[:"$1"]]}
      ]
    ]
  ]

  test "the shell can be set" do
    CLI.error("this is an error")
    assert_receive {CLI, :error, "this is an error"}

    CLI.debug("this is a debug message")
    assert_receive {CLI, :debug, "this is a debug message"}
  end

  test "the default shell will not emit messages" do
    CLI.put_shell(CLI)

    CLI.error("this is an error")
    refute_receive {CLI, :error, "this is an error"}

    CLI.debug("this is a debug message")
    refute_receive {CLI, :debug, "this is a debug message"}
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

  test "a command can have arguments optional arguments" do
    opts = [arguments: [lang: []]]
    assert {:ok, %{arguments: %{lang: "elixir"}}} = CLI.parse(~w(elixir), opts)
    assert {:ok, %{arguments: args}} = CLI.parse([], opts)
    assert 0 = map_size(args)
  end

  test "arguments can be required" do
    opts = [arguments: [lang: [required: true]]]
    assert {:ok, %{arguments: %{lang: "erlang"}}} = CLI.parse(~w(erlang), opts)

    opts = [arguments: [lang: [required: true]]]
    assert {:error, {:argument_missing, :lang}} = CLI.parse([], opts)
  end

  test "extra arguments are an error" do
    opts = [arguments: [lang: [required: true]]]
    assert {:error, {:extra_argument, "elixir"}} = CLI.parse(~w(erlang elixir), opts)
  end
end
