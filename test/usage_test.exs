defmodule CliMate.UsageTest do
  use ExUnit.Case, async: true

  defmodule CLI do
    use CliMate
  end

  def stringify(iodata) do
    iodata
    |> IO.ANSI.format()
    |> IO.puts()

    iodata
    |> IO.ANSI.format(_emit = false)
    |> :erlang.iolist_to_binary()

    # Remove duplicated spaces to ease assrting/matching on strings
    |> String.replace(~r/ +/, " ")
  end

  test "usage block can be formatted" do
    command = [
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
        ]
      ],
      arguments: [
        name: [required: true],
        other: [required: false],
        another: [required: false]
      ]
    ]

    usage = CLI.format_usage(command) |> stringify() |> tap(&IO.puts/1)

    assert usage =~ "-l --lang <value> pick a language"
    assert usage =~ "--otp-vsn <value> The OTP version."
    assert usage =~ "--with-name <some-name>"
    assert usage =~ "--with-name-bool The doc_arg is not used"
    assert usage =~ "--with-default <value> Some stuff. Defaults to nothing"
    assert usage =~ "mix some.command [options] <name> [<other> [<another>]]"
    assert usage =~ ~r"bool-with-default.*Defaults to true."
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
