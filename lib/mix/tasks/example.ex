defmodule Mix.Tasks.Example do
  alias CliMate.CLI
  use Mix.Task

  @command name: "mix example",
           options: [
             verbose: [
               short: :v,
               type: :boolean,
               default: false,
               doc: "Output debug info about the command."
             ]
           ],
           arguments: [
             n: [type: :integer],
             base: [cast: &__MODULE__.cast_base/1]
           ]

  @shortdoc "Formats an integer in base two or eight"

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """

  @impl true
  def run(argv) do
    %{options: opts, arguments: args} = CLI.parse_or_halt!(argv, @command)

    formatted = Integer.to_string(args.n, args.base)

    if opts.verbose do
      IO.puts("#{args.n} in base #{args.base} is #{formatted}")
    else
      IO.puts(formatted)
    end
  end

  def cast_base("two"), do: {:ok, 2}
  def cast_base("eight"), do: {:ok, 8}
  def cast_base(v), do: {:error, {:invalid_base, v}}
end
