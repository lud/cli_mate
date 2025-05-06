defmodule CliMate.CLI do
  alias CliMate.CLI.Command
  alias CliMate.CLI.UsageFormat

  @moduledoc """
  Main API to interact with the command line.

  ### Basic usage

      import #{inspect(__MODULE__)}

      def run(argv) do
        command = [options: [verbose: [type: :boolean]], arguments: [n: [type: :integer]]]
        %{options: opts, arguments: args} = parse_or_halt!(argv, command)

        if opts.verbose do
          writeln("Hello!")
        end

        case do_something_useful(args.n) do
          :ok -> halt_success("Done!")
          {:error, reason} -> halt_error(reason)
        end
      end
  """

  # -----------------------------------------------------------------------
  # Shell
  # -----------------------------------------------------------------------

  # Here we just basically rewrite what mix does, because we do not want to
  # rely on Mix to be started if we build escripts.

  @doc """
  Defines the current shell to send console messages to. Accepts either
  `#{inspect(__MODULE__)}` or `#{inspect(__MODULE__.ProcessShell)}`.

  This is mostly done for testing. The default shell outputs to standard io as
  you would expect.

  The shell is saved to `:persistent_term`, so shell should not be changed
  repeatedly during runtime. This method of persistence is subject to change and
  should not be relied on.
  """
  @doc section: :io
  def put_shell(module) do
    :persistent_term.put({__MODULE__, :shell}, module)
  end

  @doc """
  Returns the current shell to send output to.
  """
  @doc section: :io
  def shell do
    :persistent_term.get({__MODULE__, :shell}, __MODULE__)
  end

  # -----------------------------------------------------------------------
  # Output
  # -----------------------------------------------------------------------

  @doc false
  @doc section: :io
  def _print(output, _kind, iodata) do
    IO.puts(output, IO.ANSI.format(iodata))
  end

  @doc """
  Wraps the given `iodata` with the given `color`.

  `color` should be a `IO.ANSI.format/2` compatible atom.
  """
  @doc section: :io
  @spec color(iodata(), atom) :: [atom | [iodata | [:default_color | []]]]
  def color(iodata, color) when is_atom(color) do
    [color, iodata, :default_color]
  end

  def color(color, iodata) when is_atom(color) do
    IO.warn(
      "passing color as the first argument is deprecated. Call color(iodata, #{inspect(color)})"
    )

    [color, iodata, :default_color]
  end

  @doc """
  Outputs `iodata` to `stderr` in the current shell, formatted with bright
  red color.
  """
  @doc section: :io
  def error(iodata) do
    shell()._print(:stderr, :error, [:bright, color(iodata, :red)])
  end

  @doc """
  Outputs `iodata` to `stderr` in the current shell, formatted with yellow
  color.
  """
  @doc section: :io
  def warn(iodata) do
    shell()._print(:stderr, :warn, color(iodata, :yellow))
  end

  @doc """
  Outputs `iodata` in the current shell, formatted with cyan color.
  """
  @doc section: :io
  def debug(iodata) do
    shell()._print(:stdio, :debug, color(iodata, :cyan))
  end

  @doc """
  Outputs `iodata` in the current shell, formatted with green color.
  """
  @doc section: :io
  def success(iodata) do
    shell()._print(:stdio, :info, color(iodata, :green))
  end

  @doc """
  Outputs `iodata` in the current shell.
  """
  @doc section: :io
  def writeln(iodata) do
    shell()._print(:stdio, :info, iodata)
  end

  @doc """
  Outputs `iodata` in the current shell.
  """
  @doc section: :io
  def write(iodata) do
    shell()._print(:stdio, :info, iodata)
  end

  @doc """
  Stops the execution of the Erlang runtime, with a given return code.

  If not provided, the return code will be `0`.
  """
  @doc section: :io
  def halt(err_code \\ 0) when is_integer(err_code) do
    shell()._halt(err_code)
  end

  @doc """
  Combines `success/1` then `halt/1`. Halts the Erlang runtime with a `0`
  return code.
  """
  @doc section: :io
  def halt_success(iodata) do
    success(iodata)
    halt(0)
  end

  @doc """
  Combines `error/1` then `halt/1`. Halts the Erlang runtime with a `1`
  return code by default.
  """
  @doc section: :io
  @spec halt_error(err_code :: integer, term) :: no_return()
  def halt_error(err_code \\ 1, iodata) do
    error(iodata)
    halt(err_code)
  end

  @doc """
  Returns a string representation of the given term, with fallback to
  `Kernel.inspect/1`.
  """
  @spec safe_to_string(term) :: binary
  def safe_to_string(term) when is_binary(term) do
    term
  end

  def safe_to_string(term) do
    to_string(term)
  rescue
    _ in Protocol.UndefinedError -> inspect(term)
  end

  @doc false
  @spec _halt(integer) :: no_return()
  def _halt(n) do
    System.halt(n)
  end

  # -----------------------------------------------------------------------
  # Parser
  # -----------------------------------------------------------------------

  @doc """
  Accepts the command line arguments and the definition of a command (options,
  arguments, and metadata) and returns a parse result with flues extracted from
  the command line arguments.

  ### Defining options

  Options definitions is a `Keyword` whose keys are the option name, and values
  are the options parameters. Keys with underscores like `some_thing` define
  options in kebab case like `--some-thing`.

  The available settings for an option are described in the
  `#{inspect(__MODULE__)}.Option` module.

  The `:help` option is always defined and cannot be overridden.

  ### Options examples

      iex> {:ok, result} = parse(~w(--who joe), [options: [who: [type: :string]]])
      iex> result.options.who
      "joe"

      iex> {:ok, result} = parse(~w(--who joe), [options: [who: []]])
      iex> result.options.who
      "joe"

      iex> {:ok, result} = parse(~w(--port 4000), [options: [port: [type: :integer]]])
      iex> result.options.port
      4000

      iex> {:ok, result} = parse(~w(-p 4000), [options: [port: [type: :integer, short: :p]]])
      iex> result.options.port
      4000

      iex> parse(~w(--port nope), [options: [port: [type: :integer]]])
      {:error, {:invalid, [{"--port", "nope"}]}}

      iex> {:ok, result} = parse([], [options: [lang: [default: "elixir"]]])
      iex> result.options.lang
      "elixir"

      iex> {:ok, result} = parse([], [options: [lang: []]])
      iex> Map.has_key?(result.options, :lang)
      false

      iex> {:ok, result} = parse([], options: [])
      iex> result.options.help
      false

      iex> {:ok, result} = parse(~w(--help), options: [])
      iex> result.options.help
      true

  ### Defining arguments

  Arguments can be defined in the same way as options, providing a `Keyword`
  where the keys are the argument names and the values are the parameters.

  The available settings for an argument are described in the
  `#{inspect(__MODULE__)}.Argument` module.

  ### Arguments examples

      iex> {:ok, result} = parse(~w(joe), arguments: [who: []])
      iex> result.arguments.who
      "joe"

      iex> parse([], arguments: [who: []])
      {:error, {:missing_argument, :who}}

      iex> {:ok, result} = parse([], arguments: [who: [required: false]])
      iex> result.arguments
      %{}

      iex> cast = fn string -> Date.from_iso8601(string) end
      iex> {:ok, result} = parse(["2022-12-22"], arguments: [date: [cast: cast]])
      iex> result.arguments.date
      ~D[2022-12-22]

      iex> cast = {Date, :from_iso8601, []}
      iex> {:ok, result} = parse(["2022-12-22"], arguments: [date: [cast: cast]])
      iex> result.arguments.date
      ~D[2022-12-22]

      iex> cast = {Date, :from_iso8601, []}
      iex> parse(["not-a-date"], arguments: [date: [cast: cast]])
      {:error, {:argument_cast, :date, :invalid_format}}
  """
  @doc section: :parser
  def parse(argv, command) when is_list(command) do
    parse(argv, Command.new(command))
  end

  def parse(argv, %Command{} = command) do
    options = command.options
    arguments = command.arguments

    strict = Enum.map(options, fn {key, opt} -> {key, opt_to_switch(opt)} end)
    aliases = Enum.flat_map(options, fn {_, opt} -> opt_alias(opt) end)

    with {parsed_options, parsed_arguments, []} <-
           OptionParser.parse(argv, strict: strict, aliases: aliases),
         {:ok, %{help: false} = options_found} <- take_opts(options, parsed_options),
         {:ok, arguments_found} <- take_args(arguments, parsed_arguments) do
      {:ok, %{options: options_found, arguments: arguments_found}}
    else
      {:ok, %{help: true} = options_found} -> {:ok, %{options: options_found, arguments: []}}
      {_, _, invalid} -> {:error, {:invalid, invalid}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Attempts to parse the command line arguments `argv` with the defined
  command.

  Command options and arguments are documented in the `parse/2` function of
  this module.

  In `parse_or_halt!/2`, the successful return value will not be wrapped in
  an `:ok` tuple, but directly a map with the `:options` and `:arguments`
  keys.

  In case of a parse error, this function will output the usage block
  followed by a formatted error message, and halt the Erlang runtime.
  """
  @doc section: :parser
  def parse_or_halt!(argv, command) do
    case parse(argv, command) do
      {:ok, %{options: %{help: true}}} ->
        write(format_usage(command, ansi_enabled: IO.ANSI.enabled?()))
        halt(0)
        :halt

      {:ok, parsed} ->
        parsed

      {:error, reason} ->
        write(format_usage(command, ansi_enabled: IO.ANSI.enabled?()))
        error(format_reason(reason))
        halt(1)
        :halt
    end
  end

  defp opt_to_switch(%{keep: true, type: t}), do: [t, :keep]
  defp opt_to_switch(%{keep: false, type: t}), do: t
  defp opt_alias(%{short: nil}), do: []
  defp opt_alias(%{short: a, key: key}), do: [{a, key}]

  defp take_opts(schemes, opts) do
    all = Enum.reduce(schemes, %{}, fn scheme, acc -> collect_opt(scheme, opts, acc) end)
    {:ok, all}
  end

  defp collect_opt({key, scheme}, opts, acc) do
    case scheme.keep do
      true ->
        list = collect_list_option(opts, key)
        Map.put(acc, key, list)

      false ->
        case get_opt_value(opts, key, scheme.default) do
          {:ok, value} -> Map.put(acc, key, value)
          :skip -> acc
        end
    end
  end

  defp get_opt_value(opts, key, default) do
    case Keyword.fetch(opts, key) do
      :error ->
        case default do
          {:default, v} -> {:ok, get_opt_default(v, key)}
          :skip -> :skip
        end

      {:ok, v} ->
        {:ok, v}
    end
  end

  defp get_opt_default(f, _) when is_function(f, 0), do: f.()
  defp get_opt_default(f, key) when is_function(f, 1), do: f.(key)
  defp get_opt_default(raw, _), do: raw

  defp collect_list_option(opts, key) do
    opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
  end

  defp take_args(schemes, args) do
    take_args(schemes, args, %{})
  end

  defp take_args([scheme | schemes], [value | argv], acc) do
    %{key: key, cast: cast, type: t} = scheme

    case cast_arg_type(t, value) do
      :error ->
        {:error, {:argument_type, key, t}}

      {:ok, value} ->
        case apply_cast(cast, value) do
          {:ok, casted} ->
            acc = Map.put(acc, key, casted)
            take_args(schemes, argv, acc)

          {:error, reason} ->
            {:error, {:argument_cast, key, reason}}

          other ->
            raise "Argument custom caster #{inspect(cast)} returned invalid value: #{inspect(other)}"
        end
    end
  end

  defp take_args([], [extra | _], _) do
    {:error, {:extra_argument, extra}}
  end

  defp take_args([], [], acc) do
    {:ok, acc}
  end

  defp take_args([%{required: false} | _], [], acc) do
    {:ok, acc}
  end

  defp take_args([%{required: true, key: key} | _], [], _acc) do
    {:error, {:missing_argument, key}}
  end

  defp cast_arg_type(:string, value), do: {:ok, value}

  defp cast_arg_type(:integer, value) do
    case Integer.parse(value) do
      {v, ""} -> {:ok, v}
      :error -> :error
    end
  end

  defp cast_arg_type(:float, value) do
    case Float.parse(value) do
      {v, ""} -> {:ok, v}
      :error -> :error
    end
  end

  defp apply_cast(nil, value) do
    {:ok, value}
  end

  defp apply_cast(f, value) when is_function(f) do
    f.(value)
  end

  defp apply_cast({m, f, a}, value) do
    apply(m, f, [value | a])
  end

  defp format_reason({:argument_cast, key, {:bad_return, br}}) do
    ["could not cast argument ", Atom.to_string(key), " bad return: ", inspect(br)]
  end

  defp format_reason({:argument_cast, key, reason}) do
    ["error when casting argument ", Atom.to_string(key), ": ", safe_to_string(reason)]
  end

  defp format_reason({:argument_type, key, type}) do
    ["invalid argument ", Atom.to_string(key), ", expected type ", Atom.to_string(type)]
  end

  defp format_reason({:invalid, invalid}) do
    invalid |> Enum.map(fn {k, _v} -> "invalid option #{k}" end) |> Enum.intersperse("\n")
  end

  defp format_reason({:extra_argument, v}) do
    "unexpected extra argument #{v}"
  end

  defp format_reason({:missing_argument, key}) do
    ["missing argument ", Atom.to_string(key)]
  end

  # -----------------------------------------------------------------------
  #  Usage Format
  # -----------------------------------------------------------------------

  @doc """
  Returns a standard "usage" documentation block describing the different
  options of the given command.

  ### Options

  * `:format` - If `:moduledoc`, the formatted usage will be compatible for
    embedding in a `@moduledoc` attribute. Any other value will generate a
    simple terminal styled text. Defaults to `:cli`.
  * `:io_columns` - Number of columns for the terminal, defaults to a call to
    `:io.columns/0`. Only used when format is `:cli`.
  """
  def format_usage(command, opts \\ [])

  def format_usage(command, opts) when is_list(command) do
    format_usage(Command.new(command), opts)
  end

  def format_usage(%Command{} = command, opts) do
    UsageFormat.format_command(command, opts)
  end

  @doc """
  Delegates all `#{inspect(__MODULE__)}` functions from the calling module.

  This is useful if you want to define a module where all your CLI helpers
  reside, instead of calling, say, `writeln("hello")` from
  `#{inspect(__MODULE__)}` but `fancy_subtitle("Hello!")` from
  `MyApp.CliHelpers`.
  """
  defmacro extend do
    parent = __MODULE__

    quote bind_quoted: binding() do
      delegations =
        parent.module_info(:exports) --
          [
            __info__: 1,
            _halt: 1,
            _print: 3,
            module_info: 0,
            module_info: 1,
            safe_to_string: 1,
            "MACRO-extend": 1
          ]

      Enum.each(delegations, fn
        {fun, 0} ->
          @doc_if_moduledoc "Delegated to `#{inspect(CliMate.CLI)}.#{fun}/0`"
          @doc @doc_if_moduledoc
          defdelegate unquote(fun)(), to: CliMate.CLI

        {fun, arity} ->
          @doc_if_moduledoc "Delegated to `#{inspect(CliMate.CLI)}.#{fun}/#{arity}`"
          @doc @doc_if_moduledoc
          args = Enum.map(1..arity, &Macro.var(:"arg#{&1}", __MODULE__))
          defdelegate unquote(fun)(unquote_splicing(args)), to: CliMate.CLI
      end)
    end
  end
end
