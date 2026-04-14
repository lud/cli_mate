defmodule CliMate.CLI.SubcommandTest do
  alias CliMate.CLI
  alias CliMate.CLI.Command
  alias CliMate.CLI.ProcessShell
  use ExUnit.Case, async: true

  setup do
    CLI.put_shell(ProcessShell)
    :ok
  end

  defmodule SubModWithOptions do
    @behaviour CliMate.CLI.Command
    def command, do: [options: [foo: [type: :integer]]]
  end

  defmodule SubModExec do
    @behaviour CliMate.CLI.Command
    def command, do: [options: [y: [type: :string]]]

    def execute(parsed) do
      send(self(), {:executed_module, parsed})
      :ok
    end
  end

  defmodule SubModNoExec do
    @behaviour CliMate.CLI.Command
    def command, do: [options: [z: [type: :string]]]
  end

  defmodule SubModDoc do
    @behaviour CliMate.CLI.Command
    def command, do: [doc: "Module doc line"]
  end

  # --------------------------------------------------------------------
  #  Command construction
  # --------------------------------------------------------------------

  describe "Command construction with sub-commands" do
    test "accepts :subcommands as a keyword list and preserves order" do
      cmd = Command.new(subcommands: [zebra: [], alpha: [], mid: []])
      assert [zebra: _, alpha: _, mid: _] = cmd.subcommands
    end

    test "accepts :execute as a function of arity 1" do
      fun = fn _ -> :ok end
      cmd = Command.new(execute: fun)
      assert cmd.execute == fun
    end

    test "raises when both :arguments and :subcommands are given" do
      assert_raise ArgumentError, ~r/cannot define both/, fn ->
        Command.new(arguments: [x: []], subcommands: [sub: []])
      end
    end

    test "raises when :execute is not a 1-arity function" do
      assert_raise ArgumentError, ~r/function of arity 1/, fn ->
        Command.new(execute: fn -> :ok end)
      end
    end

    test "raises when :subcommands is not a keyword list" do
      assert_raise ArgumentError, ~r/keyword list/, fn ->
        Command.new(subcommands: "nope")
      end
    end

    test "sub-command values accept inline kw, %Command{}, and module atom" do
      struct = Command.new(options: [bar: [type: :integer]])

      cmd =
        Command.new(
          subcommands: [
            inline: [options: [x: []]],
            from_struct: struct,
            from_module: SubModWithOptions
          ]
        )

      assert [inline: _, from_struct: _, from_module: _] = cmd.subcommands
    end

    test "help option is still injected for a command with sub-commands" do
      cmd = Command.new(subcommands: [sub: []])
      assert Keyword.has_key?(cmd.options, :help)
    end
  end

  # --------------------------------------------------------------------
  #  Resolution
  # --------------------------------------------------------------------

  describe "Command.resolve_subcommand/2" do
    test "returns {:ok, key, child} for a declared sub-command name" do
      cmd = Command.new(subcommands: [foo: [options: [x: []]]])
      assert {:ok, :foo, %Command{}} = Command.resolve_subcommand(cmd, "foo")
    end

    test "returns :unknown_subcommand for an undeclared name that is nonetheless a known atom" do
      _hint = :definitely_an_atom_but_not_a_subcommand
      cmd = Command.new(subcommands: [foo: []])

      assert {:error, {:unknown_subcommand, "definitely_an_atom_but_not_a_subcommand"}} =
               Command.resolve_subcommand(cmd, "definitely_an_atom_but_not_a_subcommand")
    end

    test "fails gracefully when the input has no existing atom at all" do
      cmd = Command.new(subcommands: [foo: []])
      rand = "zzz_nonexistent_atom_#{:erlang.unique_integer([:positive])}"
      assert {:error, {:unknown_subcommand, ^rand}} = Command.resolve_subcommand(cmd, rand)
    end

    test "resolves a module-based sub-command by invoking command/0" do
      cmd = Command.new(subcommands: [sm: SubModWithOptions])

      assert {:ok, :sm, %Command{} = resolved} = Command.resolve_subcommand(cmd, "sm")
      assert {:foo, %{type: :integer}} = List.keyfind(resolved.options, :foo, 0)
      assert resolved.module == SubModWithOptions
    end
  end

  # --------------------------------------------------------------------
  #  Single-level parsing
  # --------------------------------------------------------------------

  describe "parse/2 with one level of sub-commands" do
    test "dispatches to the declared sub-command and records :path" do
      cmd = [subcommands: [sub: [options: [verbose: [type: :boolean]]]]]

      assert {:ok, %{path: [:sub], options: %{verbose: true}}} =
               CLI.parse(~w(sub --verbose), cmd)
    end

    test "parent options given before the sub-command are preserved" do
      cmd = [
        options: [global: [type: :string]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{global: "val"}, path: [:sub]}} =
               CLI.parse(~w(--global val sub), cmd)
    end

    test "child-level options are accepted after the sub-command name" do
      cmd = [subcommands: [sub: [options: [child_only: [type: :string]]]]]

      assert {:ok, %{options: %{child_only: "val"}, path: [:sub]}} =
               CLI.parse(~w(sub --child-only val), cmd)
    end

    test "parent options can be used after the sub-command name (inheritance)" do
      cmd = [
        options: [global: [type: :string]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{global: "val"}, path: [:sub]}} =
               CLI.parse(~w(sub --global val), cmd)
    end

    test "child redefinition drops the parent short alias" do
      cmd = [
        options: [verbose: [type: :boolean, short: :v]],
        subcommands: [sub: [options: [verbose: [type: :count]]]]
      ]

      assert {:error, {:invalid, [{"-v", _}]}} = CLI.parse(~w(sub -v), cmd)
    end

    test "child-only option given before sub-command errors at the parent stage (documented limitation)" do
      cmd = [subcommands: [sub: [options: [child_only: [type: :string]]]]]

      assert {:error, {:invalid, [{"--child-only", _}]}} =
               CLI.parse(~w(--child-only val sub), cmd)
    end

    test "keep parent, non-keep child → child fully replaces" do
      cmd = [
        options: [shared: [type: :string, keep: true]],
        subcommands: [sub: [options: [shared: [type: :string]]]]
      ]

      assert {:ok, %{options: %{shared: "y"}}} =
               CLI.parse(~w(--shared x sub --shared y), cmd)
    end

    test "non-keep parent, keep child → child wins with list" do
      cmd = [
        options: [shared: [type: :string]],
        subcommands: [sub: [options: [shared: [type: :string, keep: true]]]]
      ]

      assert {:ok, %{options: %{shared: ["y", "z"]}}} =
               CLI.parse(~w(--shared x sub --shared y --shared z), cmd)
    end

    test "both parent and child are keep with different types → child wins entirely" do
      cmd = [
        options: [shared: [type: :string, keep: true]],
        subcommands: [sub: [options: [shared: [type: :integer, keep: true]]]]
      ]

      assert {:ok, %{options: %{shared: [1, 2]}}} =
               CLI.parse(~w(--shared x sub --shared 1 --shared 2), cmd)
    end

    test "missing sub-command returns :missing_subcommand" do
      cmd = [subcommands: [sub: []]]
      assert {:error, :missing_subcommand} = CLI.parse([], cmd)
    end

    test "unknown sub-command returns {:unknown_subcommand, name}" do
      cmd = [subcommands: [sub: []]]
      assert {:error, {:unknown_subcommand, "nope"}} = CLI.parse(~w(nope), cmd)
    end

    test "unknown sub-command name with no existing atom still returns error gracefully" do
      cmd = [subcommands: [sub: []]]
      rand = "zzz_never_existed_#{:erlang.unique_integer([:positive])}"
      assert {:error, {:unknown_subcommand, ^rand}} = CLI.parse([rand], cmd)
    end
  end

  # --------------------------------------------------------------------
  #  Multi-level nesting
  # --------------------------------------------------------------------

  describe "parse/2 with multi-level nesting" do
    test "two levels dispatch and assign argument at the leaf" do
      cmd = [
        subcommands: [
          a: [subcommands: [b: [arguments: [val: []]]]]
        ]
      ]

      assert {:ok, %{path: [:a, :b], arguments: %{val: "hello"}}} =
               CLI.parse(~w(a b hello), cmd)
    end

    test "path records all resolved sub-commands in order" do
      cmd = [subcommands: [a: [subcommands: [b: [subcommands: [c: []]]]]]]
      assert {:ok, %{path: [:a, :b, :c]}} = CLI.parse(~w(a b c), cmd)
    end

    test "options defined at each level are all present in the merged result" do
      cmd = [
        options: [g: [type: :string]],
        subcommands: [
          mid: [
            options: [m: [type: :string]],
            subcommands: [
              leaf: [options: [l: [type: :string]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{g: "gv", m: "mv", l: "lv"}}} =
               CLI.parse(~w(--g gv mid --m mv leaf --l lv), cmd)
    end

    test "leaf-level redefinition of root option wins" do
      cmd = [
        options: [x: [type: :string, default: "root"]],
        subcommands: [
          mid: [
            subcommands: [
              leaf: [options: [x: [type: :integer]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{x: 42}}} = CLI.parse(~w(mid leaf --x 42), cmd)
    end

    test "three levels all redefining same :keep option → last level wins" do
      cmd = [
        options: [x: [type: :string, keep: true]],
        subcommands: [
          a: [
            options: [x: [type: :string, keep: true]],
            subcommands: [
              b: [options: [x: [type: :integer, keep: true]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{x: [9]}}} = CLI.parse(~w(--x r a --x ma b --x 9), cmd)
    end

    test "--help at an intermediate level returns help for that level" do
      cmd = [
        subcommands: [
          a: [subcommands: [b: []]]
        ]
      ]

      assert {:ok, %{options: %{help: true}, path: [:a]}} = CLI.parse(~w(a --help), cmd)
    end
  end

  # --------------------------------------------------------------------
  #  Options merging across levels
  # --------------------------------------------------------------------

  describe "parse/2 options merging across levels" do
    test "parent option set on argv is preserved when child does not override it" do
      cmd = [
        options: [token: [type: :string]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{token: "abc"}, path: [:sub]}} =
               CLI.parse(~w(--token abc sub), cmd)
    end

    test "parent-set value is preserved even when the option has a default" do
      cmd = [
        options: [token: [type: :string, default: "fallback"]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{token: "abc"}, path: [:sub]}} =
               CLI.parse(~w(--token abc sub), cmd)
    end

    test "parent option is preserved across an intermediate level that does not redefine it" do
      cmd = [
        options: [token: [type: :string]],
        subcommands: [
          mid: [subcommands: [leaf: []]]
        ]
      ]

      assert {:ok, %{options: %{token: "abc"}, path: [:mid, :leaf]}} =
               CLI.parse(~w(--token abc mid leaf), cmd)
    end

    test "parent-set value survives an intermediate level even when the option has a default" do
      cmd = [
        options: [token: [type: :string, default: "fallback"]],
        subcommands: [
          mid: [subcommands: [leaf: []]]
        ]
      ]

      assert {:ok, %{options: %{token: "abc"}, path: [:mid, :leaf]}} =
               CLI.parse(~w(--token abc mid leaf), cmd)
    end

    test "parent default applies at child level when neither level passes the option" do
      cmd = [
        options: [token: [type: :string, default: "fallback"]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{token: "fallback"}, path: [:sub]}} =
               CLI.parse(~w(sub), cmd)
    end

    test "child default wins over parent default when option is not passed on argv" do
      cmd = [
        options: [token: [type: :string, default: "parent_default"]],
        subcommands: [
          sub: [options: [token: [type: :string, default: "child_default"]]]
        ]
      ]

      assert {:ok, %{options: %{token: "child_default"}, path: [:sub]}} =
               CLI.parse(~w(sub), cmd)
    end

    test "grandchild default wins over parent default through an unchanged intermediate" do
      cmd = [
        options: [token: [type: :string, default: "parent_default"]],
        subcommands: [
          mid: [
            subcommands: [
              leaf: [options: [token: [type: :string, default: "leaf_default"]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{token: "leaf_default"}, path: [:mid, :leaf]}} =
               CLI.parse(~w(mid leaf), cmd)
    end

    test "grandchild parsed value overrides parent default through an unchanged intermediate" do
      cmd = [
        options: [token: [type: :string, default: "parent_default"]],
        subcommands: [
          mid: [subcommands: [leaf: []]]
        ]
      ]

      assert {:ok, %{options: %{token: "leaf_value"}, path: [:mid, :leaf]}} =
               CLI.parse(~w(mid leaf --token leaf_value), cmd)
    end

    test "keep option list is replaced at a deeper level, not accumulated" do
      cmd = [
        options: [tag: [type: :string, keep: true]],
        subcommands: [
          mid: [subcommands: [leaf: []]]
        ]
      ]

      assert {:ok, %{options: %{tag: ["c"]}, path: [:mid, :leaf]}} =
               CLI.parse(~w(--tag a --tag b mid leaf --tag c), cmd)
    end
  end

  # --------------------------------------------------------------------
  #  Execute callback
  # --------------------------------------------------------------------

  describe "execute callback" do
    test "keyword :execute is exposed as a zero-arity closure" do
      me = self()
      cmd = [options: [x: [type: :string]], execute: fn p -> send(me, {:executed, p}) end]

      assert {:ok, %{execute: run}} = CLI.parse(~w(--x hello), cmd)
      assert is_function(run, 0)
    end

    test "calling the closure invokes the function with the parsed map (without :execute key)" do
      me = self()
      cmd = [options: [x: [type: :string]], execute: fn p -> send(me, {:executed, p}) end]

      assert {:ok, parsed} = CLI.parse(~w(--x hello), cmd)
      parsed.execute.()

      assert_receive {:executed, received}
      refute Map.has_key?(received, :execute)
      assert received.options.x == "hello"
    end

    test "module-based sub-command with execute/1 auto-wires the callback" do
      cmd = [subcommands: [sm: SubModExec]]

      assert {:ok, %{execute: run} = parsed} = CLI.parse(~w(sm --y hello), cmd)
      assert is_function(run, 0)
      assert parsed.path == [:sm]

      run.()
      assert_receive {:executed_module, received}
      refute Map.has_key?(received, :execute)
      assert received.options.y == "hello"
    end

    test "module-based sub-command without execute/1 returns execute: nil" do
      cmd = [subcommands: [nm: SubModNoExec]]

      assert {:ok, %{execute: nil}} = CLI.parse(~w(nm --z hi), cmd)
    end

    test "root command with :execute and no sub-commands produces closure" do
      cmd = [options: [x: []], execute: fn _ -> :done end]
      assert {:ok, %{execute: run}} = CLI.parse(~w(--x v), cmd)
      assert is_function(run, 0)
    end

    test "when --help is hit, execute is nil" do
      cmd = [options: [x: []], execute: fn _ -> :done end]
      assert {:ok, %{options: %{help: true}, execute: nil}} = CLI.parse(~w(--help), cmd)
    end
  end

  # --------------------------------------------------------------------
  #  parse_or_halt!/2 behaviour
  # --------------------------------------------------------------------

  describe "parse_or_halt!/2" do
    test "--help at root prints root usage and halts 0" do
      cmd = [
        name: "mycmd",
        subcommands: [sub: [name: "mycmd-sub"]]
      ]

      assert :halt = CLI.parse_or_halt!(~w(--help), cmd)
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "mycmd"
      refute text =~ "mycmd-sub"
      assert_receive {:cli_mate_shell, :halt, 0}
    end

    test "`mycmd sub --help` prints the sub-command's usage, not the root's" do
      cmd = [
        name: "mycmd",
        subcommands: [
          sub: [name: "mycmd-sub", options: [alpha: [doc: "alpha doc", type: :string]]]
        ]
      ]

      assert :halt = CLI.parse_or_halt!(~w(sub --help), cmd)
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "mycmd-sub"
      assert text =~ "alpha"
      assert_receive {:cli_mate_shell, :halt, 0}
    end

    test "unknown sub-command prints usage and error, halts 1" do
      cmd = [name: "mycmd", subcommands: [sub: []]]
      assert :halt = CLI.parse_or_halt!(~w(bogus), cmd)
      assert_receive {:cli_mate_shell, :info, _text}
      assert_receive {:cli_mate_shell, :error, err}
      assert err =~ "unknown sub-command"
      assert_receive {:cli_mate_shell, :halt, 1}
    end

    test "invalid option at child level prints the child's usage and halts 1" do
      cmd = [
        name: "mycmd",
        subcommands: [
          sub: [name: "mycmd-sub", options: [valid: [type: :string]]]
        ]
      ]

      assert :halt = CLI.parse_or_halt!(~w(sub --bogus), cmd)
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "mycmd-sub"
      assert_receive {:cli_mate_shell, :error, err}
      assert err =~ "invalid option"
      assert_receive {:cli_mate_shell, :halt, 1}
    end

    test "successful parse returns the parsed map with :path and :execute" do
      cmd = [subcommands: [sub: [options: [x: [type: :string]]]]]

      parsed = CLI.parse_or_halt!(~w(sub --x v), cmd)
      assert parsed.path == [:sub]
      assert parsed.options.x == "v"
      assert parsed.execute == nil
    end
  end

  # --------------------------------------------------------------------
  #  Usage format
  # --------------------------------------------------------------------

  describe "usage format" do
    test "synopsis for a command with sub-commands ends with <subcommand>" do
      cmd = [name: "cmd", subcommands: [sub: []]]
      out = cmd |> CLI.format_usage() |> IO.iodata_to_binary()
      assert out =~ "cmd [options] <subcommand>"
    end

    test "Sub-commands section lists children in declaration order" do
      cmd = [
        name: "cmd",
        subcommands: [
          zebra: [doc: "Z doc"],
          alpha: [doc: "A doc"],
          mid: [doc: "M doc"]
        ]
      ]

      out = cmd |> CLI.format_usage() |> IO.iodata_to_binary()
      assert out =~ "Sub-commands"
      assert out =~ "Z doc"

      {z, _} = :binary.match(out, "zebra")
      {a, _} = :binary.match(out, "alpha")
      {m, _} = :binary.match(out, "mid")
      assert z < a
      assert a < m
    end

    test "module-form sub-command docs are pulled from command/0" do
      cmd = [name: "cmd", subcommands: [dm: SubModDoc]]
      out = cmd |> CLI.format_usage() |> IO.iodata_to_binary()
      assert out =~ "Module doc line"
    end

    test "help for a leaf sub-command shows both parent and child options" do
      cmd = [
        name: "mycmd",
        options: [parent_opt: [type: :string, doc: "parent option doc"]],
        subcommands: [
          sub: [
            name: "mycmd-sub",
            options: [child_opt: [type: :string, doc: "child option doc"]]
          ]
        ]
      ]

      assert :halt = CLI.parse_or_halt!(~w(sub --help), cmd)
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "parent-opt"
      assert text =~ "child-opt"
    end
  end

  # --------------------------------------------------------------------
  #  Backwards compatibility
  # --------------------------------------------------------------------

  describe "backwards compatibility" do
    test "a flat command parses identically to the legacy shape" do
      cmd = [options: [foo: [type: :string]], arguments: [bar: []]]

      assert {:ok, %{options: %{foo: "v"}, arguments: %{bar: "b"}}} =
               CLI.parse(~w(--foo v b), cmd)
    end

    test "result map carries :path (empty) and :execute (nil) for a flat command" do
      cmd = [options: [x: []]]
      assert {:ok, %{path: [], execute: nil}} = CLI.parse(~w(--x v), cmd)
    end

    test "format_usage for a flat command shows no sub-commands markers" do
      cmd = [name: "cmd", options: [foo: [type: :string, doc: "a foo"]]]
      out = cmd |> CLI.format_usage() |> IO.iodata_to_binary()
      refute out =~ "Sub-commands"
      refute out =~ "<subcommand>"
      assert out =~ "foo"
    end
  end
end
