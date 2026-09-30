defmodule Mix.Tasks.Cli.Embed.Check do
  alias CliMate.CLI
  alias CliMate.Embed
  use Mix.Task

  @shortdoc "Checks that the CLI code copied by cli.embed is up to date."

  @command module: __MODULE__,
           doc: @shortdoc,
           options: [
             fix: [
               type: :boolean,
               default: false,
               doc: """
               Regenerates the embeds that are out of date and deletes their
               stale files.
               """
             ]
           ],
           arguments: [
             path: [
               required: false,
               doc: """
               The base directory of an embed, as given to cli.embed. Limits the
               check to that embed. By default, all the compilation paths of the
               project are scanned.
               """
             ]
           ]

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """

  @impl true
  def run(argv) do
    %{options: opts, arguments: args} = CLI.parse_or_halt!(argv, @command)
    path = if args[:path], do: Embed.normalize_path(args.path)

    case path |> scan_files() |> find_banner_commands() |> parse_commands() do
      {:error, message} -> CLI.halt_error(message)
      {:ok, []} -> report_nothing_found(path)
      {:ok, parsed} -> check_parsed(parsed, path, opts.fix)
    end
  end

  defp check_parsed(parsed, path, fix?) do
    case group_embeds(parsed) do
      {:error, message} ->
        CLI.halt_error(message)

      {:ok, embeds} ->
        embeds = Enum.map(embeds, &check_embed/1)

        if fix?,
          do: Enum.each(embeds, &fix_embed/1),
          else: report(embeds, path)
    end
  end

  defp scan_files(nil) do
    Mix.Project.config()[:elixirc_paths]
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.ex")))
    |> Enum.map(&Embed.normalize_path/1)
    |> Enum.uniq()
  end

  defp scan_files(path) do
    files =
      Path.wildcard(Path.join(path, "**/*.ex")) ++ Enum.filter([path <> ".ex"], &File.regular?/1)

    Enum.map(files, &Embed.normalize_path/1)
  end

  defp find_banner_commands(paths) do
    Enum.flat_map(paths, fn path ->
      case Embed.banner_command(File.read!(path)) do
        {:ok, command} -> [{command, path}]
        :error -> []
      end
    end)
  end

  defp parse_commands(commands_and_paths) do
    commands_and_paths
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce_while({:ok, []}, fn {command, paths}, {:ok, acc} ->
      case CLI.parse(OptionParser.split(command), Mix.Tasks.Cli.Embed.command()) do
        {:ok, %{options: opts, arguments: args}} ->
          {:cont, {:ok, [{Embed.config(args, opts), paths} | acc]}}

        {:error, _} ->
          {:halt,
           {:error, "Could not parse the command in #{hd(paths)}: mix cli.embed #{command}"}}
      end
    end)
  end

  defp group_embeds(parsed) do
    groups =
      parsed
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {config, paths} -> {config, paths |> Enum.concat() |> Enum.sort()} end)
      |> Enum.group_by(fn {config, _} -> config.path end)
      |> Enum.sort()

    case Enum.filter(groups, fn {_, configs} -> length(configs) > 1 end) do
      [] ->
        {:ok, Enum.map(groups, fn {_, [{config, paths}]} -> %{config: config, paths: paths} end)}

      conflicts ->
        {:error, format_conflicts(conflicts)}
    end
  end

  defp format_conflicts(conflicts) do
    blocks =
      Enum.map(conflicts, fn {path, configs} ->
        commands =
          Enum.map(configs, fn {config, paths} ->
            ["    ", Embed.command_line(config), ?\n, format_conflict_paths(paths)]
          end)

        ["Conflicting commands found for ", path, ":\n\n", Enum.intersperse(commands, ?\n)]
      end)

    [
      Enum.intersperse(blocks, ?\n),
      "\nRegenerate each embed with the command you want to keep, then delete the files " <>
        "still listed under other commands."
    ]
  end

  defp format_conflict_paths(paths) do
    {shown, rest} = Enum.split(paths, 2)
    lines = Enum.map(shown, &["      ", &1, ?\n])

    case length(rest) do
      0 -> lines
      1 -> [lines, "      (1 more file)\n"]
      n -> [lines, "      (#{n} more files)\n"]
    end
  end

  defp check_embed(embed) do
    expected = Embed.generate(embed.config)
    expected_paths = Enum.map(expected, & &1.path)

    changed_or_missing = Enum.flat_map(expected, &compare_file/1)
    stale = for path <- embed.paths, path not in expected_paths, do: {:stale, path}

    Map.merge(embed, %{expected: expected, problems: changed_or_missing ++ stale})
  end

  defp compare_file(file) do
    case File.read(file.path) do
      {:ok, content} ->
        if Embed.strip_banner(content) == Embed.strip_banner(file.content),
          do: [],
          else: [{:changed, file.path}]

      {:error, _} ->
        [{:missing, file.path}]
    end
  end

  defp report(embeds, path) do
    Enum.each(embeds, &report_embed/1)

    case Enum.count(embeds, &(&1.problems != [])) do
      0 ->
        :ok

      n ->
        fix_command =
          Enum.join(Enum.reject(["mix cli.embed.check", path, "--fix"], &is_nil/1), " ")

        CLI.halt_error("Run `#{fix_command}` to regenerate #{n} #{pluralize(n, "embed")}.")
    end
  end

  defp report_embed(%{problems: []} = embed) do
    CLI.writeln("#{embed.config.path} is up to date")
  end

  defp report_embed(embed) do
    problems =
      Enum.map(embed.problems, fn {kind, path} ->
        ["  ", String.pad_trailing(Atom.to_string(kind), 9), path, ?\n]
      end)

    CLI.writeln([embed.config.path, " is out of date\n", problems])
  end

  defp fix_embed(%{problems: []} = embed) do
    report_embed(embed)
  end

  defp fix_embed(embed) do
    CLI.writeln("#{embed.config.path}: #{Embed.command_line(embed.config)}")

    Enum.each(embed.expected, fn file ->
      suffix = if File.exists?(file.path), do: " (overwrite)", else: ""
      Embed.write_file!(file)
      CLI.writeln("created #{file.path}#{suffix}")
    end)

    for {:stale, path} <- embed.problems do
      File.rm!(path)
      CLI.writeln("removed #{path}")
    end
  end

  defp report_nothing_found(nil) do
    CLI.writeln("No embedded CLI found")
  end

  defp report_nothing_found(path) do
    CLI.halt_error("No embedded CLI found in #{path}")
  end

  defp pluralize(1, word), do: word
  defp pluralize(_, word), do: word <> "s"
end
