defmodule CliMate.UsageTest do
  use ExUnit.Case, async: true

  defmodule CLI do
    use CliMate
  end

  def stringify(iodata) do
    iodata
    |> IO.ANSI.format()

    iodata
    |> IO.ANSI.format(_emit = false)
    |> :erlang.iolist_to_binary()

    # Remove duplicated spaces to ease assrting/matching on strings
    |> String.replace(~r/ +/, " ")
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
          doc:
            "This is a very long documentation line and it should be wrapped on multiple lines if the terminal is short."
        ],
        with_default: [
          doc: "Some stuff.",
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
          default_doc: "Function in test"
        ],
        with_default_capture: [
          doc: "Some fun",
          default: &__MODULE__.some_default/1,
          default_doc: "Function capture in test"
        ]
      ],
      arguments: [
        name: [required: true],
        other: [required: false],
        another: [required: false]
      ]
    ]
  end

  def some_default(_), do: nil

  test "usage block can be formatted" do
    command = command_test_format()

    usage = CLI.format_usage(command, io_columns: 9_999_999) |> stringify()

    assert usage =~ "-l --lang <string> pick a language"
    assert usage =~ "--otp-vsn <integer> The OTP version."
    assert usage =~ "--with-name <some-name>"
    assert usage =~ "--with-name-bool The doc_arg is not used"
    assert usage =~ "--with-default <string> Some stuff. Defaults to nothing"
    assert usage =~ "mix some.command [options] <name> [<other> [<another>]]"
    assert usage =~ ~r"bool-with-default\s*Defaults to true."
    assert usage =~ "Function in test."
    assert usage =~ "Function capture in test."
  end

  test "usage block can be formatted for moduledoc" do
    command = command_test_format()

    _usage = CLI.format_usage(command, format: :moduledoc)
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
      |> stringify()
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
