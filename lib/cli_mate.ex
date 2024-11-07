defmodule CliMate do
  defmacro __using__(_) do
    cli_mod = __CALLER__.module

    quote bind_quoted: [cli_mod: cli_mod], location: :keep, generated: true do
      # -----------------------------------------------------------------------
      # Shell
      # -----------------------------------------------------------------------

      # Here we just basically rewrite what mix does, because we do not want to
      # rely on Mix to be started if we build escripts.

      @doc """
      Defines the current shell to send console messages to. Accepts either
      `#{inspect(__MODULE__)}` or `#{inspect(__MODULE__.ProcessShell)}`.

      The shell is saved to `:persistent_term`, so shell should not be changed
      repeatedly during runtime. This method of persistence is subject to change
      and should not be relied on.
      """
      def put_shell(module) do
        :persistent_term.put({__MODULE__, :shell}, module)
      end

      @doc """
      Returns the current shell used by #{inspect(__MODULE__)} to send output.
      """
      def shell do
        :persistent_term.get({__MODULE__, :shell}, __MODULE__)
      end

      # -----------------------------------------------------------------------
      # Output
      # -----------------------------------------------------------------------

      @doc false
      def _print(output, _kind, iodata) do
        IO.puts(output, IO.ANSI.format(iodata))
      end

      @doc """
      Outputs `iodata` in the current shell, wrapped with formatting
      information, such as `[color, iodata, :default_color]`.

      `color` should be a `IO.ANSI.format/2` compatible atom.
      """
      def color(color, iodata) do
        [color, iodata, :default_color]
      end

      @doc """
      Outputs `iodata` to `stderr` in the current shell, formatted with bright
      red color.
      """
      def error(iodata) do
        shell()._print(:stderr, :error, [:bright, color(:red, iodata)])
      end

      @doc """
      Outputs `iodata` to `stderr` in the current shell, formatted with yellow
      color.
      """
      def warn(iodata) do
        shell()._print(:stderr, :warn, color(:yellow, iodata))
      end

      @doc """
      Outputs `iodata` in the current shell, formatted with cyan color.
      """
      def debug(iodata) do
        shell()._print(:stdio, :debug, color(:cyan, iodata))
      end

      @doc """
      Outputs `iodata` in the current shell, formatted with green color.
      """
      def success(iodata) do
        shell()._print(:stdio, :info, color(:green, iodata))
      end

      @doc """
      Outputs `iodata` in the current shell.
      """
      def writeln(iodata) do
        shell()._print(:stdio, :info, iodata)
      end

      @doc """
      Stops the execution of the Erlang runtime, with a given return code.

      If not provided, the return code will be `0`.
      """
      def halt(err_code \\ 0) when is_integer(err_code) do
        shell()._halt(err_code)
      end

      @doc """
      Combines `success/1` then `halt/1`. Halts the Erlang runtime with a `0`
      return code.
      """
      def halt_success(iodata) do
        success(iodata)
        halt(0)
      end

      @doc """
      Combines `error/1` then `halt/1`. Halts the Erlang runtime with a `1`
      return code by default.
      """
      def halt_error(err_code \\ 1, iodata) do
        error(iodata)
        halt(err_code)
      end

      @doc false
      def _halt(n) do
        System.halt(n)
      end

      defmodule ProcessShell do
        @moduledoc """
        An output shell implementation allowing your CLI commands to send their
        output as messages to themselves. This is most useful for tests.

        The process that will receive the messages is found by looking up the
        first pid in the `:"$callers"` key of the process dictionary, or
        `self()` if there is no caller.

        Use `#{inspect(cli_mod)}.put_shell(#{inspect(__MODULE__)})` to enable this
        shell.
        """

        @doc false
        def cli_mod, do: unquote(cli_mod)

        @doc false
        def _print(_output, kind, iodata) do
          send(message_target(), {cli_mod(), kind, format_message(iodata)})
        end

        defp format_message(iodata) do
          iodata
          |> IO.ANSI.format(false)
          |> :erlang.iolist_to_binary()
        end

        @doc """
        Returns the pid of the process that will receive output messages.
        """
        def message_target do
          case Process.get(:"$callers") do
            [parent | _] -> parent
            _ -> self()
          end
        end

        def _halt(n) do
          send(message_target(), {cli_mod(), :halt, n})
        end
      end

      # -----------------------------------------------------------------------
      # Defining commands
      # -----------------------------------------------------------------------

      defmodule Option do
        @moduledoc false
        @enforce_keys [:key, :doc, :type, :short, :default, :keep, :doc_arg]
        defstruct @enforce_keys

        @type vtype :: :integer | :float | :string | :count | :boolean
        @type t :: %__MODULE__{
                key: atom,
                doc: binary,
                type: vtype,
                short: atom,
                default: term,
                keep: boolean,
                doc_arg: binary
              }
      end

      defp build_option({key, conf}) when is_atom(key) and is_list(conf) do
        keep = Keyword.get(conf, :keep, false)
        type = Keyword.get(conf, :type, :string)
        doc = Keyword.get(conf, :doc, "")
        short = Keyword.get(conf, :short, nil)
        doc_arg = Keyword.get(conf, :doc_arg, Atom.to_string(type))

        default =
          case Keyword.fetch(conf, :default) do
            {:ok, term} -> {:default, term}
            :error when type == :boolean -> :skip
            :error -> :skip
          end

        opt = %Option{
          key: key,
          doc: doc,
          type: type,
          short: short,
          default: default,
          keep: keep,
          doc_arg: doc_arg
        }

        {key, opt}
      end

      defmodule Argument do
        @moduledoc false
        @enforce_keys [:key, :required, :cast, :doc, :type]
        defstruct @enforce_keys

        @type vtype :: :integer | :float | :string
        @type t :: %__MODULE__{
                required: boolean,
                key: atom,
                type: vtype,
                doc: binary,
                cast: (term -> term) | {module, atom, [term]}
              }
      end

      defp build_argument({key, conf}) when is_atom(key) and is_list(conf) do
        required = Keyword.get(conf, :required, true)
        cast = Keyword.get(conf, :cast, nil)

        doc = Keyword.get(conf, :doc, "")
        type = Keyword.get(conf, :type, :string)

        validate_arg_type_spec(type)

        %Argument{key: key, required: required, cast: cast, doc: doc, type: type}
      end

      defp validate_cast(cast) do
        case cast do
          f when is_function(f, 1) ->
            :ok

          nil ->
            :ok

          {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
            :ok

          _ ->
            raise(
              ArgumentError,
              "Expected :cast function to be a valid cast function, got: #{inspect(cast)}"
            )
        end
      end

      defp validate_arg_type_spec(spec) do
        unless spec in [:string, :float, :integer] do
          raise ArgumentError,
                "expected argument type to be one of :string, :float or :integer, got: #{inspect(spec)}"
        end

        :ok
      end

      defmodule Command do
        @moduledoc false
        @enforce_keys [:arguments, :options]
        defstruct [:arguments, :options, :module, :name]

        @type t :: %__MODULE__{
                arguments: [Argument.t()],
                options: [{atom, Option.t()}],
                module: module | nil,
                name: binary | nil
              }
      end

      @help_option_def [type: :boolean, default: false, doc: "Displays this help."]

      defp build_command(conf) do
        options =
          conf
          |> Keyword.get(:options, [])
          |> Keyword.update(:help, @help_option_def, fn _ ->
            raise ArgumentError, "the :help option cannot be overriden"
          end)
          |> Enum.map(&build_option/1)

        arguments = conf |> Keyword.get(:arguments, []) |> Enum.map(&build_argument/1)
        name = conf |> Keyword.get(:name, nil)
        module = conf |> Keyword.get(:module, nil)
        %Command{options: options, arguments: arguments, name: name, module: module}
      end

      # -----------------------------------------------------------------------
      # Parser
      # -----------------------------------------------------------------------

      @doc """
      Accepts the command line arguments and the definition of a command
      (options, arguments, and metadata) and returns a parse result with values
      extracted from the command line arguments.

      ### Defining options

      Options definitions is a `Keyword` whose keys are the option name, and
      values are the options parameters. Note that keys with underscores like
      `some_thing` define options in kebab case like `--some-thing`.

      The following parameters are available:

      - `:type` - Can be either `:boolean`, `:integer` or `:string`. The default
        value is `:string`.
      - `:short` - Defines the shortcut for the option, for instance `-p`
        instead of `--port`.
      - `:default` - Defines the default value if the corresponding option is
        not defined in `argv`.See "Default values" below.
      - `:doc` - Accepts a string that will be used when formatting the usage
        block for the command.

      Note that the `:help` option is always defined and cannot be overridden.

      ### Default values

      Default values can be omitted, in that case, the option will not be
      present at all if not provided in the command line.

      When defined, a default value can be:

      * A raw value, that is anything that is not a function. This value will be
        used as the default value.
      * A function of arity zero. This function will be called when the option
        is not provided in the command line and the result value will be used as
        the default value. For instance `fn -> 123 end` or `&default_age/0`.
      * A function of arity one. This function will be called with the option
        key as its argument. For instance, passing `&default_opt/1` as the
        `:default` for an option definition allow to define the following
        function:

            defp default_opt(:port), do: 4000
            defp default_opt(:scheme), do: "http"

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

      Arguments can be defined in the same way, providing a `Keyword` where the
      keys are the argument names and the values are the parameters.

      ### Defining arguments

      The following parameters are available:

      - `:required` - A boolean marking the argument as required. **Note that
        arguments are required by default**. Keys for optional arguments that
        are not provided by the command line will not be defined in the results.
      - `:cast` - Accepts a fun or a `{module, function, arguments}` tuple to
        transform the argument value when parsing. The invoked function must
        return a result tuple: `{:ok, _} | {:error, _}`.
      - `:doc` - Accepts a string that will be used when formatting the usage
        block for the command. Note that this is not currently implemented for
        arguments.

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
      def parse(argv, command) when is_list(command) do
        parse(argv, build_command(command))
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
      def parse_or_halt!(argv, command) do
        case parse(argv, command) do
          {:ok, %{options: %{help: true}}} ->
            writeln(format_usage(command))
            halt(0)
            :halt

          {:ok, parsed} ->
            parsed

          {:error, reason} ->
            writeln(format_usage(command))
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

      defp take_args([%{required: true, key: key} | _], [], _acc) do
        {:error, {:missing_argument, key}}
      end

      defp take_args([scheme | schemes], [value | argv], acc) do
        %{key: key, cast: cast, type: t} = scheme

        case cast_arg_type(t, value) do
          :error ->
            {:error, {:argument_type, key, "Invalid argument #{key}, expected type #{t}"}}

          {:ok, value} ->
            case apply_cast(cast, value) do
              {:ok, casted} ->
                acc = Map.put(acc, key, casted)
                take_args(schemes, argv, acc)

              {:error, reason} ->
                {:error, {:argument_cast, key, reason}}

              other ->
                {:error, {:argument_cast, key, {:bad_return, other}}}
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

      defp format_reason({:argument_cast, key, reason}) do
        ["error when casting argument ", Atom.to_string(key), ": ", ensure_string(reason)]
      end

      defp format_reason({:argument_cast, key, {:bad_return, br}}) do
        ["could not cast argument ", Atom.to_string(key), " bad return: ", inspect(br)]
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

      defp format_reason(other) do
        inspect(other)
      end

      # -----------------------------------------------------------------------
      #  Usage Format
      # -----------------------------------------------------------------------

      defp format_opts do
        %{format: :cli}
      end

      @doc """
      Returns a standard "usage" documentation block describing the different
      options of the given command.

      ### Options

      * `:format` - If `:moduledoc`, the formatted usage will be compatible for
        embedding in a `@moduledoc` attribute. Any other value will generate a
        simple terminal styled text. Defaults to `:cli`.
      """
      def format_usage(command, opts \\ [])

      def format_usage(command, opts) when is_list(command) do
        format_usage(build_command(command), opts)
      end

      def format_usage(%Command{} = command, opts) do
        opts = Map.merge(format_opts(), Map.new(opts))
        header = format_usage_header(command, opts)
        options = format_usage_opts(command.options, opts)
        [header, "\n\n", options]
      end

      defp format_usage_header(command, opts) do
        name = format_usage_command_name(command)

        {title, padding} =
          case opts.format do
            :moduledoc -> {"## Usage", "    "}
            _ -> {"Usage", "  "}
          end

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

        [title, "\n\n", padding, name, optarray, argslist]
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
            f -> {"Options", Enum.map(options, &format_usage_opt(&1, max_opt, wrapping, pad_io))}
          end

        opts = [title, "\n\n", optsdoc]
      end

      defp format_usage_opt_md({k, option}) do
        %Option{type: t, short: s, key: k, doc: doc, default: default, doc_arg: doc_arg} = option

        short =
          case s do
            nil -> []
            _ -> ["`-", Atom.to_string(s), "`, "]
          end

        name = k |> Atom.to_string() |> String.replace("_", "-")

        doc_arg =
          case t do
            :boolean -> []
            _ -> [" <", doc_arg, ">"]
          end

        long = ["`--", name, doc_arg, "`"]

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
            {_, {:default, v}} -> [doc, [" ", format_default_moduledoc(k, v)]]
          end

        ["* ", short, long, doc, "\n"]
      end

      defp format_usage_opt({k, option}, max_opt, wrapping, pad_io) do
        %Option{type: t, short: s, key: k, doc: doc, default: default, doc_arg: doc_arg} = option

        short =
          case s do
            nil -> "  "
            _ -> [?-, Atom.to_string(s)]
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
            {_, :skip} -> ensure_final_dot(doc)
            {_, {:default, v}} -> [ensure_final_dot(doc), " ", [format_default(k, v)]]
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

      defp ensure_string(str) when is_binary(str) do
        str
      end

      defp ensure_string(term) do
        to_string(term)
      rescue
        _ in Protocol.UndefinedError -> inspect(term)
      end

      defp format_default(k, value) when is_function(value, 1) do
        "Dynamic default value."
      end

      defp format_default(_, value) do
        ["Defaults to ", ensure_string(value), "."]
      end

      defp format_default_moduledoc(k, value) when is_function(value, 1) do
        info = Function.info(value)

        case Keyword.fetch!(info, :type) do
          :external ->
            module = Keyword.fetch!(info, :module)
            name = Keyword.fetch!(info, :name)
            ["Default value generated by `#{inspect(module)}.#{name}/1`."]

          _ ->
            format_default(k, value)
        end
      end

      defp format_default_moduledoc(k, value) do
        format_default(k, value)
      end
    end
  end
end
