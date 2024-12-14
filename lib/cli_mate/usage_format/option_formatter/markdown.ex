defmodule CliMate.UsageFormat.OptionFormatter.Markdown do
  alias CliMate.Option

  @moduledoc false

  def format({_, option}) do
    %Option{
      short: s,
      key: k,
      doc: doc,
      default: default,
      default_doc: default_doc
    } = option

    short =
      case s do
        nil -> []
        _ -> ["-", Atom.to_string(s), ", "]
      end

    long = ["--", name(option), doc(option)]

    short_long = ["`", short, long, "`"]

    doc =
      case doc do
        "" -> ""
        nil -> ""
        text -> [" - ", text]
      end

    doc =
      case {k, default} do
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, [" ", format_default_moduledoc(k, v, default_doc)]]
      end

    ["* ", short_long, doc, "\n"]
  end

  defp name(%Option{key: k}) do
    k |> Atom.to_string() |> String.replace("_", "-")
  end

  defp doc(%Option{type: :boolean}), do: []
  defp doc(%Option{doc_arg: doc_arg}), do: [" <", doc_arg, ">"]

  defp format_default_moduledoc(_, _, default_doc) when is_binary(default_doc) do
    default_doc
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
