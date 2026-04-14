defmodule CliMate.CLI.Command do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option

  @moduledoc """
  A behaviour to define module-based commands.

  A command is a keyword list (or a module implementing this behaviour) and
  accepts these top-level entries:

  * `:options` — option schema (see `CliMate.CLI.Option`).
  * `:arguments` — positional argument schema.
  * `:subcommands` — a keyword list of nested commands. A command cannot declare
    both `:arguments` and `:subcommands`; the first positional slot is consumed
    as the sub-command name. A sub-command value can be an inline keyword list,
    or a module implementing this behaviour.
  * `:execute` — a 1-arity function called with the parsed result. Also provided
    via the `execute/1` callback on module-based commands. When a command with
    `:execute` is selected, `CliMate.CLI.parse/2` returns the parsed map with an
    `:execute` key holding a zero-arity closure; calling it runs the function
    with the parsed map (minus the `:execute` key). Returns `nil` when no
    execute is defined or when `--help` was requested.
  * `:name`, `:version`, `:doc` — metadata used by `format_usage/2`.

  ### Option inheritance across sub-commands

  Options declared on a parent command are inherited by sub-commands and can be
  passed on any level where the command is being parsed. Merging rules for the
  final `:options` map:

  * A value explicitly parsed from argv at any level wins and is never
    overwritten by a default from a deeper level.
  * If an option is not passed on argv, the default from the deepest level that
    declares the option is used. Redefining an option at a child level replaces
    the parent entry entirely (including `:short` and `:keep`).
  * `:keep` lists are not accumulated across levels: the list parsed at a given
    level replaces any previously accumulated list.
  """

  @type command :: [command_opt]
  @type command_opt ::
          {:name, String.t()}
          | {:version, String.t()}
          | {:module, module}
          | {:doc, String.t()}
          | {:options, [{atom, option}]}
          | {:arguments, [{atom, argument}]}
          | {:subcommands, [{atom, command | module | t}]}
          | {:execute, (map -> term)}

  @type option :: [option_opt]
  @type option_opt ::
          {:key, atom}
          | {:doc, String.t()}
          | {:type, Option.vtype()}
          | {:short, atom}
          | {:default, term}
          | {:keep, boolean}
          | {:doc_arg, String.t()}
          | {:default_doc, String.t()}

  @type argument :: [argument_opt]
  @type argument_opt ::
          {:key, atom}
          | {:required, boolean}
          | {:type, Argument.vtype()}
          | {:doc, binary | nil}
          | {:cast, nil | Argument.caster()}

  @doc """
  Returns a command definition to be used with the parser, or invoked as a sub
  command.
  """
  @callback command :: command
  @callback execute(CliMate.CLI.parsed()) :: term

  @optional_callbacks execute: 1

  @enforce_keys [:arguments, :options, :subcommands]
  defstruct [:arguments, :options, :module, :name, :version, :doc, :subcommands, :execute]

  @type t :: %__MODULE__{
          arguments: [Argument.t()],
          options: [{atom, Option.t()}],
          module: module | nil,
          name: binary | nil,
          version: binary | nil,
          doc: binary | nil,
          subcommands: [t],
          execute: (-> term) | nil
        }

  @help_option_def [type: :boolean, default: false, doc: "Displays this help."]

  def new(conf) when is_list(conf) do
    options =
      conf
      |> Keyword.get(:options, [])
      |> add_help()
      |> Enum.map(&build_option/1)

    arguments = conf |> Keyword.get(:arguments, []) |> build_args()
    subcommands = conf |> Keyword.get(:subcommands, []) |> validate_subcommands()
    execute = conf |> Keyword.get(:execute, nil) |> validate_execute()

    case {arguments, subcommands} do
      {[_ | _], [_ | _]} ->
        raise ArgumentError,
              "cannot define both arguments and subcommands, " <>
                "got arguments: #{inspect(arguments)}, subcommands: #{inspect(subcommands)}"

      _ ->
        :ok
    end

    %__MODULE__{
      options: options,
      arguments: arguments,
      name: Keyword.get(conf, :name, nil),
      module: Keyword.get(conf, :module, nil),
      version: Keyword.get(conf, :version, nil),
      doc: Keyword.get(conf, :doc, nil),
      subcommands: subcommands,
      execute: execute
    }
  end

  def new(module) when is_atom(module) do
    base = module.command()

    spec =
      if function_exported?(module, :execute, 1) do
        Keyword.merge([module: module, execute: &module.execute/1], base)
      else
        Keyword.put_new(base, :module, module)
      end

    new(spec)
  end

  defp add_help(options) do
    :ok =
      case Keyword.fetch(options, :help) do
        {:ok, _} -> raise ArgumentError, "the :help option cannot be overriden"
        :error -> :ok
      end

    # Help should be at the end for usage block
    options ++ [{:help, @help_option_def}]
  end

  defp build_option({key, conf}), do: {key, Option.new(key, conf)}

  defp build_args(list) do
    # non-required arguments must be last
    # a variadic argument must be the last one
    prev = %{not_required: nil, variadic: nil}

    {args, _} = Enum.map_reduce(list, prev, &reduce_args/2)
    args
  end

  defp reduce_args(arg, prev) do
    arg = build_argument(arg)

    case arg do
      %{key: key, required: true} when prev.not_required != nil ->
        raise ArgumentError,
              "non-required arguments must be defined after required ones " <>
                "but #{inspect(key)} was defined after #{inspect(prev.not_required)}"

      %{key: key} when prev.variadic != nil ->
        raise ArgumentError,
              "repeated argument must be the last argument " <>
                "but #{inspect(key)} was defined after #{inspect(prev.variadic)}"

      %{key: key} = arg ->
        prev = if arg.required, do: prev, else: %{prev | not_required: key}
        prev = if arg.repeat, do: %{prev | variadic: key}, else: prev

        {arg, prev}
    end
  end

  defp build_argument({key, conf}), do: Argument.new(key, conf)

  defp validate_subcommands(list) when is_list(list) do
    list
  end

  defp validate_subcommands(other) do
    raise ArgumentError,
          "invalid subcommands, expected keyword list, got #{inspect(other)}"
  end

  defp validate_execute(nil), do: nil
  defp validate_execute(f) when is_function(f, 1), do: f

  defp validate_execute(other) do
    raise ArgumentError,
          "invalid :execute option expected function of arity 1 or nil, got: #{inspect(other)}"
  end

  def resolve_subcommand(command, bin_key) do
    String.to_existing_atom(bin_key)
  rescue
    ArgumentError -> {:error, {:unknown_subcommand, bin_key}}
  else
    key -> do_resolve_subcommand(command, key, bin_key)
  end

  defp do_resolve_subcommand(command, key, bin_key) do
    case Keyword.fetch(command.subcommands, key) do
      {:ok, opts} when is_list(opts) ->
        {:ok, key, new(opts)}

      {:ok, module} when is_atom(module) ->
        {:ok, key, new(module)}

      :error ->
        {:error, {:unknown_subcommand, bin_key}}
    end
  end
end
