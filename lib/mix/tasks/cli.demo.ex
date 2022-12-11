defmodule Mix.Tasks.Cli.Demo do
  @moduledoc false
  use Mix.Task
  alias CliMate.CLI

  @command [
    options: [
      name: [
        doc: "Displays a name.",
        short: :n
      ],
      very_long_name: [doc: "This option has a very long name.", default: "Some default string"],
      docdoc: [
        doc: "This option has a very long documentation line that most likely spans multiple
          lines, but hopefully good wrapping will keep it readable."
      ]
    ],
    arguments: [arg_one: []]
  ]

  # @usage CLI.format_usage(@command, format: :moduledoc)

  @impl Mix.Task
  def run(argv) do
    CLI.parse_or_halt!(
      argv,
      @command
    )
  end
end
