defmodule Mix.Tasks.Cli.Demo do
  use Mix.Task
  alias CliMate.CLI

  @impl Mix.Task
  def run(argv) do
    CLI.parse_or_halt!(argv,
      options: [
        name: [
          doc: "Displays a name"
        ]
      ],
      arguments: [arg_one: []]
    )
  end
end
