defmodule CliMate.UsageFormat do
  alias CliMate.Option
  alias CliMate.Command

  @moduledoc false

  def format_command(command, opts) do
    opts = Map.merge(default_opts(), Map.new(opts))
    header = format_usage_header(command, opts)
    options = format_usage_opts(command.options, opts)
    [header, "\n\n", options]
  end

  defp default_opts do
    %{format: :cli}
  end

  defp format_usage_header(command, opts) do
    name = format_usage_command_name(command)

    optarray =
      case command do
        %{options: []} -> ""
        _ -> " [options]"
      end

    argslist =
      case command do
        %{arguments: []} -> ""
        %{arguments: args} -> format_usage_args_list(args)
      end

    {title, code_block} =
      case opts.format do
        :moduledoc -> {"## Usage", ["```shell\n", name, optarray, argslist, "\n```"]}
        _ -> {"Usage", ["  ", name, optarray, argslist]}
      end

    [title, "\n\n", code_block]
  end

  defp format_usage_command_name(command) do
    case command do
      %Command{name: nil, module: nil} ->
        "unnamed command"

      %Command{name: name} when is_binary(name) ->
        name

      %Command{module: mod} when is_atom(mod) and mod != nil ->
        mod
        |> inspect()
        |> String.split(".")
        |> case do
          ["Mix", "Tasks" | rest] ->
            "mix #{Enum.map_join(rest, ".", &Macro.underscore/1)}"

          rest ->
            Enum.map_join(rest, ".", &Macro.underscore/1)
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

  defp format_usage_opts([], _) do
    []
  end

  defp format_usage_opts(options, opts) do
    {title, optsdoc} =
      case opts.format do
        :moduledoc ->
          {"## Options", Enum.map(options, &__MODULE__.OptionFormatter.Markdown.format(&1))}

        _ ->
          max_opt = max_keyval_len(options)
          columns = Map.get_lazy(opts, :io_columns, &io_columns/0)
          left_padding = 12 + max_opt
          pad_io = ["\n", String.duplicate(" ", left_padding)]
          wrapping = columns - left_padding

          {"Options",
           Enum.map(
             options,
             &__MODULE__.OptionFormatter.PlainText.format(&1, max_opt, wrapping, pad_io)
           )}
      end

    [title, "\n\n", optsdoc]
  end

  defp max_keyval_len(kw) do
    kw
    |> Enum.map(fn
      {k, %Option{type: :boolean}} ->
        String.length(Atom.to_string(k))

      {k, %Option{doc_arg: doc_arg}} ->
        String.length(Atom.to_string(k)) + String.length(doc_arg)
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp io_columns do
    case :io.columns() do
      {:ok, n} -> n
      _ -> 100
    end
  end
end
