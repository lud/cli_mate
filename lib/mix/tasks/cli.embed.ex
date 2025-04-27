defmodule Mix.Tasks.Cli.Embed do
  alias CliMate.CLI
  use Mix.Task

  @command module: __MODULE__,
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
             moduledoc: [
               type: :boolean,
               default: true,
               doc: """
               When true, include @moduledoc attributes in the generated code.
               When false, defines `@moduledoc false` in all generated modules.
               """
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
               option is not provided, the base module is definied as <path>.ex,
               that is outside of said directory.
               """
             ]
           ]

  @shortdoc "Copy the CLI code into your own application"

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """

  @impl true
  def run(argv) do
    %{options: opts, arguments: args} = CLI.parse_or_halt!(argv, @command)

    namespace_replacement =
      args.prefix
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)

    alias_replacement =
      if opts.extend do
        {namespace_replacement, namespace_replacement ++ [:Base]}
      else
        {namespace_replacement, namespace_replacement}
      end

    target_root_path = Path.absname(args.path)

    source_root_path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("../../cli_mate/cli")
      |> Path.expand()

    source_root_size = byte_size(source_root_path)

    source_specs =
      source_root_path
      |> Path.join("**/*.ex")
      |> Path.wildcard()
      |> Enum.map(fn source_path ->
        <<^source_root_path::binary-size(source_root_size), target_sub_path::binary>> =
          source_path

        target_path = Path.relative_to_cwd(target_root_path <> target_sub_path)

        %{
          source_path: source_path,
          target_path: target_path,
          source_code: read_source(source_path, opts),
          alias_replacement: alias_replacement
        }
      end)

    main_source = source_root_path <> ".ex"

    main_file_spec =
      if opts.extend do
        %{
          source_path: main_source,
          target_path: target_root_path <> "/base.ex",
          source_code: read_source(main_source, opts),
          alias_replacement: alias_replacement
        }
      else
        %{
          source_path: main_source,
          target_path: target_root_path <> ".ex",
          source_code: read_source(main_source, opts),
          alias_replacement: alias_replacement
        }
      end

    source_specs = [main_file_spec | source_specs]

    Enum.each(source_specs, &handle_source(&1, opts))
  end

  defp handle_source(spec, opts) do
    target_exists? = File.exists?(spec.target_path)

    cond do
      opts.force ->
        maybe_write_module(target_exists?, spec, opts)

      target_exists? ->
        CLI.writeln("would create #{spec.target_path} (exists)")

      :other ->
        CLI.writeln("would create #{spec.target_path}")
    end
  end

  defp ask_overwrite(target_path) do
    Mix.Shell.IO.yes?("file #{target_path} exists, overwrite?", default: :no)
  end

  defp maybe_write_module(true = _target_exists?, spec, opts) do
    if opts.yes || ask_overwrite(spec.target_path) do
      :ok = write_module(spec, opts)
      CLI.writeln("created #{spec.target_path} (overwrite)")
    else
      CLI.warn("skipped file #{spec.target_path} (exists)")
    end
  end

  defp maybe_write_module(false = _target_exists?, spec, opts) do
    :ok = write_module(spec, opts)
    CLI.writeln("created #{spec.target_path}")
  end

  defp write_module(spec, opts) do
    module_code = generate_module(spec, opts)
    File.mkdir_p!(Path.dirname(spec.target_path))
    File.write!(spec.target_path, module_code)
  end

  defp generate_module(spec, opts) do
    {forms, comments} =
      Code.string_to_quoted_with_comments!(spec.source_code,
        token_metadata: true,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        unescape: false,
        columns: true
      )

    fmt_opts = formatter_options()
    line_length = Keyword.get(fmt_opts, :line_length, 98)

    forms =
      if opts.moduledoc do
        forms
      else
        Macro.postwalk(forms, &strip_docs/1)
      end

    forms = Macro.postwalk(forms, &replace_aliases(&1, spec.alias_replacement))

    forms
    |> Code.quoted_to_algebra(
      [comments: comments, migrate_charlists_as_sigils: true, escape: false] ++
        formatter_options()
    )
    |> Inspect.Algebra.format(line_length)
    |> IO.iodata_to_binary()
  end

  defp strip_docs({:moduledoc, meta, _}), do: {:moduledoc, meta, [false]}

  defp strip_docs({:@, attr_meta, [{:doc_if_moduledoc, skip_meta, value}]})
       when not is_nil(value) do
    {:@, attr_meta, [{:doc_if_moduledoc, skip_meta, [{:__block__, skip_meta, [false]}]}]}
  end

  defp strip_docs(form), do: form

  # replacement of the exact alias
  defp replace_aliases({:__aliases__, meta, [:CliMate, :CLI]}, {_, main_mod_replacement}) do
    {:__aliases__, meta, main_mod_replacement}
  end

  # replacement of submodule
  defp replace_aliases({:__aliases__, meta, [:CliMate, :CLI | rest]}, {namespace_replacement, _}) do
    {:__aliases__, meta, namespace_replacement ++ rest}
  end

  defp replace_aliases(form, _), do: form

  defp formatter_options do
    path = ".formatter.exs"

    with true <- File.regular?(path),
         {opts, _} <- Code.eval_file(path),
         true <- Keyword.keyword?(opts) do
      Keyword.take(opts, [:locals_without_parens])
    else
      _ -> []
    end
  end

  defp read_source(path, %{force: true}), do: File.read!(path)
  defp read_source(_path, _), do: []
end
