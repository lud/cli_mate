defmodule CliMate.CLI.Command do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option
  alias CliMate.CLI.OptsValidator

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
  passed on any level where the command is being parsed. Arguments given before
  a sub-command name are parsed with the options known at that level, and
  arguments given after it with the options of the sub-command, including the
  inherited ones.

  * Redefining an option at a child level replaces the parent entry entirely,
    including `:short`, `:default`, `:cast` and `:deprecated`. The child
    definition must keep the same `:type` and `:keep` settings, otherwise an
    `ArgumentError` is raised. Use `:cast` to change the final value.
  * When a child option uses the same `:short` as an inherited option, the
    short refers to the child option after the sub-command name. The inherited
    option is still available with its long name.
  * Values given on several levels are combined as if they were given on a
    single level: the last value wins, `:keep` lists are concatenated and
    `:count` occurrences are summed.
  * The default value, the cast function and the deprecation warning are taken
    from the definition of the selected sub-command, whatever the level the
    value was given on.
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
          {:doc, String.t()}
          | {:type, Option.vtype()}
          | {:short, atom}
          | {:default, term}
          | {:keep, boolean}
          | {:doc_arg, String.t()}
          | {:default_doc, String.t()}
          | {:cast, nil | Option.caster()}
          | {:deprecated, nil | boolean | String.t()}

  @type argument :: [argument_opt]
  @type argument_opt ::
          {:required, boolean}
          | {:type, Argument.vtype()}
          | {:doc, binary | nil}
          | {:cast, nil | Argument.caster()}
          | {:repeat, boolean}

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
          subcommands: [{atom, command | module | t}],
          execute: (-> term) | nil
        }

  @help_option_def [type: :boolean, default: false, doc: "Displays this help."]

  @doc """
  Builds a command struct from a keyword definition, or from a module
  implementing this behaviour.

  The accepted entries are listed in the module documentation. Raises an
  `ArgumentError` for invalid definitions, for instance when a command declares
  both `:arguments` and `:subcommands`.

  ### Examples

  The returned struct holds the normalized options, including the automatic
  `:help` option:

      iex> command = CliMate.CLI.Command.new(name: "hello", options: [upcase: [type: :boolean]])
      iex> command.name
      "hello"
      iex> Keyword.keys(command.options)
      [:upcase, :help]
  """
  def new(command), do: build(command, nil)

  defp build(%__MODULE__{} = command, _subject) do
    command
  end

  defp build(conf, subject) when is_list(conf) do
    subject = subject || command_subject(conf)
    settings = OptsValidator.validate!(conf, subject, &validate_setting/2)

    options = settings |> Map.get(:options, []) |> build_options(subject)
    arguments = settings |> Map.get(:arguments, []) |> build_args(subject)
    subcommands = settings |> Map.get(:subcommands, []) |> validate_subcommands(subject)

    case {arguments, subcommands} do
      {[_ | _], [_ | _]} ->
        raise ArgumentError,
              "cannot define both arguments and subcommands in #{subject}, " <>
                "got arguments: #{inspect(Enum.map(arguments, & &1.key))}, " <>
                "subcommands: #{inspect(Keyword.keys(subcommands))}"

      _ ->
        :ok
    end

    %__MODULE__{
      options: options,
      arguments: arguments,
      name: Map.get(settings, :name),
      module: Map.get(settings, :module),
      version: Map.get(settings, :version),
      doc: Map.get(settings, :doc),
      subcommands: subcommands,
      execute: Map.get(settings, :execute)
    }
  end

  defp build(module, subject) when is_atom(module) do
    if not (Code.ensure_loaded?(module) and function_exported?(module, :command, 0)) do
      raise ArgumentError,
            "invalid #{subject || "command"}, expected a module implementing command/0, " <>
              "got: #{inspect(module)}"
    end

    base = module.command()

    if not is_list(base) do
      raise ArgumentError,
            "invalid #{subject || "command"}, expected #{inspect(module)}.command/0 " <>
              "to return a keyword list, got: #{inspect(base)}"
    end

    spec =
      if function_exported?(module, :execute, 1) do
        Keyword.merge([module: module, execute: &module.execute/1], base)
      else
        Keyword.put_new(base, :module, module)
      end

    build(spec, subject)
  end

  defp build(other, subject) do
    raise ArgumentError,
          "invalid #{subject || "command"}, expected a keyword list or a module, " <>
            "got: #{inspect(other)}"
  end

  defp command_subject(%__MODULE__{name: name}) when is_binary(name),
    do: "command #{inspect(name)}"

  defp command_subject(%__MODULE__{module: mod}) when mod != nil, do: "command #{inspect(mod)}"
  defp command_subject(%__MODULE__{}), do: "command"

  defp command_subject(conf) do
    case {Keyword.get(conf, :name), Keyword.get(conf, :module)} do
      {name, _} when is_binary(name) -> "command #{inspect(name)}"
      {_, mod} when is_atom(mod) and mod != nil -> "command #{inspect(mod)}"
      _ -> "command"
    end
  end

  defp validate_setting(:name, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:version, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:doc, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:module, value) when is_atom(value), do: {:ok, value}
  defp validate_setting(:module, _), do: {:error, "a module"}
  defp validate_setting(:options, value), do: OptsValidator.keyword_list(value)
  defp validate_setting(:arguments, value), do: OptsValidator.keyword_list(value)
  defp validate_setting(:subcommands, value), do: OptsValidator.keyword_list(value)
  defp validate_setting(:execute, value) when is_function(value, 1), do: {:ok, value}
  defp validate_setting(:execute, nil), do: {:ok, nil}
  defp validate_setting(:execute, _), do: {:error, "a function of arity 1 or nil"}
  defp validate_setting(_, _), do: :unknown

  defp build_options(options, subject) do
    :ok = OptsValidator.duplicate_keys!(options, "option", subject)

    options
    |> add_help(subject)
    |> Enum.map(fn {key, conf} -> {key, Option.new(key, conf)} end)
    |> tap(&check_duplicate_shorts(&1, subject))
  end

  defp add_help(options, subject) do
    :ok =
      case Keyword.fetch(options, :help) do
        {:ok, _} -> raise ArgumentError, "the :help option cannot be overriden in #{subject}"
        :error -> :ok
      end

    # Help should be at the end for usage block
    options ++ [{:help, @help_option_def}]
  end

  defp check_duplicate_shorts(options, subject) do
    Enum.reduce(options, %{}, fn
      {_, %{short: nil}}, seen ->
        seen

      {key, %{short: short}}, seen ->
        case seen do
          %{^short => other} ->
            raise ArgumentError,
                  "options #{inspect(other)} and #{inspect(key)} use the same short " <>
                    "#{inspect(short)} in #{subject}"

          _ ->
            Map.put(seen, short, key)
        end
    end)
  end

  defp build_args(list, subject) do
    :ok = OptsValidator.duplicate_keys!(list, "argument", subject)

    # non-required arguments must be last
    # a variadic argument must be the last one
    prev = %{not_required: nil, variadic: nil}

    {args, _} = Enum.map_reduce(list, prev, &reduce_args(&1, &2, subject))
    args
  end

  defp reduce_args({key, conf}, prev, subject) do
    arg = Argument.new(key, conf)

    case arg do
      %{key: key, required: true} when prev.not_required != nil ->
        raise ArgumentError,
              "non-required arguments must be defined after required ones " <>
                "but #{inspect(key)} was defined after #{inspect(prev.not_required)} in #{subject}"

      %{key: key} when prev.variadic != nil ->
        raise ArgumentError,
              "repeated argument must be the last argument " <>
                "but #{inspect(key)} was defined after #{inspect(prev.variadic)} in #{subject}"

      %{key: key} = arg ->
        prev = if arg.required, do: prev, else: %{prev | not_required: key}
        prev = if arg.repeat, do: %{prev | variadic: key}, else: prev

        {arg, prev}
    end
  end

  defp validate_subcommands(list, subject) do
    :ok = OptsValidator.duplicate_keys!(list, "sub-command", subject)

    Enum.each(list, fn
      {_, sub} when is_list(sub) when is_atom(sub) when is_struct(sub, __MODULE__) ->
        :ok

      {key, sub} ->
        raise ArgumentError,
              "invalid sub-command #{inspect(key)} of #{subject}, " <>
                "expected a keyword list or a module, got: #{inspect(sub)}"
    end)

    list
  end

  @doc false
  def build_subcommands(command) do
    Enum.map(command.subcommands, fn {key, sub} ->
      {key, build_subcommand(command, key, sub)}
    end)
  end

  defp build_subcommand(command, key, sub) do
    build(sub, "sub-command #{inspect(key)} of #{command_subject(command)}")
  end

  @doc """
  Resolves a sub-command name given on the command line into its definition
  from the parent command.

  Returns `{:ok, key, sub_command}` where `key` is the atom form of `bin_key`
  and `sub_command` is the resolved definition built with `new/1`. Returns
  `{:error, {:unknown_subcommand, bin_key}}` when the name matches no declared
  sub-command.
  """
  def resolve_subcommand(command, bin_key) do
    String.to_existing_atom(bin_key)
  rescue
    ArgumentError -> {:error, {:unknown_subcommand, bin_key}}
  else
    key -> do_resolve_subcommand(command, key, bin_key)
  end

  defp do_resolve_subcommand(command, key, bin_key) do
    case Keyword.fetch(command.subcommands, key) do
      {:ok, sub} ->
        {:ok, key, build_subcommand(command, key, sub)}

      :error ->
        {:error, {:unknown_subcommand, bin_key}}
    end
  end
end
