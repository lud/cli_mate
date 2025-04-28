defmodule CliMate.CLI.ParserTest do
  alias CliMate.CLI
  alias CliMate.CLI.ProcessShell
  use ExUnit.Case, async: true

  setup do
    CLI.put_shell(ProcessShell)
    :ok
  end

  describe "options" do
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

    test "last flag wins when duplicate options are provided" do
      opts = [options: [name: [short: :n]]]
      assert {:ok, %{options: %{name: "one"}}} = CLI.parse(~w(--name one), opts)
      assert {:ok, %{options: %{name: "two"}}} = CLI.parse(~w(--name one -n two), opts)

      assert {:ok, %{options: %{name: "three"}}} =
               CLI.parse(~w(--name one -n two --name three), opts)

      assert {:ok, %{options: %{name: "four"}}} =
               CLI.parse(~w(--name one -n two --name three -n four), opts)

      # With the :keep flag
      opts = [options: [name: [short: :n, keep: true]]]

      assert {:ok, %{options: %{name: ["one"]}}} = CLI.parse(~w(--name one), opts)

      assert {:ok, %{options: %{name: ["one", "two", "three", "four"]}}} =
               CLI.parse(~w(--name one -n two --name three -n four), opts)
    end
  end

  describe "the --help option" do
    test "is always defined" do
      assert {:ok, %{options: %{help: false}}} = CLI.parse(~w(), [])
      assert {:ok, %{options: %{help: true}}} = CLI.parse(~w(--help), [])
    end

    test "will halt(0) with parse_or_halt!" do
      assert :halt = CLI.parse_or_halt!(~w(--help), [])
      {_, _, text} = assert_receive {:cli_mate_shell, :info, _text}
      assert text =~ "Synopsis"
      assert_receive {:cli_mate_shell, :halt, 0}
    end

    test "ignore parsing of arguments" do
      assert :halt = CLI.parse_or_halt!(~w(--help), arguments: [some_arg: []])
      {_, _, text} = assert_receive {:cli_mate_shell, :info, _text}
      assert text =~ "Synopsis"
      assert_receive {:cli_mate_shell, :halt, 0}
    end

    test "cannot be overriden" do
      assert_raise ArgumentError, "the :help option cannot be overriden", fn ->
        CLI.parse(~w(--help 123), options: [help: [type: :integer]])
      end
    end
  end

  describe "arguments" do
    test "arguments are required by default" do
      opts = [arguments: [lang: []]]
      assert {:error, {:missing_argument, :lang}} = CLI.parse([], opts)
    end

    test "non-required arguments should be last" do
      opts = [arguments: [one: [], two: [required: false], three: []]]
      assert_raise ArgumentError, ~r/:three was given after :two/, fn -> CLI.parse([], opts) end

      # first late-required and closest non-required argument is used in error
      # message. So here error is between :d and :e
      opts = [
        arguments: [
          a: [],
          b: [required: false],
          c: [required: false],
          d: [required: false],
          e: [],
          f: []
        ]
      ]

      assert_raise ArgumentError, ~r/:e was given after :d/, fn -> CLI.parse([], opts) end
    end

    test "extra arguments are an error" do
      opts = [arguments: [lang: [required: true]]]
      assert {:error, {:extra_argument, "elixir"}} = CLI.parse(~w(erlang elixir), opts)
    end

    test "the parse_or_halt! shortcut words" do
      opts = [arguments: [lang: [required: true]]]
      assert :halt = CLI.parse_or_halt!([], opts)
      assert_receive {:cli_mate_shell, :halt, 1}
    end

    test "a command can have optional arguments" do
      opts = [arguments: [lang: [required: false]]]
      assert {:ok, %{arguments: %{lang: "elixir"}}} = CLI.parse(~w(elixir), opts)
      assert {:ok, %{arguments: args}} = CLI.parse([], opts)
      assert 0 = map_size(args)
    end

    test "arguments can be required or not" do
      opts = [arguments: [lang: [required: true]]]
      assert {:ok, %{arguments: %{lang: "erlang"}}} = CLI.parse(~w(erlang), opts)

      # The default value for option required is true
      opts = [arguments: [lang: []]]
      assert {:error, {:missing_argument, :lang}} = CLI.parse([], opts)

      # 2nd is not required
      opts = [arguments: [lang: [], platform: [required: false]]]
      assert {:ok, %{arguments: %{lang: "erlang"}}} = CLI.parse(~w(erlang), opts)
    end

    test "the arguments can be casted" do
      opts = [arguments: [one: [cast: fn v -> {:ok, String.to_integer(v) + 1} end]]]
      assert {:ok, %{arguments: %{one: 2}}} = CLI.parse(~w(1), opts)

      opts = [arguments: [one: [cast: {__MODULE__, :cast_add_int, []}]]]
      assert {:ok, %{arguments: %{one: 2}}} = CLI.parse(~w(1), opts)

      opts = [arguments: [one: [cast: {__MODULE__, :cast_add_int, [10]}]]]
      assert {:ok, %{arguments: %{one: 11}}} = CLI.parse(~w(1), opts)
    end

    test "invalid cast return" do
      opts = [arguments: [one: [cast: fn _ -> :NOT_A_RESULT_TUPLE end]]]

      assert_raise RuntimeError, ~r/returned invalid value/, fn ->
        CLI.parse(~w(1), opts)
      end
    end

    def cast_add_int(v, add \\ 1) do
      {:ok, String.to_integer(v) + add}
    end

    test "arguments cast can return error" do
      opts = [arguments: [one: [cast: fn _ -> {:error, "bad stuff"} end]]]
      assert {:error, {:argument_cast, :one, "bad stuff"}} = CLI.parse(~w(1), opts)
    end

    test "arguments can have type" do
      opts = [arguments: [one: [type: :integer]]]
      assert {:ok, %{arguments: %{one: 1}}} = CLI.parse(~w(1), opts)

      assert {:error, {:argument_type, :one, "Invalid argument one, expected type integer"}} =
               CLI.parse(~w(hello), opts)
    end

    test "arguments types are from a shortlist" do
      opts = [arguments: [one: [type: :"unknown-type"]]]

      assert_raise ArgumentError, ~r"expected argument type", fn ->
        CLI.parse(~w(1), opts)
      end
    end
  end
end
