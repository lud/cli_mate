defmodule CliMate.CLI.OptionInheritanceTest do
  alias CliMate.CLI
  alias CliMate.CLI.Command
  alias CliMate.CLI.ProcessShell
  use ExUnit.Case, async: true

  setup do
    CLI.put_shell(ProcessShell)
    :ok
  end

  defp upcase(value), do: {:ok, String.upcase(value)}
  defp to_integer(value), do: {:ok, String.to_integer(value)}

  defp usage_text(argv, command) do
    assert :halt = CLI.parse_or_halt!(argv, command)
    assert_receive {:cli_mate_shell, :info, text}

    text
    |> IO.ANSI.format(_emit = false)
    |> IO.iodata_to_binary()
  end

  defp option_lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "-"))
  end

  describe "duplicate shorts on a single level" do
    test "raise when the command is built" do
      assert_raise ArgumentError,
                   "options :a and :b use the same short :x in command",
                   fn -> Command.new(options: [a: [short: :x], b: [short: :x]]) end
    end

    test "raise when a sub-command is resolved" do
      cmd = [subcommands: [sub: [options: [a: [short: :x], b: [short: :x]]]]]

      assert_raise ArgumentError, ~r/options :a and :b use the same short :x/, fn ->
        CLI.parse(~w(sub), cmd)
      end
    end

    test "are allowed in sibling sub-commands" do
      cmd = [
        subcommands: [
          one: [options: [foo: [type: :string, short: :x]]],
          two: [options: [bar: [type: :string, short: :x]]]
        ]
      ]

      assert {:ok, %{options: %{foo: "v"}}} = CLI.parse(~w(one -x v), cmd)
      assert {:ok, %{options: %{bar: "v"}}} = CLI.parse(~w(two -x v), cmd)
    end
  end

  describe "child short shadows a parent short on a different key" do
    defp shadowing_command do
      [
        name: "cmd",
        options: [
          pkey: [type: :string, short: :x, doc: "Parent key."],
          other: [type: :string, short: :o, doc: "Other parent option."]
        ],
        subcommands: [
          sub: [
            name: "cmd-sub",
            options: [ckey: [type: :string, short: :x, doc: "Child key."]]
          ]
        ]
      ]
    end

    test "the short given after the sub-command name sets the child option" do
      assert {:ok, %{options: options}} = CLI.parse(~w(sub -x C), shadowing_command())
      assert %{ckey: "C"} = options
      refute Map.has_key?(options, :pkey)
    end

    test "the short given before the sub-command name sets the parent option" do
      assert {:ok, %{options: options}} = CLI.parse(~w(-x P sub), shadowing_command())
      assert %{pkey: "P"} = options
      refute Map.has_key?(options, :ckey)
    end

    test "the short can be given on both sides" do
      assert {:ok, %{options: %{pkey: "P", ckey: "C"}}} =
               CLI.parse(~w(-x P sub -x C), shadowing_command())
    end

    test "the shadowed parent option is still available by its long name" do
      assert {:ok, %{options: %{pkey: "P", ckey: "C"}}} =
               CLI.parse(~w(sub --pkey P -x C), shadowing_command())
    end

    test "other parent shorts are still inherited" do
      assert {:ok, %{options: %{other: "O"}}} = CLI.parse(~w(sub -o O), shadowing_command())
    end

    test "works with different types on both sides" do
      cmd = [
        options: [pflag: [type: :boolean, short: :x]],
        subcommands: [
          sub: [
            options: [cval: [type: :string, short: :x]],
            arguments: [file: [required: false]]
          ]
        ]
      ]

      assert {:ok, %{options: options, arguments: arguments}} = CLI.parse(~w(sub -x C), cmd)
      assert %{cval: "C"} = options
      refute Map.has_key?(options, :pflag)
      assert arguments == %{}

      assert {:ok, %{options: %{pflag: true}, arguments: %{file: "F"}}} =
               CLI.parse(~w(-x sub F), cmd)
    end

    test "a grandchild shadows a root short through an intermediate level" do
      cmd = [
        options: [root_key: [type: :string, short: :x]],
        subcommands: [
          mid: [
            subcommands: [
              leaf: [options: [leaf_key: [type: :string, short: :x]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{root_key: "M"}}} = CLI.parse(~w(mid -x M leaf), cmd)
      assert {:ok, %{options: %{leaf_key: "L"}}} = CLI.parse(~w(mid leaf -x L), cmd)
    end

    test "an intermediate level shadow applies to its own sub-commands" do
      cmd = [
        options: [root_key: [type: :string, short: :x]],
        subcommands: [
          mid: [
            options: [mid_key: [type: :string, short: :x]],
            subcommands: [leaf: []]
          ]
        ]
      ]

      assert {:ok, %{options: %{root_key: "R", mid_key: "M"}}} =
               CLI.parse(~w(-x R mid leaf -x M), cmd)
    end

    test "a child redefinition can take the short of another parent option" do
      cmd = [
        options: [
          alpha: [type: :string],
          beta: [type: :string, short: :y]
        ],
        subcommands: [sub: [options: [alpha: [type: :string, short: :y]]]]
      ]

      assert {:ok, %{options: options}} = CLI.parse(~w(sub -y v), cmd)
      assert %{alpha: "v"} = options
      refute Map.has_key?(options, :beta)

      assert {:ok, %{options: %{beta: "v"}}} = CLI.parse(~w(-y v sub), cmd)
    end

    test "a child redefinition releasing a short lets another child option use it" do
      cmd = [
        options: [pkey: [type: :string, short: :x]],
        subcommands: [
          sub: [
            options: [
              pkey: [type: :string],
              ckey: [type: :string, short: :x]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{ckey: "C"}}} = CLI.parse(~w(sub -x C), cmd)
      assert {:ok, %{options: %{pkey: "P"}}} = CLI.parse(~w(-x P sub), cmd)
    end

    test "sub-command help shows the short on the child option only" do
      lines = option_lines(usage_text(~w(sub --help), shadowing_command()))

      assert "--pkey <string>" in lines
      assert "-x, --ckey <string>" in lines
      assert "-o, --other <string>" in lines
    end

    test "root help still shows the parent short" do
      lines = option_lines(usage_text(~w(--help), shadowing_command()))
      assert "-x, --pkey <string>" in lines
    end
  end

  describe "child redefinition replaces the parent entry" do
    test "parent default does not leak when the child has no default" do
      cmd = [
        options: [key: [type: :string, default: "pdef"]],
        subcommands: [sub: [options: [key: [type: :string]]]]
      ]

      assert {:ok, %{options: options}} = CLI.parse(~w(sub), cmd)
      refute Map.has_key?(options, :key)
    end

    test "parent default does not leak through an intermediate level" do
      cmd = [
        options: [key: [type: :string, default: "pdef"]],
        subcommands: [
          mid: [subcommands: [leaf: [options: [key: [type: :string]]]]]
        ]
      ]

      assert {:ok, %{options: options}} = CLI.parse(~w(mid leaf), cmd)
      refute Map.has_key?(options, :key)
    end

    test "parent default applies when stopping at the parent level" do
      cmd = [
        options: [key: [type: :string, default: "pdef"]],
        subcommands: [sub: [options: [key: [type: :string]]]]
      ]

      assert {:ok, %{options: %{key: "pdef", help: true}}} = CLI.parse(~w(--help), cmd)
    end

    test "keep option redefined without default gets an empty list" do
      cmd = [
        options: [tags: [type: :string, keep: true, default: ["pdef"]]],
        subcommands: [sub: [options: [tags: [type: :string, keep: true]]]]
      ]

      assert {:ok, %{options: %{tags: []}}} = CLI.parse(~w(sub), cmd)
    end

    test "child default is used when the option is not given" do
      cmd = [
        options: [key: [type: :string, default: "pdef"]],
        subcommands: [sub: [options: [key: [type: :string, default: "cdef"]]]]
      ]

      assert {:ok, %{options: %{key: "cdef"}}} = CLI.parse(~w(sub), cmd)
    end

    test "child default function receives the option key" do
      cmd = [
        options: [key: [type: :string, default: "pdef"]],
        subcommands: [
          sub: [options: [key: [type: :string, default: &{:from_child, &1}]]]
        ]
      ]

      assert {:ok, %{options: %{key: {:from_child, :key}}}} = CLI.parse(~w(sub), cmd)
    end

    test "a value given before the sub-command name wins over the child default" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :string, default: "cdef"]]]]
      ]

      assert {:ok, %{options: %{key: "given"}}} = CLI.parse(~w(--key given sub), cmd)
    end

    test "child without short drops the parent short after the sub-command name" do
      cmd = [
        options: [key: [type: :string, short: :k]],
        subcommands: [sub: [options: [key: [type: :string]]]]
      ]

      assert {:error, {:invalid, [{"-k", _}]}} = CLI.parse(~w(sub -k v), cmd)
      assert {:ok, %{options: %{key: "v"}}} = CLI.parse(~w(-k v sub), cmd)
      assert {:ok, %{options: %{key: "v"}}} = CLI.parse(~w(sub --key v), cmd)
    end

    test "child short is only available after the sub-command name" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :string, short: :k]]]]
      ]

      assert {:ok, %{options: %{key: "v"}}} = CLI.parse(~w(sub -k v), cmd)
      assert {:error, {:invalid, [{"-k", _}]}} = CLI.parse(~w(-k v sub), cmd)
    end

    test "child cast applies to a value given before the sub-command name" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :string, cast: &upcase/1]]]]
      ]

      assert {:ok, %{options: %{key: "V"}}} = CLI.parse(~w(--key v sub), cmd)
      assert {:ok, %{options: %{key: "V"}}} = CLI.parse(~w(sub --key v), cmd)
    end

    test "parent cast does not apply when the child redefines without cast" do
      cmd = [
        options: [key: [type: :string, cast: &upcase/1]],
        subcommands: [sub: [options: [key: [type: :string]]]]
      ]

      assert {:ok, %{options: %{key: "v"}}} = CLI.parse(~w(--key v sub), cmd)
      assert {:ok, %{options: %{key: "V"}}} = CLI.parse(~w(--key v --help), cmd)
    end

    test "child cast can turn a string option into another type" do
      cmd = [
        options: [level: [type: :string]],
        subcommands: [sub: [options: [level: [type: :string, cast: &to_integer/1]]]]
      ]

      assert {:ok, %{options: %{level: 3}}} = CLI.parse(~w(--level 3 sub), cmd)
      assert {:ok, %{options: %{level: "3"}}} = CLI.parse(~w(--level 3 --help), cmd)
    end

    test "child cast is applied to every value of a keep option across levels" do
      cmd = [
        options: [tags: [type: :string, keep: true]],
        subcommands: [sub: [options: [tags: [type: :string, keep: true, cast: &upcase/1]]]]
      ]

      assert {:ok, %{options: %{tags: ["A", "B", "C"]}}} =
               CLI.parse(~w(--tags a sub --tags b --tags c), cmd)
    end

    test "child cast error on a value given before the sub-command name" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [
          sub: [options: [key: [type: :string, cast: fn _ -> {:error, "bad key"} end]]]
        ]
      ]

      assert {:error, {:option_cast, :key, "bad key"}} = CLI.parse(~w(--key v sub), cmd)
    end

    test "cast error is reported with the sub-command usage" do
      cmd = [
        name: "cmd",
        options: [key: [type: :string]],
        subcommands: [
          sub: [
            name: "cmd-sub",
            options: [key: [type: :string, cast: fn _ -> {:error, "bad key"} end]]
          ]
        ]
      ]

      assert :halt = CLI.parse_or_halt!(~w(--key v sub), cmd)
      assert_receive {:cli_mate_shell, :info, usage}
      assert IO.iodata_to_binary(IO.ANSI.format(usage, false)) =~ "cmd-sub"
      assert_receive {:cli_mate_shell, :error, error}
      assert error =~ "bad key"
    end

    test "grandchild redefinition applies through an intermediate level" do
      cmd = [
        options: [key: [type: :string, short: :k, default: "root"]],
        subcommands: [
          mid: [
            subcommands: [
              leaf: [options: [key: [type: :string, cast: &upcase/1]]]
            ]
          ]
        ]
      ]

      assert {:ok, %{options: %{key: "V"}}} = CLI.parse(~w(-k v mid leaf), cmd)
      assert {:ok, %{options: %{key: "V"}}} = CLI.parse(~w(mid -k v leaf), cmd)
      assert {:error, {:invalid, [{"-k", _}]}} = CLI.parse(~w(mid leaf -k v), cmd)
      assert {:ok, %{options: options}} = CLI.parse(~w(mid leaf), cmd)
      refute Map.has_key?(options, :key)
    end

    test "sub-command help shows the child definition" do
      cmd = [
        name: "cmd",
        options: [key: [type: :string, short: :k, doc: "Parent doc.", default: "pdef"]],
        subcommands: [
          sub: [name: "cmd-sub", options: [key: [type: :string, doc: "Child doc."]]]
        ]
      ]

      text = usage_text(~w(sub --help), cmd)
      assert text =~ "Child doc."
      refute text =~ "Parent doc."
      refute text =~ "pdef"
      assert "--key <string>" in option_lines(text)
    end
  end

  describe "redefinition with a different type or keep" do
    test "raises on a type change" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :boolean]]]]
      ]

      assert_raise ArgumentError,
                   ~s(option :key is redefined with type: :boolean in sub-command "sub" ) <>
                     "but has type: :string in its parent command",
                   fn -> CLI.parse(~w(sub), cmd) end
    end

    test "raises on a change from non-keep to keep" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :string, keep: true]]]]
      ]

      assert_raise ArgumentError,
                   ~s(option :key is redefined with keep: true in sub-command "sub" ) <>
                     "but has keep: false in its parent command",
                   fn -> CLI.parse(~w(sub), cmd) end
    end

    test "raises on a change from keep to non-keep" do
      cmd = [
        options: [key: [type: :string, keep: true]],
        subcommands: [sub: [options: [key: [type: :string]]]]
      ]

      assert_raise ArgumentError, ~r/redefined with keep: false/, fn ->
        CLI.parse(~w(--key a sub), cmd)
      end
    end

    test "reports the type when both type and keep change" do
      cmd = [
        options: [key: [type: :string, keep: true]],
        subcommands: [sub: [options: [key: [type: :integer]]]]
      ]

      assert_raise ArgumentError, ~r/redefined with type: :integer/, fn ->
        CLI.parse(~w(sub), cmd)
      end
    end

    test "raises between count and boolean" do
      cmd = [
        options: [verbose: [type: :count, short: :v]],
        subcommands: [sub: [options: [verbose: [type: :boolean, short: :v]]]]
      ]

      assert_raise ArgumentError, ~r/redefined with type: :boolean/, fn ->
        CLI.parse(~w(-vvv sub), cmd)
      end
    end

    test "reports the full sub-command path" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [
          mid: [subcommands: [leaf: [options: [key: [type: :integer]]]]]
        ]
      ]

      assert_raise ArgumentError, ~r/in sub-command "mid leaf"/, fn ->
        CLI.parse(~w(mid leaf), cmd)
      end
    end

    test "compares with the closest definition" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [
          mid: [
            options: [key: [type: :string]],
            subcommands: [leaf: [options: [key: [type: :integer]]]]
          ]
        ]
      ]

      assert {:ok, _} = CLI.parse(~w(mid --help), cmd)

      assert_raise ArgumentError, ~r/type: :integer in sub-command "mid leaf"/, fn ->
        CLI.parse(~w(mid leaf), cmd)
      end
    end

    test "raises when printing the sub-command help" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: [options: [key: [type: :integer]]]]
      ]

      assert_raise ArgumentError, ~r/redefined with type/, fn ->
        CLI.parse_or_halt!(~w(sub --help), cmd)
      end
    end

    test "does not raise when only other settings change" do
      cmd = [
        options: [
          key: [
            type: :integer,
            short: :k,
            doc: "Parent.",
            default: 1,
            cast: &{:ok, &1 * 10},
            deprecated: true
          ]
        ],
        subcommands: [
          sub: [options: [key: [type: :integer, doc: "Child.", default: 2, doc_arg: "n"]]]
        ]
      ]

      assert {:ok, %{options: %{key: 2}}} = CLI.parse(~w(sub), cmd)
      assert {:ok, %{options: %{key: 5}}} = CLI.parse(~w(-k 5 sub), cmd)
    end
  end

  describe "values given on several levels" do
    test "scalar: the last given value wins" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{key: "a"}}} = CLI.parse(~w(--key a sub), cmd)
      assert {:ok, %{options: %{key: "b"}}} = CLI.parse(~w(sub --key b), cmd)
      assert {:ok, %{options: %{key: "b"}}} = CLI.parse(~w(--key a sub --key b), cmd)
      assert {:ok, %{options: %{key: "b"}}} = CLI.parse(~w(--key x --key a sub --key b), cmd)
      assert {:ok, %{options: %{key: "b"}}} = CLI.parse(~w(--key a --key b sub), cmd)
    end

    test "scalar: the last value wins across three levels" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [mid: [subcommands: [leaf: []]]]
      ]

      assert {:ok, %{options: %{key: "m"}}} = CLI.parse(~w(--key r mid --key m leaf), cmd)
      assert {:ok, %{options: %{key: "l"}}} = CLI.parse(~w(--key r mid leaf --key l), cmd)
    end

    test "integer: same result on both sides of the sub-command name" do
      cmd = [
        options: [num: [type: :integer]],
        subcommands: [sub: [options: [num: [type: :integer]]]]
      ]

      assert {:ok, %{options: %{num: 5}}} = CLI.parse(~w(--num 5 sub), cmd)
      assert {:ok, %{options: %{num: 5}}} = CLI.parse(~w(sub --num 5), cmd)
    end

    test "boolean: the last given value wins" do
      cmd = [
        options: [flag: [type: :boolean, default: true]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{flag: false}}} = CLI.parse(~w(--flag sub --no-flag), cmd)
      assert {:ok, %{options: %{flag: true}}} = CLI.parse(~w(--no-flag sub --flag), cmd)
      assert {:ok, %{options: %{flag: false}}} = CLI.parse(~w(--no-flag sub), cmd)
    end

    test "keep: values are accumulated in order" do
      cmd = [
        options: [tag: [type: :string, keep: true, short: :t]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{tag: ["a"]}}} = CLI.parse(~w(--tag a sub), cmd)
      assert {:ok, %{options: %{tag: ["b"]}}} = CLI.parse(~w(sub --tag b), cmd)

      assert {:ok, %{options: %{tag: ["a", "b", "c", "d"]}}} =
               CLI.parse(~w(--tag a -t b sub -t c --tag d), cmd)
    end

    test "keep: values are accumulated across three levels" do
      cmd = [
        options: [tag: [type: :integer, keep: true]],
        subcommands: [mid: [subcommands: [leaf: []]]]
      ]

      assert {:ok, %{options: %{tag: [1, 2, 3, 4]}}} =
               CLI.parse(~w(--tag 1 mid --tag 2 --tag 3 leaf --tag 4), cmd)
    end

    test "keep: default applies only when no level gives a value" do
      cmd = [
        options: [tag: [type: :string, keep: true, default: ["def"]]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{tag: ["def"]}}} = CLI.parse(~w(sub), cmd)
      assert {:ok, %{options: %{tag: ["a"]}}} = CLI.parse(~w(--tag a sub), cmd)
    end

    test "keep: empty list when not given and no default" do
      cmd = [
        options: [tag: [type: :string, keep: true]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{tag: []}}} = CLI.parse(~w(sub), cmd)
    end

    test "count: occurrences are summed across levels" do
      cmd = [
        options: [verbose: [type: :count, short: :v]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{verbose: 3}}} = CLI.parse(~w(-vvv sub), cmd)
      assert {:ok, %{options: %{verbose: 3}}} = CLI.parse(~w(sub -vvv), cmd)
      assert {:ok, %{options: %{verbose: 3}}} = CLI.parse(~w(-v sub -vv), cmd)
      assert {:ok, %{options: %{verbose: 3}}} = CLI.parse(~w(--verbose --verbose sub -v), cmd)
    end

    test "count: occurrences are summed across three levels" do
      cmd = [
        options: [verbose: [type: :count, short: :v]],
        subcommands: [
          mid: [
            options: [verbose: [type: :count, short: :v]],
            subcommands: [leaf: []]
          ]
        ]
      ]

      assert {:ok, %{options: %{verbose: 4}}} = CLI.parse(~w(-v mid -vv leaf -v), cmd)
    end

    test "count: default applies only when no level gives a value" do
      cmd = [
        options: [verbose: [type: :count, short: :v, default: 0]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{verbose: 0}}} = CLI.parse(~w(sub), cmd)
      assert {:ok, %{options: %{verbose: 1}}} = CLI.parse(~w(-v sub), cmd)
    end

    test "count: parent cast does not see partial counts" do
      cmd = [
        options: [verbose: [type: :count, short: :v, cast: &{:ok, {:level, &1}}]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{verbose: {:level, 3}}}} = CLI.parse(~w(-v sub -vv), cmd)
    end

    test "cast is called once on the final value" do
      test_pid = self()

      cast = fn value ->
        send(test_pid, {:cast, value})
        {:ok, value}
      end

      cmd = [
        options: [key: [type: :string, cast: cast]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{key: "b"}}} = CLI.parse(~w(--key a sub --key b), cmd)
      assert_received {:cast, "b"}
      refute_received {:cast, _}
    end
  end

  describe "--help on sub-command levels" do
    test "intermediate help returns values given before it" do
      cmd = [
        options: [key: [type: :string]],
        subcommands: [mid: [subcommands: [leaf: []]]]
      ]

      assert {:ok, %{options: %{key: "v", help: true}, path: [:mid]}} =
               CLI.parse(~w(--key v mid --help), cmd)
    end

    test "intermediate help returns no execute" do
      cmd = [
        subcommands: [
          mid: [execute: fn _ -> :ran end, subcommands: [leaf: []]]
        ]
      ]

      assert {:ok, %{options: %{help: true}, path: [:mid], execute: nil}} =
               CLI.parse(~w(mid --help), cmd)
    end

    test "help given before the sub-command name returns the parent help" do
      cmd = [subcommands: [sub: [options: [key: [type: :string]]]]]

      assert {:ok, %{options: %{help: true}, path: []}} = CLI.parse(~w(--help sub), cmd)
    end

    test "help wins over errors from any level" do
      cmd = [
        options: [num: [type: :integer, cast: fn _ -> {:error, "bad num"} end]],
        subcommands: [
          mid: [
            options: [flag: [type: :boolean]],
            subcommands: [leaf: [arguments: [file: []]]]
          ]
        ]
      ]

      assert {:ok, %{options: %{help: true}, path: [:mid, :leaf]}} =
               CLI.parse(~w(--num 1 mid leaf --help), cmd)

      assert {:ok, %{options: %{help: true}, path: [:mid]}} =
               CLI.parse(~w(--num 1 mid --unknown --help), cmd)

      assert {:ok, %{options: %{help: true}, path: [:mid, :leaf]}} =
               CLI.parse(~w(mid leaf --flag nope --help), cmd)
    end
  end

  describe "deprecated options use the final definition" do
    test "warns once for a parent deprecated option given on several levels" do
      cmd = [
        options: [old: [type: :count, deprecated: true]],
        subcommands: [sub: []]
      ]

      assert {:ok, %{options: %{old: 2}}} = CLI.parse(~w(--old sub --old), cmd)
      assert_received {:cli_mate_shell, :warn, message}
      assert message =~ "--old"
      refute_received {:cli_mate_shell, :warn, _}
    end

    test "uses the child deprecation message" do
      cmd = [
        options: [key: [type: :string, deprecated: "parent message"]],
        subcommands: [sub: [options: [key: [type: :string, deprecated: "child message"]]]]
      ]

      assert {:ok, _} = CLI.parse(~w(--key x sub), cmd)
      assert_received {:cli_mate_shell, :warn, message}
      assert message =~ "child message"
      refute_received {:cli_mate_shell, :warn, _}
    end
  end
end
