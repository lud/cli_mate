defmodule CliMate.CLI.UsageTest do
  alias CliMate.CLI
  use ExUnit.Case, async: true

  def no_ansi(iodata) do
    iodata
    |> IO.ANSI.format()

    # |> IO.puts()

    iodata
    |> IO.ANSI.format(_emit = false)
    |> :erlang.iolist_to_binary()
  end

  defp command_test_format do
    [
      module: Mix.Tasks.Some.Command,
      options: [
        lang: [
          short: :l,
          type: :string,
          doc: "pick a language"
        ],
        otp_vsn: [type: :integer, doc: "The OTP version."],
        with_name: [doc_arg: "some-name"],
        with_name_bool: [doc_arg: "some-name", type: :boolean, doc: "The doc_arg is not used"],
        diatribe: [
          doc: """
          This is a very long documentation line and it should be wrapped on multiple lines if the terminal is short.



          """
        ],
        with_count_type: [
          doc: "I count.",
          type: :count,
          doc_arg: "should not be shown"
        ],
        with_default: [
          doc: """
          Some stuff.

          """,
          default: "nothing"
        ],
        bool_with_default: [
          type: :boolean,
          default: true
        ],
        bool_bare: [
          type: :boolean
        ],
        with_default_fun: [
          doc: "Some fun",
          # Output not tested but should not fail
          default: fn k -> some_default(k) end,
          default_doc: "Function in test."
        ],
        with_default_capture: [
          doc: "Some fun",
          default: &__MODULE__.some_default/1,
          default_doc: "Function capture in test."
        ],
        with_nil_default: [
          type: :string,
          default: nil
        ]
      ],
      arguments: [
        name: [
          required: true,
          doc: """
          The name of the thing.



          """
        ],
        other: [required: false],
        another: [required: false, doc: "Another argument"]
      ]
    ]
  end

  def some_default(_), do: nil

  test "usage block can be formatted in shell" do
    command = command_test_format()

    usage = CLI.format_usage(command, io_columns: 70) |> no_ansi()

    expected = """
    mix some.command

    Synopsis

      mix some.command [options] <name> [<other> [<another>]]

    Arguments

      name
      The name of the thing.

      other

      another
      Another argument

    Options

      -l, --lang <string>
            pick a language

          --otp-vsn <integer>
            The OTP version.

          --with-name <some-name>

          --with-name-bool
            The doc_arg is not used

          --diatribe <string>
            This is a very long documentation line and it should be
            wrapped on multiple lines if the terminal is short.

          --with-count-type (repeatable)
            I count.

          --with-default <string>
            Some stuff. Defaults to "nothing".

          --bool-with-default
            Defaults to true.

          --bool-bare

          --with-default-fun <string>
            Some fun Function in test.

          --with-default-capture <string>
            Some fun Function capture in test.

          --with-nil-default <string>
            Defaults to nil.

          --help
            Displays this help.
    """

    assert expected === no_ansi(usage)
  end

  test "use space if no option has short" do
    command = command_test_format()
    # Remove the lang option that has a short opt
    options = List.keydelete(Keyword.fetch!(command, :options), :lang, 0)
    command = Keyword.put(command, :options, options)

    usage = CLI.format_usage(command, io_columns: 70) |> no_ansi()

    expected = """
    mix some.command

    Synopsis

      mix some.command [options] <name> [<other> [<another>]]

    Arguments

      name
      The name of the thing.

      other

      another
      Another argument

    Options

      --otp-vsn <integer>
        The OTP version.

      --with-name <some-name>

      --with-name-bool
        The doc_arg is not used

      --diatribe <string>
        This is a very long documentation line and it should be wrapped on
        multiple lines if the terminal is short.

      --with-count-type (repeatable)
        I count.

      --with-default <string>
        Some stuff. Defaults to "nothing".

      --bool-with-default
        Defaults to true.

      --bool-bare

      --with-default-fun <string>
        Some fun Function in test.

      --with-default-capture <string>
        Some fun Function capture in test.

      --with-nil-default <string>
        Defaults to nil.

      --help
        Displays this help.
    """

    assert expected === no_ansi(usage)
  end

  test "usage block can be formatted for moduledoc" do
    command = command_test_format()

    usage = CLI.format_usage(command, format: :moduledoc)

    expected = """
    ## Synopsis

        mix some.command [options] <name> [<other> [<another>]]


    ## Arguments

    * `name`- The name of the thing.
    * `other`
    * `another`- Another argument


    ## Options

    * `-l, --lang <string>`- pick a language
    * `--otp-vsn <integer>`- The OTP version.
    * `--with-name <some-name>`
    * `--with-name-bool`- The doc_arg is not used
    * `--diatribe <string>`- This is a very long documentation line and it should be wrapped on multiple lines if the terminal is short.
    * `--with-count-type`- I count.
    * `--with-default <string>`- Some stuff. Defaults to `"nothing"`.
    * `--bool-with-default` Defaults to `true`.
    * `--bool-bare`
    * `--with-default-fun <string>`- Some fun Function in test.
    * `--with-default-capture <string>`- Some fun Function capture in test.
    * `--with-nil-default <string>` Defaults to `nil`.
    * `--help`- Displays this help.
    """

    assert expected === IO.chardata_to_string(usage)
  end

  test "usage block keeps options order" do
    command = [
      module: Mix.Tasks.Some.Command,
      options: [
        zzz: [short: :z, type: :string, doc: "zzz"],
        ccc: [short: :c, type: :string, doc: "ccc"],
        bbb: [short: :b, type: :string, doc: "bbb"],
        aaa: [short: :a, type: :string, doc: "aaa"]
      ]
    ]

    opts_doc =
      CLI.format_usage(command)
      |> no_ansi()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&String.starts_with?(&1, "-"))

    # Definition order is kept
    assert [
             "-z" <> _,
             "-c" <> _,
             "-b" <> _,
             "-a" <> _,
             "--help" <> _
           ] = opts_doc
  end
end
