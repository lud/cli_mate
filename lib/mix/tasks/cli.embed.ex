defmodule Mix.Tasks.Cli.Embed do
  alias CliMate.CLI
  alias CliMate.Embed
  use Mix.Task

  @shortdoc "Copies the CLI code into your own application."

  @command module: __MODULE__,
           doc: @shortdoc,
           options: [
             extend: [
               type: :boolean,
               default: false,
               doc: """
               When true, the base CLI module will be defined as `<prefix>.Base`
               and will export an extend/0 macro. You will have to define your
               main CLI module and call `require(<prefix>.Base).extend()` from
               there.

               When false, the command will define the main CLI module as
               `<prefix>` directly. The `extend/0` macro is still included.
               """
             ],
             skip_docs: [
               type: :boolean,
               default: false,
               doc: """
               When true, replaces the `@moduledoc`, `@doc` and `@typedoc`
               strings with `false` in all generated modules.
               """
             ],
             moduledoc: [
               type: :boolean,
               default: true,
               deprecated: "use --skip-docs instead"
             ],
             force: [
               type: :boolean,
               default: false,
               short: :f,
               doc: """
               Actually writes generated code to disk. Without this option the
               command only prints debug information.
               """
             ],
             yes: [
               type: :boolean,
               default: false,
               short: :y,
               doc: """
               Automatically accept prompts to overwrite files.
               """
             ]
           ],
           arguments: [
             prefix: [
               doc: """
               The root namespace for the generated modules.
               Example: MyApp.CLI.
               """
             ],
             path: [
               doc: """
               The base directory for the generated modules. When the --extend
               option is not provided, the base module is defined as <path>.ex,
               that is outside of said directory.
               """
             ]
           ]

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """

  @doc false
  def command, do: @command

  @impl true
  def run(argv) do
    %{options: opts, arguments: args} = CLI.parse_or_halt!(argv, @command)

    args
    |> Embed.config(opts)
    |> Embed.generate()
    |> Enum.each(&handle_file(&1, opts))
  end

  defp handle_file(file, opts) do
    target_exists? = File.exists?(file.path)

    cond do
      opts.force ->
        maybe_write_file(target_exists?, file, opts)

      target_exists? ->
        CLI.writeln("would create #{file.path} (exists)")

      :other ->
        CLI.writeln("would create #{file.path}")
    end
  end

  defp ask_overwrite(path) do
    Mix.Shell.IO.yes?("file #{path} exists, overwrite?", default: :no)
  end

  defp maybe_write_file(true = _target_exists?, file, opts) do
    if opts.yes || ask_overwrite(file.path) do
      Embed.write_file!(file)
      CLI.writeln("created #{file.path} (overwrite)")
    else
      CLI.warn("skipped file #{file.path} (exists)")
    end
  end

  defp maybe_write_file(false = _target_exists?, file, _opts) do
    Embed.write_file!(file)
    CLI.writeln("created #{file.path}")
  end
end
