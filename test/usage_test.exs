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
    |> IO.ANSI.format(false)
    |> :erlang.iolist_to_binary()
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
        diatribe: [
          doc:
            "This is a very long documentation line and it should be wrapped on multiple lines if the terminal is short."
        ],
        with_default: [
          doc: "Some stuff.",
          default: "nothing"
        ]
      ],
      arguments: [
        name: [required: true],
        other: [required: false],
        another: [required: false]
      ]
    ]

    usage = CLI.format_usage(command) |> stringify()

    assert usage =~ "-l --lang pick a language"
    assert usage =~ "--otp-vsn The OTP version."
    assert usage =~ "--with-default Some stuff. Defaults to nothing"
    assert usage =~ "mix some.command [options] <name> [<other> [<another>]]"
  end
end
