defmodule CliMate.CLI.UsageFormat.OptionFormatter.PlainText do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option

  @moduledoc false

  @behaviour CliMate.CLI.UsageFormat
  @doc_indent 16
  @arg_indent 2
  @max_doc_width 87

  defp indent(n), do: List.duplicate(32, n)

  @impl true
  def format_head(title, docs, fmt_opts) do
    case docs do
      nil -> format_command(title, fmt_opts)
      _ -> [format_command(title, fmt_opts), "\n\n", docs]
    end
  end

  defp format_command(title, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      bright(title)
    else
      title
    end
  end

  @impl true
  def format_synopsis(iodata, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      ["  ", cyan(iodata)]
    else
      ["  ", iodata]
    end
  end

  @impl true
  def format_section(title, content, fmt_opts) do
    [format_heading(title, fmt_opts), "\n\n", content]
  end

  defp format_heading(title, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      ubright(title)
    else
      title
    end
  end

  @impl true
  def section_margin, do: "\n\n"

  @impl true
  def format_arguments(command, fmt_opts) do
    columns = Keyword.get_lazy(fmt_opts, :io_columns, &io_columns/0)
    ansi_enabled? = Keyword.get(fmt_opts, :ansi_enabled, false)

    doc_width = min(columns - @doc_indent, @max_doc_width)

    Enum.map_intersperse(command.arguments, "\n\n", fn arg ->
      name = Atom.to_string(arg.key)
      title = arg_title(name, arg.repeat, ansi_enabled?)
      len = String.length(name) + @arg_indent + if arg.repeat, do: 3, else: 0
      spacing = @doc_indent - len
      doc_padding = [?\n, indent(@doc_indent)]
      first_padding = if spacing > 1, do: indent(spacing), else: doc_padding

      case format_doc(arg, doc_width, first_padding, doc_padding) do
        :no_doc -> [indent(@arg_indent), title]
        doc -> [indent(@arg_indent), title, doc]
      end
    end)
  end

  defp arg_title(name, repeat?, ansi_enabled?) do
    title = if ansi_enabled?, do: bright(name), else: name

    if repeat? do
      [title, "..."]
    else
      title
    end
  end

  @impl true
  def format_options(command, fmt_opts) do
    columns = Keyword.get_lazy(fmt_opts, :io_columns, &io_columns/0)
    ansi_enabled? = Keyword.get(fmt_opts, :ansi_enabled, false)
    options = command.options
    doc_padding = [?\n, indent(@doc_indent)]
    doc_width = min(columns - @doc_indent, @max_doc_width)

    docs =
      Enum.map(options, fn opt ->
        {signature, raw_len} = signature(opt, ansi_enabled?)
        spacing = @doc_indent - (raw_len + @arg_indent)
        first_padding = if spacing > 1, do: indent(spacing), else: doc_padding
        doc = format_doc(opt, doc_width, first_padding, doc_padding)

        case doc do
          :no_doc -> [indent(@arg_indent), signature, ?\n]
          doc -> [indent(@arg_indent), signature, doc, ?\n]
        end
      end)

    Enum.intersperse(docs, ?\n)
  end

  defp signature({_, option}, ansi_enabled?) do
    {iodata_short, short_len} =
      case short_signature(option, ansi_enabled?) do
        [] -> {[], 0}
        short -> {short, 4}
      end

    {iodata_long, len} = long_signature(option, ansi_enabled?)
    {[iodata_short, iodata_long], len + short_len}
  end

  defp short_signature(option, ansi_enabled?) do
    %Option{short: short} = option

    case short do
      nil -> []
      s when ansi_enabled? -> [bright(["-", Atom.to_string(s)]), ", "]
      s -> ["-", Atom.to_string(s), ", "]
    end
  end

  defp long_signature(option, ansi_enabled?) do
    %Option{type: type} = option
    name = name(option)

    len = String.length(name) + 2

    {signature, len} =
      case type do
        t when t in [:boolean, :count] and ansi_enabled? ->
          {[bright(["--", name])], len}

        t when t in [:boolean, :count] ->
          {["--", name], len}

        _ when ansi_enabled? ->
          doc_arg = option.doc_arg
          {[bright(["--", name]), cyan([" <", doc_arg, ">"])], len + String.length(doc_arg) + 3}

        _ ->
          doc_arg = option.doc_arg
          {["--", name, " <", doc_arg, ">"], len + String.length(doc_arg) + 3}
      end

    {_formatted, _len} =
      if type == :count || option.keep do
        {[signature, " [...]"], len + 6}
      else
        {signature, len}
      end
  end

  defp format_doc(%Argument{} = argument, width, first_padding, other_padding) do
    %{doc: doc} = argument

    case doc do
      "" ->
        :no_doc

      _ ->
        doc =
          doc
          |> unwrap_doc()
          |> wrap_doc(width)
          |> Enum.intersperse(other_padding)

        [first_padding, doc]
    end
  end

  defp format_doc({_, %Option{} = option}, width, first_padding, other_padding) do
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
        doc =
          doc
          |> unwrap_doc()
          |> wrap_doc(width)
          |> Enum.intersperse(other_padding)

        [first_padding, doc]
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
  defp ubright(iodata), do: [IO.ANSI.underline(), IO.ANSI.bright(), iodata, IO.ANSI.reset()]
  defp cyan(iodata), do: [IO.ANSI.cyan(), iodata, IO.ANSI.reset()]

  defp unwrap_doc(doc) do
    doc
    |> IO.chardata_to_string()
    |> String.trim()
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
  end

  defp wrap_doc(doc, width) do
    words =
      doc
      |> String.split(" ")
      |> Enum.map(&{&1, String.length(&1)})

    words
    |> Enum.reduce({0, [], []}, fn {word, len}, {line_len, this_line, lines} ->
      cond do
        line_len == 0 -> {len, [word | this_line], lines}
        line_len + 1 + len > width -> {len, [word], [:lists.reverse(this_line) | lines]}
        :_ -> {line_len + 1 + len, [word, " " | this_line], lines}
      end
    end)
    |> case do
      {_, [], lines} -> lines
      {_, current, lines} -> [:lists.reverse(current) | lines]
    end
    # Fancy stuff. We need to reverse the lines but also map them so if one line
    # starts with a backtick we insert a backspace before so the text aligns
    # more naturally.
    |> List.foldl([], fn
      ["`" <> _ = h | t], acc -> [["\b", h | t] | acc]
      line, acc -> [line | acc]
    end)
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
    ["Defaults to ", inspect(value), "."]
  end
end
