defmodule CliMate.CLI.UsageFormat.OptionFormatter.Markdown do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option

  @moduledoc false

  @behaviour CliMate.CLI.UsageFormat

  @impl true
  def format_head(_, _, _), do: nil

  @impl true
  def format_synopsis(iodata, _), do: ["    ", iodata, "\n"]

  @impl true
  def format_section(title, content, _), do: ["## ", title, "\n\n", content]

  @impl true
  def section_margin, do: "\n\n"

  @impl true
  def format_arguments(command, _fmt_opts) do
    Enum.map(command.arguments, &format_argument/1)
  end

  defp format_argument(argument) do
    %Argument{
      key: key,
      doc: doc
    } = argument

    doc =
      case doc do
        "" -> ""
        text -> [" - ", indent_lines_except_first(text, 2)]
      end

    ["* ", ["`", Atom.to_string(key), "`"], String.trim(IO.chardata_to_string(doc)), "\n"]
  end

  @impl true
  def format_options(command, _fmt_opts) do
    Enum.map(command.options, &format_option/1)
  end

  defp format_option({_, option}) do
    %Option{
      key: key,
      doc: doc,
      default: default,
      default_doc: default_doc
    } = option

    doc =
      case doc do
        "" -> ""
        nil -> ""
        text -> [" - ", indent_lines_except_first(text, 2)]
      end

    doc = String.trim(IO.chardata_to_string(doc))

    doc =
      case {key, default} do
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, [" ", option_doc(key, v, default_doc)]]
      end

    ["* ", short_long(option), doc, "\n"]
  end

  defp short_long(option) do
    %Option{short: s} = option

    long = ["--", name(option), doc(option)]

    short =
      case s do
        nil -> []
        _ -> ["-", Atom.to_string(s), ", "]
      end

    ["`", short, long, "`"]
  end

  defp name(%Option{key: k}) do
    k |> Atom.to_string() |> String.replace("_", "-")
  end

  defp doc(%Option{type: t}) when t in [:boolean, :count], do: []
  defp doc(%Option{doc_arg: doc_arg}), do: [" <", doc_arg, ">"]

  defp option_doc(_, _, default_doc) when is_binary(default_doc) do
    default_doc
  end

  defp option_doc(k, value, _) when is_function(value, 1) do
    IO.warn([
      "Option ",
      inspect(k),
      " should document the default value using :default_doc option."
    ])

    "Dynamic default value."
  end

  defp option_doc(_, value, _) do
    ["Defaults to `", inspect(value), "`."]
  end

  defp indent_lines_except_first(text, indent) do
    text = IO.chardata_to_string(text)

    [first | lines] = String.split(text, "\n")

    indentation = String.duplicate(" ", indent)
    lines = Enum.map(lines, &[indentation, &1])

    Enum.intersperse([first | lines], ?\n)
  end
end
