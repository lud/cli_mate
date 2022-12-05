defmodule CliMate do
  defmacro __using__(_) do
    cli_mod = __CALLER__.module

    quote bind_quoted: [cli_mod: cli_mod], location: :keep, generated: true do
      #

      # -- Defining the shell -------------------------------------------------

      # Here we just basically rewrite what mix does, because we do not want to
      # rely on Mix to be started if we build escripts.

      def put_shell(module) do
        :persistent_term.put({__MODULE__, :shell}, module)
      end

      def shell do
        :persistent_term.get({__MODULE__, :shell}, __MODULE__)
      end

      # -- Emitting messages to the console -----------------------------------

      @doc false
      def print(output, _kind, iodata) do
        IO.puts(output, IO.ANSI.format(iodata))
      end

      def color(color, iodata) do
        [color, iodata]
      end

      def error(iodata) do
        shell().print(:stderr, :error, color(:red, iodata))
      end

      def debug(iodata) do
        shell().print(:stdio, :debug, color(:cyan, iodata))
      end

      defmodule ProcessShell do
        @doc false
        def cli_mod, do: unquote(cli_mod)

        @doc false
        def print(_output, kind, iodata) do
          send(message_target(), {cli_mod(), kind, format_message(iodata)})
        end

        @doc false
        def format_message(iodata) do
          iodata
          |> IO.ANSI.format(false)
          |> :erlang.iolist_to_binary()
        end

        defp message_target() do
          case Process.get(:"$callers") do
            [parent | _] -> parent
            _ -> self()
          end
        end
      end

      # -- Defining commands --------------------------------------------------

      defmodule Option do
        @moduledoc false
        @enforce_keys [:key, :doc, :type, :short, :default, :keep]
        defstruct @enforce_keys

        @type vtype :: :integer | :float | :string | :count | :boolean
        @type t :: %__MODULE__{
                key: atom,
                doc: binary,
                type: vtype,
                short: atom,
                default: term,
                keep: boolean
              }
      end

      defp build_option({key, conf}) when is_atom(key) and is_list(conf) do
        keep = Keyword.get(conf, :keep, false)
        type = Keyword.get(conf, :type, :string)
        doc = Keyword.get(conf, :doc, "")
        short = Keyword.get(conf, :short, nil)

        default =
          case Keyword.fetch(conf, :default) do
            {:ok, term} -> {:default, term}
            :error -> :skip
          end

        opt = %Option{key: key, doc: doc, type: type, short: short, default: default, keep: keep}
        {key, opt}
      end

      defmodule Argument do
        @moduledoc false
        @enforce_keys [:key, :required, :cast]
        defstruct @enforce_keys

        @type t :: %__MODULE__{
                required: boolean,
                key: atom,
                cast: (term -> term) | {module, atom, [term]}
              }
      end

      defp build_argument({key, conf}) when is_atom(key) and is_list(conf) do
        required = Keyword.get(conf, :required, false)
        cast = Keyword.get(conf, :cast, &{:ok, &1})
        %Argument{key: key, required: required, cast: cast}
      end

      # -- Parser -------------------------------------------------------------

      def parse(argv, command) when is_list(command) do
        options = command |> Keyword.get(:options, []) |> Enum.map(&build_option/1)
        arguments = command |> Keyword.get(:arguments, []) |> Enum.map(&build_argument/1)
        strict = Enum.map(options, fn {key, opt} -> {key, opt_to_switch(opt)} end)
        aliases = Enum.flat_map(options, fn {_, opt} -> opt_alias(opt) end)

        with {parsed_options, parsed_arguments, []} <-
               OptionParser.parse(argv, strict: strict, aliases: aliases),
             {:ok, options_found} <- take_opts(options, parsed_options),
             {:ok, arguments_found} <- take_args(arguments, parsed_arguments) do
          {:ok, %{options: options_found, arguments: arguments_found}}
        else
          {_, _, invalid} -> {:error, {:invalid, invalid}}
          {:error, _} = err -> err
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

      def get_opt_value(opts, key, default) do
        case Keyword.fetch(opts, key) do
          :error ->
            case default do
              {:default, v} -> {:ok, v}
              :skip -> :skip
            end

          {:ok, v} ->
            {:ok, v}
        end
      end

      defp collect_list_option(opts, key) do
        opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
      end

      defp take_args(schemes = task, args) do
        take_args(schemes, args, %{})
      end

      defp take_args([%{required: true, key: key} | _], [], _acc) do
        {:error, {:argument_missing, key}}
      end

      defp take_args([%{key: key, cast: cast} | schemes], [value | argv], acc) do
        case cast.(value) do
          {:ok, casted} ->
            acc = Map.put(acc, key, casted)
            take_args(schemes, argv, acc)

          {:error, reason} ->
            {:error, {:argument_cast, key, reason}}

          other ->
            {:error, {:argument_cast, key, {:bad_return, other}}}
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
    end
  end
end
