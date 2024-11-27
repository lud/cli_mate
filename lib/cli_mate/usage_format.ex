defmodule CliMate.UsageFormat do
  alias CliMate.Option
  alias CliMate.Command

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
    max_opt = max_keyval_len(options)
    columns = Map.get_lazy(opts, :io_columns, &io_columns/0)
    left_padding = 12 + max_opt
    wrapping = columns - left_padding
    pad_io = ["\n", String.duplicate(" ", left_padding)]

    {title, optsdoc} =
      case opts.format do
        :moduledoc -> {"## Options", Enum.map(options, &format_usage_opt_md(&1))}
        _ -> {"Options", Enum.map(options, &format_usage_opt(&1, max_opt, wrapping, pad_io))}
      end

    [title, "\n\n", optsdoc]
  end

  defp format_usage_opt_md({_, option}) do
    %Option{
      type: t,
      short: s,
      key: k,
      doc: doc,
      default: default,
      default_doc: default_doc,
      doc_arg: doc_arg
    } = option

    name = k |> Atom.to_string() |> String.replace("_", "-")

    doc_arg =
      case t do
        :boolean -> []
        _ -> [" <", doc_arg, ">"]
      end

    short =
      case s do
        nil -> []
        _ -> ["-", Atom.to_string(s), ", "]
      end

    long = ["--", name, doc_arg]

    short_long = ["`", short, long, "`"]

    doc =
      case doc do
        "" -> ""
        nil -> ""
        text -> [" - ", ensure_final_dot(text)]
      end

    doc =
      case {k, default} do
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, [" ", format_default_moduledoc(k, v, default_doc)]]
      end

    ["* ", short_long, doc, "\n"]
  end

  defp format_usage_opt({_, option}, max_opt, wrapping, pad_io) do
    %Option{
      type: t,
      short: s,
      key: k,
      doc: doc,
      default: default,
      default_doc: default_doc,
      doc_arg: doc_arg
    } = option

    short =
      case s do
        nil -> "  "
        _ -> ["-", Atom.to_string(s)]
      end

    name = k |> Atom.to_string() |> String.replace("_", "-")

    long =
      case t do
        :boolean -> name
        _ -> to_string([name, " <", doc_arg, ">"])
      end

    long = ["--", String.pad_trailing(long, max_opt + 3, " ")]

    doc =
      case {k, default} do
        {:help, _} ->
          doc

        {_, :skip} ->
          ensure_final_dot(doc)

        {_, {:default, v}} ->
          [ensure_final_dot(doc), " ", [format_default(k, v, default_doc)]]
      end

    wrapped_doc =
      doc
      |> unwrap_doc()
      |> wrap_doc(wrapping)
      |> Enum.intersperse(pad_io)

    ["  ", short, " ", long, "  ", wrapped_doc, "\n"]
  end

  defp unwrap_doc(doc) do
    doc
    |> IO.chardata_to_string()
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
  end

  @re_sentence_end ~r/[.!?]$/
  defp ensure_final_dot("") do
    ""
  end

  defp ensure_final_dot(doc) do
    case Regex.match?(@re_sentence_end, doc) do
      true -> doc
      false -> doc <> "."
    end
  end

  defp wrap_doc(doc, width) do
    words =
      doc
      |> String.split(" ")
      |> Enum.map(&{&1, String.length(&1)})

    Enum.reduce(words, {0, [], []}, fn {word, len}, {line_len, this_line, lines} ->
      cond do
        line_len == 0 -> {len, [word | this_line], lines}
        line_len + 1 + len > width -> {len, [word], [:lists.reverse(this_line) | lines]}
        :_ -> {line_len + 1 + len, [word, " " | this_line], lines}
      end
    end)
    |> case do
      {_, [], lines} -> :lists.reverse(lines)
      {_, current, lines} -> :lists.reverse([:lists.reverse(current) | lines])
    end
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

  @doc false
  def ensure_string(str) when is_binary(str) do
    str
  end

  def ensure_string(term) do
    to_string(term)
  rescue
    _ in Protocol.UndefinedError -> inspect(term)
  end

  defp format_default(_k, _value, default_doc) when is_binary(default_doc) do
    ensure_final_dot(default_doc)
  end

  defp format_default(k, value, _) when is_function(value, 1) do
    IO.warn([
      "Option ",
      inspect(k),
      " should document the default value using :default_doc option."
    ])

    "Dynamic default value."
  end

  defp format_default(_, value, _) do
    ["Defaults to ", ensure_string(value), "."]
  end

  defp format_default_moduledoc(_, _, default_doc) when is_binary(default_doc) do
    ensure_final_dot(default_doc)
  end

  defp format_default_moduledoc(k, value, _) when is_function(value, 1) do
    IO.warn([
      "Option ",
      inspect(k),
      " should document the default value using :default_doc option."
    ])

    "Dynamic default value."
  end

  defp format_default_moduledoc(_, value, _) do
    ["Defaults to `", inspect(value), "`."]
  end
end
