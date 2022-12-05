defmodule CliMateTest do
  use ExUnit.Case, async: true

  defmodule CLI do
    use CliMate
  end

  @command [
    options: [
      gen_server: [
        type: :boolean,
        short: :g,
        doc: "bla bla bla",
        default: false
      ],
      supervisor: [
        type: :boolean,
        short: :s,
        doc: "bla bla bla",
        default: false
      ]
    ],
    arguments: [
      module: [
        required: true,
        cast: {Module, :concat, [[:"$1"]]}
      ]
    ]
  ]

  test "the shell can be set" do
    CLI.shell(CLI.ProcessShell)
    assert is_list(CLI.ProcessShell.module_info(:exports))
    CLI.error("this is an error")
    assert_receive {CLI, :error, "this is an error"}
  end
end
