defmodule CliMate.UsageFormat.OptionFormatter.PlainText do
  alias CliMate.Option

  @moduledoc false

  def format({_, option}, max_opt, wrapping, pad_io) do
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
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, " ", [format_default(k, v, default_doc)]]
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

  defp format_default(_k, _value, default_doc) when is_binary(default_doc) do
    default_doc
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
    ["Defaults to ", CliMate.CLI.safe_to_string(value), "."]
  end
end
