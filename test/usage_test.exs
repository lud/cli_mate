defmodule CliMate.CLI.UsageTest do
  alias CliMate.CLI
  use ExUnit.Case, async: true

  def no_ansi(iodata) do
    IO.ANSI.format(iodata)

    # |> IO.puts()

    iodata
    |> IO.ANSI.format(_emit = false)
    |> :erlang.iolist_to_binary()
  end

  def some_default(_), do: nil

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
