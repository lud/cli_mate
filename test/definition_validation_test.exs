defmodule CliMate.CLI.DefinitionValidationTest do
  alias CliMate.CLI
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Command
  alias CliMate.CLI.Option
  use ExUnit.Case, async: true

  defmodule NotACommand do
    def hello, do: :world
  end

  defmodule GoodSubCommand do
    @behaviour CliMate.CLI.Command
    def command, do: [options: [x: []]]
  end

  defmodule RecursiveCommand do
    @behaviour CliMate.CLI.Command
    def command, do: [subcommands: [again: __MODULE__, stop: []]]
  end

  defmodule MapCommand do
    def command, do: %{options: []}
  end

  defmodule BadSubCommand do
    @behaviour CliMate.CLI.Command
    def command, do: [options: :bad]
  end

  defp assert_invalid(message, fun) do
    err = assert_raise ArgumentError, fun
    assert err.message =~ message
  end

  describe "option settings" do
    test "accepts valid settings" do
      assert %Option{} =
               Option.new(:opt,
                 type: :integer,
                 doc: "some doc",
                 short: :o,
                 default: 1,
                 keep: true,
                 doc_arg: "num",
                 default_doc: "one",
                 cast: {Function, :identity, []},
                 deprecated: "use --other"
               )

      assert %Option{} = Option.new(:opt, doc: nil, short: nil, default_doc: nil, cast: nil)
      assert %Option{} = Option.new(:opt, default: fn -> 1 end)
      assert %Option{} = Option.new(:opt, default: fn key -> key end)
    end

    test "rejects invalid types" do
      for type <- [:str, :atom, "string", nil] do
        assert_invalid(
          "invalid value for :type in option :opt, expected one of :boolean, :count",
          fn -> Option.new(:opt, type: type) end
        )
      end
    end

    test "rejects settings that are not a keyword list" do
      for conf <- [:boolean, "doc", %{}, [:type]] do
        assert_invalid("invalid option :opt, expected a keyword list", fn ->
          Option.new(:opt, conf)
        end)
      end
    end

    test "rejects non-atom keys" do
      assert_invalid("invalid option key, expected an atom", fn -> Option.new("opt", []) end)
    end

    test "rejects invalid shorts" do
      for short <- ["a", 1, :ab, true, :"1", :-, :" "] do
        assert_invalid(
          "invalid value for :short in option :opt, expected a single-letter atom",
          fn ->
            Option.new(:opt, short: short)
          end
        )
      end
    end

    test "rejects invalid values for each setting" do
      cases = [
        keep: "yes",
        keep: nil,
        doc: 123,
        doc: :atom,
        doc_arg: 123,
        doc_arg: nil,
        default_doc: 123,
        cast: "not a function",
        default: fn _, _ -> :x end
      ]

      for {key, value} <- cases do
        assert_invalid("invalid value for #{inspect(key)} in option :opt", fn ->
          Option.new(:opt, [{key, value}])
        end)
      end
    end

    test "rejects unknown settings" do
      assert_invalid("unknown setting :defualt in option :opt", fn ->
        Option.new(:opt, defualt: "x")
      end)

      assert_invalid("unknown setting :required in option :opt", fn ->
        Option.new(:opt, required: true)
      end)
    end

    test "rejects duplicate settings" do
      assert_invalid("duplicate setting :type in option :opt", fn ->
        Option.new(:opt, type: :string, type: :integer)
      end)
    end

    test "rejects keep with the count type" do
      assert_invalid("option :opt cannot use keep: true with type: :count", fn ->
        Option.new(:opt, type: :count, keep: true)
      end)

      assert %Option{} = Option.new(:opt, type: :count, keep: false)
    end
  end

  describe "argument settings" do
    test "accepts valid settings" do
      assert %Argument{} =
               Argument.new(:arg,
                 required: false,
                 type: :float,
                 doc: "some doc",
                 cast: &{:ok, &1},
                 repeat: true
               )
    end

    test "rejects settings that are not a keyword list" do
      assert_invalid("invalid argument :arg, expected a keyword list", fn ->
        Argument.new(:arg, :string)
      end)
    end

    test "rejects non-atom keys" do
      assert_invalid("invalid argument key, expected an atom", fn -> Argument.new("arg", []) end)
    end

    test "rejects invalid values for each setting" do
      cases = [required: "yes", repeat: "yes", doc: 123, type: :boolean, cast: {:nope}]

      for {key, value} <- cases do
        assert_invalid("invalid value for #{inspect(key)} in argument :arg", fn ->
          Argument.new(:arg, [{key, value}])
        end)
      end
    end

    test "rejects unknown settings" do
      assert_invalid("unknown setting :requried in argument :arg", fn ->
        Argument.new(:arg, requried: false)
      end)
    end
  end

  describe "command settings" do
    test "rejects invalid values for each setting" do
      cases = [
        name: 123,
        version: 1,
        doc: :doc,
        module: "Mod",
        options: %{opt: []},
        options: [{"opt", []}],
        arguments: :arg,
        subcommands: "nope",
        execute: fn -> :ok end
      ]

      for {key, value} <- cases do
        assert_invalid("invalid value for #{inspect(key)} in command", fn ->
          Command.new([{key, value}])
        end)
      end
    end

    test "rejects unknown settings" do
      assert_invalid(~s(unknown setting :option in command "tool"), fn ->
        Command.new(name: "tool", option: [verbose: []])
      end)

      assert_invalid("unknown setting :argument in command", fn ->
        Command.new(argument: [file: []])
      end)
    end

    test "names the module in the error" do
      assert_invalid("unknown setting :option in command SomeMod", fn ->
        Command.new(module: SomeMod, option: [])
      end)
    end

    test "rejects duplicate option keys" do
      assert_invalid("duplicate option :opt in command", fn ->
        Command.new(options: [opt: [type: :string], opt: [type: :integer]])
      end)
    end

    test "rejects duplicate argument keys" do
      assert_invalid("duplicate argument :a in command", fn ->
        Command.new(arguments: [a: [], a: []])
      end)
    end

    test "rejects duplicate shorts" do
      assert_invalid("options :a and :b use the same short :x in command", fn ->
        Command.new(options: [a: [short: :x], b: [short: :x]])
      end)
    end

    test "names the command in argument ordering errors" do
      assert_invalid(~s(:b was defined after :a in command "tool"), fn ->
        Command.new(name: "tool", arguments: [a: [required: false], b: []])
      end)

      assert_invalid(~s(:b was defined after :a in command "tool"), fn ->
        Command.new(name: "tool", arguments: [a: [repeat: true], b: []])
      end)
    end

    test "accepts non-ASCII letters as shorts" do
      assert %Option{short: :é} = Option.new(:opt, short: :é)
    end

    test "reports the invalid option" do
      assert_invalid("invalid value for :keep in option :opt", fn ->
        Command.new(options: [opt: [keep: "yes"]])
      end)
    end
  end

  describe "sub-commands" do
    test "are built when resolved" do
      struct = Command.new([])
      command = Command.new(subcommands: [sub: [], mod: GoodSubCommand, from_struct: struct])

      assert [sub: [], mod: GoodSubCommand, from_struct: ^struct] = command.subcommands
      assert {:ok, :sub, %Command{}} = Command.resolve_subcommand(command, "sub")

      assert {:ok, :mod, %Command{module: GoodSubCommand}} =
               Command.resolve_subcommand(command, "mod")

      assert {:ok, :from_struct, ^struct} = Command.resolve_subcommand(command, "from_struct")
    end

    test "invalid definitions are not built until selected" do
      command = Command.new(name: "tool", subcommands: [good: [], bad: [options: :bad]])

      assert {:ok, %{path: [:good]}} = CLI.parse(~w(good), command)

      assert_invalid(~s(invalid value for :options in sub-command :bad of command "tool"), fn ->
        CLI.parse(~w(bad), command)
      end)
    end

    test "reject invalid module definitions when resolved" do
      command = Command.new(subcommands: [sub: BadSubCommand])

      assert_invalid("invalid value for :options in sub-command :sub of command", fn ->
        Command.resolve_subcommand(command, "sub")
      end)
    end

    test "reject modules without command/0 when resolved" do
      command = Command.new(subcommands: [sub: NotACommand])

      assert_invalid(
        "expected a module implementing command/0, got: #{inspect(NotACommand)}",
        fn -> Command.resolve_subcommand(command, "sub") end
      )
    end

    test "reject modules whose command/0 does not return a list" do
      assert_invalid(
        "invalid command, expected #{inspect(MapCommand)}.command/0 to return a keyword list",
        fn -> Command.new(MapCommand) end
      )
    end

    test "reject invalid definitions when formatting usage" do
      command = Command.new(name: "tool", subcommands: [sub: [bad: 1]])

      assert_invalid(~s(unknown setting :bad in sub-command :sub of command "tool"), fn ->
        CLI.format_usage(command)
      end)
    end

    test "reject values that are not a command" do
      assert_invalid(
        "invalid sub-command :sub of command, expected a keyword list or a module",
        fn -> Command.new(subcommands: [sub: "nope"]) end
      )
    end

    test "reject non-atom keys" do
      assert_invalid("invalid value for :subcommands in command, expected a keyword list", fn ->
        Command.new(subcommands: [{"sub", []}])
      end)
    end

    test "reject duplicate keys" do
      assert_invalid("duplicate sub-command :sub in command", fn ->
        Command.new(subcommands: [sub: [], sub: []])
      end)
    end

    test "a module can list itself as a sub-command" do
      command = Command.new(subcommands: [again: RecursiveCommand])
      assert {:ok, %{path: [:again, :again, :stop]}} = CLI.parse(~w(again again stop), command)
    end
  end
end
