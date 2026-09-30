defmodule CliMate.CLI.DeprecatedOptionTest do
  alias CliMate.CLI
  alias CliMate.CLI.Option
  alias CliMate.CLI.ProcessShell
  use ExUnit.Case, async: true

  setup do
    CLI.put_shell(ProcessShell)
    :ok
  end

  defp assert_deprecation_warning(long_name) do
    assert_received {:cli_mate_shell, :warn, message}
    assert message =~ "--#{long_name}"
    assert message =~ "deprecated"
    message
  end

  defp refute_warnings do
    refute_received {:cli_mate_shell, :warn, _}
  end

  defp usage_text(command, fmt_opts \\ []) do
    command
    |> CLI.format_usage(Keyword.put_new(fmt_opts, :io_columns, 100))
    |> IO.ANSI.format(_emit = false)
    |> IO.iodata_to_binary()
  end

  describe "option definition" do
    test "accepts true, false, nil and a string" do
      for value <- [true, false, nil, "use --other instead"] do
        Option.new(:old, deprecated: value)
      end
    end

    test "raises on an invalid value" do
      for value <- [:yes, 1, ~c"charlist", %{}] do
        assert_raise ArgumentError, fn ->
          Option.new(:old, deprecated: value)
        end
      end
    end
  end

  describe "warning message" do
    test "uses a default message when deprecated is true" do
      command = [options: [old_name: [type: :string, deprecated: true]]]

      assert {:ok, _} = CLI.parse(~w(--old-name x), command)
      assert "option --old-name is deprecated" == assert_deprecation_warning("old-name")
    end

    test "appends the custom message when deprecated is a string" do
      command = [
        options: [old_name: [type: :string, deprecated: "use --new-name instead"]]
      ]

      assert {:ok, _} = CLI.parse(~w(--old-name x), command)

      assert "option --old-name is deprecated, use --new-name instead" ==
               assert_deprecation_warning("old-name")
    end

    test "does not print the option :doc" do
      command = [
        options: [
          old_name: [type: :string, doc: "Some option documentation.", deprecated: true]
        ]
      ]

      assert {:ok, _} = CLI.parse(~w(--old-name x), command)
      refute assert_deprecation_warning("old-name") =~ "Some option documentation."
    end

    test "uses the long name when the short form is given" do
      command = [options: [old_name: [type: :string, short: :x, deprecated: true]]]

      assert {:ok, _} = CLI.parse(~w(-x v), command)
      message = assert_deprecation_warning("old-name")
      refute message =~ "-x"
    end

    test "is sent through the shell as a warning" do
      command = [options: [old: [type: :boolean, deprecated: true]]]

      assert {:ok, _} = CLI.parse(~w(--old), command)
      refute_received {:cli_mate_shell, :info, _}
      refute_received {:cli_mate_shell, :error, _}
      assert_deprecation_warning("old")
    end
  end

  describe "when warnings are emitted" do
    test "no warning when a deprecated option is not given" do
      command = [
        options: [
          old: [type: :string, deprecated: true],
          other: [type: :string]
        ]
      ]

      assert {:ok, %{options: options}} = CLI.parse(~w(--other x), command)
      refute Map.has_key?(options, :old)
      refute_warnings()
    end

    test "no warning when a deprecated option only receives its default value" do
      command = [options: [old: [type: :string, default: "dflt", deprecated: true]]]

      assert {:ok, %{options: %{old: "dflt"}}} = CLI.parse([], command)
      refute_warnings()
    end

    test "no warning when a deprecated option with a function default is not given" do
      command = [
        options: [old: [type: :integer, default: fn -> 123 end, deprecated: true]]
      ]

      assert {:ok, %{options: %{old: 123}}} = CLI.parse([], command)
      refute_warnings()
    end

    test "no warning when a deprecated :keep option only receives its empty list default" do
      command = [options: [old: [type: :string, keep: true, deprecated: true]]]

      assert {:ok, %{options: %{old: []}}} = CLI.parse([], command)
      refute_warnings()
    end

    test "no warning for non-deprecated options" do
      command = [
        options: [
          a: [type: :string],
          b: [type: :boolean, deprecated: false],
          c: [type: :integer, deprecated: nil]
        ]
      ]

      assert {:ok, _} = CLI.parse(~w(--a x --b --c 1), command)
      refute_warnings()
    end

    test "warns when the deprecated option is given with its default value" do
      command = [options: [old: [type: :string, default: "dflt", deprecated: true]]]

      assert {:ok, %{options: %{old: "dflt"}}} = CLI.parse(~w(--old dflt), command)
      assert_deprecation_warning("old")
    end

    test "warns for a boolean given in its --no- form" do
      command = [options: [old: [type: :boolean, default: true, deprecated: true]]]

      assert {:ok, %{options: %{old: false}}} = CLI.parse(~w(--no-old), command)
      assert_deprecation_warning("old")
    end

    test "warns once per deprecated option, each option having its own warning" do
      command = [
        options: [
          old_a: [type: :string, deprecated: true],
          old_b: [type: :string, deprecated: "use --new-b"],
          regular: [type: :string]
        ]
      ]

      assert {:ok, _} = CLI.parse(~w(--old-a x --regular y --old-b z), command)

      assert_received {:cli_mate_shell, :warn, first}
      assert_received {:cli_mate_shell, :warn, second}
      refute_warnings()

      messages = [first, second]
      assert Enum.any?(messages, &(&1 =~ "--old-a"))
      assert Enum.any?(messages, &(&1 =~ "--old-b"))
    end

    test "each call to parse emits its own warnings" do
      command = [options: [old: [type: :string, deprecated: true]]]

      assert {:ok, _} = CLI.parse(~w(--old x), command)
      assert_deprecation_warning("old")

      assert {:ok, _} = CLI.parse(~w(--old x), command)
      assert_deprecation_warning("old")

      refute_warnings()
    end
  end

  describe "warn once" do
    test "a :keep option given multiple times warns once" do
      command = [options: [old: [type: :string, keep: true, deprecated: true]]]

      assert {:ok, %{options: %{old: ["a", "b", "c"]}}} =
               CLI.parse(~w(--old a --old b --old c), command)

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "a :keep option given in both short and long forms warns once" do
      command = [options: [old: [type: :string, short: :o, keep: true, deprecated: true]]]

      assert {:ok, %{options: %{old: ["a", "b"]}}} = CLI.parse(~w(--old a -o b), command)
      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "a non-keep option given multiple times warns once" do
      command = [options: [old: [type: :string, deprecated: true]]]

      assert {:ok, %{options: %{old: "b"}}} = CLI.parse(~w(--old a --old b), command)
      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "a :count option given multiple times warns once" do
      command = [options: [old: [type: :count, short: :o, deprecated: true]]]

      assert {:ok, %{options: %{old: 3}}} = CLI.parse(~w(-ooo), command)
      assert_deprecation_warning("old")
      refute_warnings()
    end
  end

  describe "parsed values" do
    test "the value of a deprecated option is available" do
      command = [
        options: [
          old_str: [type: :string, deprecated: true],
          old_int: [type: :integer, deprecated: true],
          old_bool: [type: :boolean, deprecated: true]
        ]
      ]

      assert {:ok, %{options: %{old_str: "x", old_int: 12, old_bool: true}}} =
               CLI.parse(~w(--old-str x --old-int 12 --old-bool), command)
    end

    test "the cast function is applied to a deprecated option" do
      command = [
        options: [
          old: [type: :string, deprecated: true, cast: &{:ok, String.upcase(&1)}]
        ]
      ]

      assert {:ok, %{options: %{old: "HELLO"}}} = CLI.parse(~w(--old hello), command)
      assert_deprecation_warning("old")
    end

    test "invalid values are still reported as errors" do
      command = [options: [old: [type: :integer, deprecated: true]]]

      assert {:error, {:invalid, _}} = CLI.parse(~w(--old not-an-int), command)
    end

    test "cast errors are still reported as errors" do
      command = [
        options: [old: [type: :string, deprecated: true, cast: fn _ -> {:error, "bad"} end]]
      ]

      assert {:error, {:option_cast, :old, "bad"}} = CLI.parse(~w(--old x), command)
    end

    test "arguments are parsed along deprecated options" do
      command = [
        options: [old: [type: :string, deprecated: true]],
        arguments: [name: []]
      ]

      assert {:ok, %{options: %{old: "x"}, arguments: %{name: "joe"}}} =
               CLI.parse(~w(--old x joe), command)
    end
  end

  describe "parse_or_halt!/2" do
    test "warns and returns the parsed options" do
      command = [options: [old: [type: :string, deprecated: "use --new"]]]

      assert %{options: %{old: "x"}} = CLI.parse_or_halt!(~w(--old x), command)
      assert_deprecation_warning("old")
      refute_received {:cli_mate_shell, :halt, _}
    end

    test "help output does not include deprecated options" do
      command = [
        name: "mycmd",
        options: [
          old_name: [type: :string, doc: "Old option doc.", deprecated: true],
          regular: [type: :string, doc: "Regular option doc."]
        ]
      ]

      assert :halt = CLI.parse_or_halt!(~w(--help), command)
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "--regular"
      refute text =~ "old-name"
      refute text =~ "Old option doc."
    end
  end

  describe "usage" do
    test "plain text usage hides deprecated options" do
      command = [
        name: "mycmd",
        options: [
          old_name: [type: :string, short: :o, doc: "Old option doc.", deprecated: true],
          regular: [type: :string, short: :r, doc: "Regular option doc."]
        ]
      ]

      text = usage_text(command)
      assert text =~ "--regular"
      assert text =~ "Regular option doc."
      assert text =~ "--help"
      refute text =~ "old-name"
      refute text =~ "Old option doc."
      refute text =~ "-o "
    end

    test "markdown usage hides deprecated options" do
      command = [
        module: Mix.Tasks.Some.Command,
        options: [
          old_name: [type: :string, short: :o, doc: "Old option doc.", deprecated: true],
          regular: [type: :string, short: :r, doc: "Regular option doc."]
        ]
      ]

      text = usage_text(command, format: :moduledoc)
      assert text =~ "--regular"
      assert text =~ "Regular option doc."
      refute text =~ "old-name"
      refute text =~ "Old option doc."
    end

    test "options with deprecated set to false or nil are shown" do
      command = [
        name: "mycmd",
        options: [
          opt_false: [type: :string, deprecated: false],
          opt_nil: [type: :string, deprecated: nil]
        ]
      ]

      text = usage_text(command)
      assert text =~ "--opt-false"
      assert text =~ "--opt-nil"
    end

    test "usage renders when all options besides --help are deprecated" do
      command = [
        name: "mycmd",
        options: [
          old_a: [type: :string, deprecated: true],
          old_b: [type: :boolean, deprecated: "use --new-b"]
        ]
      ]

      for format <- [:cli, :moduledoc] do
        text = usage_text(command, format: format)
        assert text =~ "--help"
        refute text =~ "old-a"
        refute text =~ "old-b"
      end
    end

    test "usage keeps the order of remaining options" do
      command = [
        name: "mycmd",
        options: [
          zzz: [short: :z, type: :string],
          old: [short: :o, type: :string, deprecated: true],
          aaa: [short: :a, type: :string]
        ]
      ]

      opts_lines =
        command
        |> usage_text()
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "-"))

      assert ["-z" <> _, "-a" <> _, "--help" <> _] = opts_lines
    end
  end

  describe "sub-commands" do
    defp parent_deprecated_command do
      [
        name: "mycmd",
        options: [
          old: [type: :string, short: :o, doc: "Old parent doc.", deprecated: true],
          regular: [type: :string, doc: "Regular parent doc."]
        ],
        subcommands: [
          sub: [
            name: "mycmd-sub",
            options: [child_opt: [type: :string, doc: "Child option doc."]],
            arguments: [arg: [required: false]]
          ]
        ]
      ]
    end

    test "parent deprecated option given before the sub-command name warns once" do
      assert {:ok, %{options: %{old: "x"}, path: [:sub]}} =
               CLI.parse(~w(--old x sub), parent_deprecated_command())

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "parent deprecated option given after the sub-command name warns once" do
      assert {:ok, %{options: %{old: "x"}, path: [:sub]}} =
               CLI.parse(~w(sub --old x), parent_deprecated_command())

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "parent deprecated option given at both levels warns once" do
      assert {:ok, %{options: %{old: "y"}, path: [:sub]}} =
               CLI.parse(~w(--old x sub -o y), parent_deprecated_command())

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "parent deprecated option not given does not warn" do
      assert {:ok, %{path: [:sub]}} =
               CLI.parse(~w(--regular r sub --child-opt c), parent_deprecated_command())

      refute_warnings()
    end

    test "deprecated option given at every level of a deep tree warns once" do
      command = [
        options: [old: [type: :string, keep: true, deprecated: true]],
        subcommands: [
          a: [
            subcommands: [
              b: [
                subcommands: [
                  c: [options: [leaf: [type: :string]]]
                ]
              ]
            ]
          ]
        ]
      ]

      assert {:ok, %{path: [:a, :b, :c]}} =
               CLI.parse(~w(--old 1 a --old 2 b --old 3 c --old 4), command)

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "deprecated option of an intermediate command warns once" do
      command = [
        subcommands: [
          a: [
            options: [old: [type: :string, deprecated: "use --new"]],
            subcommands: [b: []]
          ]
        ]
      ]

      assert {:ok, %{options: %{old: "y"}, path: [:a, :b]}} =
               CLI.parse(~w(a --old x b --old y), command)

      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "child deprecated option warns" do
      command = [
        subcommands: [
          sub: [options: [old: [type: :boolean, deprecated: true]]]
        ]
      ]

      assert {:ok, %{options: %{old: true}, path: [:sub]}} = CLI.parse(~w(sub --old), command)
      assert_deprecation_warning("old")
      refute_warnings()
    end

    test "deprecated options from different levels each warn once" do
      command = [
        options: [old_parent: [type: :string, deprecated: true]],
        subcommands: [
          sub: [options: [old_child: [type: :string, deprecated: true]]]
        ]
      ]

      assert {:ok, _} =
               CLI.parse(~w(--old-parent a sub --old-child b --old-parent c), command)

      assert_received {:cli_mate_shell, :warn, first}
      assert_received {:cli_mate_shell, :warn, second}
      refute_warnings()

      messages = [first, second]
      assert Enum.any?(messages, &(&1 =~ "--old-parent"))
      assert Enum.any?(messages, &(&1 =~ "--old-child"))
    end

    test "sub-command help hides parent deprecated options" do
      assert :halt = CLI.parse_or_halt!(~w(sub --help), parent_deprecated_command())
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "mycmd-sub"
      assert text =~ "--regular"
      assert text =~ "--child-opt"
      refute text =~ "--old"
      refute text =~ "Old parent doc."
    end

    test "root help hides deprecated options" do
      assert :halt = CLI.parse_or_halt!(~w(--help), parent_deprecated_command())
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "--regular"
      refute text =~ "--old"
    end

    defp child_undeprecates_command do
      [
        options: [key: [type: :string, deprecated: true]],
        subcommands: [
          sub: [name: "mycmd-sub", options: [key: [type: :string, doc: "Child key doc."]]]
        ]
      ]
    end

    defp child_deprecates_command do
      [
        options: [key: [type: :string, doc: "Parent key doc."]],
        subcommands: [
          sub: [name: "mycmd-sub", options: [key: [type: :string, deprecated: true]]]
        ]
      ]
    end

    test "child redefining a parent deprecated option: warns when given at parent level" do
      assert {:ok, %{options: %{key: "x"}}} =
               CLI.parse(~w(--key x sub), child_undeprecates_command())

      assert_deprecation_warning("key")
      refute_warnings()
    end

    test "child redefining a parent deprecated option: no warning when given at child level" do
      assert {:ok, %{options: %{key: "x"}}} =
               CLI.parse(~w(sub --key x), child_undeprecates_command())

      refute_warnings()
    end

    test "child redefining a parent deprecated option: shown in the child help" do
      assert :halt = CLI.parse_or_halt!(~w(sub --help), child_undeprecates_command())
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "--key"
      assert text =~ "Child key doc."
    end

    test "child deprecating a parent option: no warning when given at parent level" do
      assert {:ok, %{options: %{key: "x"}}} =
               CLI.parse(~w(--key x sub), child_deprecates_command())

      refute_warnings()
    end

    test "child deprecating a parent option: warns when given at child level" do
      assert {:ok, %{options: %{key: "x"}}} =
               CLI.parse(~w(sub --key x), child_deprecates_command())

      assert_deprecation_warning("key")
      refute_warnings()
    end

    test "child deprecating a parent option: hidden in the child help, shown in the root help" do
      assert :halt = CLI.parse_or_halt!(~w(sub --help), child_deprecates_command())
      assert_receive {:cli_mate_shell, :info, text}
      refute text =~ "--key"

      assert :halt = CLI.parse_or_halt!(~w(--help), child_deprecates_command())
      assert_receive {:cli_mate_shell, :info, text}
      assert text =~ "--key"
      assert text =~ "Parent key doc."
    end

    test "option deprecated at both levels with different messages warns once" do
      command = [
        options: [key: [type: :string, deprecated: "parent message"]],
        subcommands: [
          sub: [options: [key: [type: :string, deprecated: "child message"]]]
        ]
      ]

      assert {:ok, %{options: %{key: "y"}}} = CLI.parse(~w(--key x sub --key y), command)
      assert_deprecation_warning("key")
      refute_warnings()
    end

    test "sub-command execute receives the deprecated option value" do
      test_pid = self()

      command = [
        options: [old: [type: :string, deprecated: true]],
        subcommands: [
          sub: [execute: fn parsed -> send(test_pid, {:executed, parsed.options}) end]
        ]
      ]

      assert {:ok, %{execute: execute}} = CLI.parse(~w(--old x sub), command)
      execute.()
      assert_received {:executed, %{old: "x"}}
    end
  end
end
