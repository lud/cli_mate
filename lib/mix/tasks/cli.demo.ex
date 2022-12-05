defmodule Mix.Tasks.Cli.Demo do
  use Mix.Task
  alias CliMate.CLI

  @shortdoc "This is a playground command to try some features of CliMate"

  @impl Mix.Task
  def run(argv) do
    parsed =
      CLI.parse_or_halt!(argv,
        options: [
          name: [
            doc: "Displays a name"
          ]
        ],
        arguments: [qzf: []]
      )

    parsed |> IO.inspect(label: "parsed")
  end
end
