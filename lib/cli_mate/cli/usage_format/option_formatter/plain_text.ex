defmodule CliMate.CLI.UsageFormat.OptionFormatter.PlainText do
  alias CliMate.CLI.Option

  @moduledoc false

  @behaviour CliMate.CLI.UsageFormat

  # padding on the left of the options block
  @left_padding "  "

  # padding between an option signature and its docs
  @inner_padding "   "

  @inner_padding_len String.length(@inner_padding)
  @left_padding_len String.length(@left_padding)

  @impl true
  def format_synopsis(iodata, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      ["  ", IO.ANSI.cyan(), iodata, IO.ANSI.reset()]
    else
      ["  ", iodata]
    end
  end

  @impl true
  def format_section(title, content, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      [bright(title), "\n\n", content]
    else
      [title, "\n\n", content]
    end
  end

  @impl true
  def section_padding, do: "\n\n"

  @impl true
  def format_options(command, fmt_opts) do
    columns = Keyword.get_lazy(fmt_opts, :io_columns, &io_columns/0)
    ansi_enabled? = Keyword.get(fmt_opts, :ansi_enabled, false)

    options = command.options
    has_short_opts? = Enum.any?(options, fn {_, %{short: short}} -> short != nil end)

    signatures_w_len = Enum.map(options, &signature(&1, ansi_enabled?, has_short_opts?))

    max_signature_len = Enum.reduce(signatures_w_len, 0, fn {_, len}, acc -> max(acc, len) end)

    signatures_w_pad =
      Enum.map(signatures_w_len, fn {text, len} ->
        case max_signature_len - len do
          0 -> {text, ""}
          rem -> {text, List.duplicate(" ", rem)}
        end
      end)

    doc_padding_len = @left_padding_len + max_signature_len + @inner_padding_len
    doc_padding = ["\n", List.duplicate(" ", doc_padding_len)]
    doc_width = columns - doc_padding_len

    docs = Enum.map(options, &format_doc(&1, doc_width, doc_padding))

    Enum.zip_with(signatures_w_pad, docs, fn
      {signature, _sign_pad}, :no_doc ->
        [@left_padding, signature, "\n"]

      {signature, sign_pad}, doc ->
        [@left_padding, signature, sign_pad, @inner_padding, doc, "\n"]
    end)
  end

  defp signature({_, option}, ansi_enabled?, true = _shorts?) do
    %Option{short: short} = option

    {iodata, len} =
      case short do
        nil -> {["    "], 4}
        s when ansi_enabled? -> {[bright(["-", Atom.to_string(s)]), ", "], 4}
        s -> {["-", Atom.to_string(s), ", "], 4}
      end

    signature_2(option, iodata, len, ansi_enabled?)
  end

  defp signature({_, option}, ansi_enabled?, false = _shorts?) do
    signature_2(option, "", 0, ansi_enabled?)
  end

  defp signature_2(option, iodata, len, ansi_enabled?) do
    %Option{type: type} = option

    name = name(option)
    name_len = String.length(name)

    case type do
      t when t in [:boolean, :count] and ansi_enabled? ->
        {[iodata, bright(["--", name])], len + 2 + name_len}

      t when t in [:boolean, :count] ->
        {[iodata, "--", name], len + 2 + name_len}

      _ when ansi_enabled? ->
        doc_arg = option.doc_arg
        doc_arg_len = String.length(doc_arg)
        {[iodata, bright(["--", name, " <", doc_arg, ">"])], len + 2 + name_len + doc_arg_len + 3}

      _ ->
        doc_arg = option.doc_arg
        doc_arg_len = String.length(doc_arg)
        {[iodata, "--", name, " <", doc_arg, ">"], len + 2 + name_len + doc_arg_len + 3}
    end
  end

  defp format_doc({_, option}, width, pad_text) do
    %Option{
      key: k,
      doc: doc,
      default: default,
      default_doc: default_doc
    } = option

    doc =
      case {k, default} do
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, " ", [format_default(k, v, default_doc)]]
      end

    case doc do
      "" ->
        :no_doc

      _ ->
        doc
        |> unwrap_doc()
        |> wrap_doc(width)
        |> Enum.intersperse(pad_text)
    end
  end

  defp name(%Option{key: key}) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end

  defp io_columns do
    case :io.columns() do
      {:ok, n} -> n
      _ -> 78
    end
  end

  defp bright(iodata), do: [IO.ANSI.bright(), iodata, IO.ANSI.reset()]

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
