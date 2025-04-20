defmodule CliMate.CLI.UsageFormat do
  alias CliMate.CLI.Command
  alias CliMate.CLI.UsageFormat.OptionFormatter.Markdown
  alias CliMate.CLI.UsageFormat.OptionFormatter.PlainText

  @type fmt_opt :: {:io_columns, pos_integer} | {:ansi_enabled, boolean}
  @type fmt_opts :: [fmt_opt]

  @callback format_synopsis(iodata, fmt_opts) :: iodata()
  @callback format_section(title :: String.t(), content :: iodata(), fmt_opts) :: iodata()
  @callback section_padding() :: iodata()

  @doc """
  Formats an option block for the command. There is always at least one option
  for each command, the `--help` option, so there is no need to check if the
  options are an empty list.
  """
  @callback format_options(command :: Command.t(), fmt_opts) :: iodata()

  @moduledoc false

  defp adapter(opts) do
    case Keyword.fetch!(opts, :format) do
      :moduledoc -> Markdown
      :cli -> PlainText
    end
  end

  def format_command(command, fmt_opts) do
    opts = Keyword.merge(default_fmt_opts(), fmt_opts)
    adapter = adapter(opts)

    usage_section =
      adapter.format_section(
        "Usage",
        [
          adapter.format_synopsis(synopsis_line(command), fmt_opts)
        ],
        fmt_opts
      )

    options_section =
      adapter.format_section("Options", adapter.format_options(command, fmt_opts), fmt_opts)

    [usage_section, adapter.section_padding(), options_section]
  end

  defp default_fmt_opts do
    [format: :cli]
  end

  defp synopsis_line(command) do
    call = format_usage_command_call(command)

    argslist =
      case command do
        %{arguments: []} -> ""
        %{arguments: args} -> format_usage_args_list(args)
      end

    [call, " [options]", argslist]
  end

  defp format_usage_command_call(command) do
    case command do
      %Command{name: nil, module: nil} ->
        "unnamed command"

      %Command{name: name} when is_binary(name) ->
        name

      %Command{module: mod} when is_atom(mod) and mod != nil ->
        mod
        |> Module.split()
        |> case do
          ["Mix", "Tasks" | rest] ->
            "mix #{Enum.map_join(rest, ".", &Macro.underscore/1)}"

          _ ->
            inspect(mod)
        end
    end
  end

  defp format_usage_args_list([%{required: req?, key: key} | rest]) do
    name = Atom.to_string(key)

    case req? do
      true -> [" <", name, ">" | format_usage_args_list(rest)]
      false -> [[" [<", name, ">" | format_usage_args_list(rest)], "]"]
    end
  end

  defp format_usage_args_list([]) do
    []
  end
end
