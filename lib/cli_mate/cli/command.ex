defmodule CliMate.CLI.Command do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option

  @moduledoc """
  A behaviour to define module-based commands.
  """

  @type command :: [command_opt]
  @type command_opt ::
          {:name, String.t()}
          | {:version, String.t()}
          | {:module, module}
          | {:doc, String.t()}
          | {:options, [{atom, option}]}
          | {:arguments, [{atom, argument}]}

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

  @enforce_keys [:arguments, :options]
  defstruct [:arguments, :options, :module, :name, :version, :doc]

  @type t :: %__MODULE__{
          arguments: [Argument.t()],
          options: [{atom, Option.t()}],
          module: module | nil,
          name: binary | nil,
          version: binary | nil,
          doc: binary | nil
        }

  @help_option_def [type: :boolean, default: false, doc: "Displays this help."]

  def new(conf) do
    options =
      conf
      |> Keyword.get(:options, [])
      |> add_help()
      |> Enum.map(&build_option/1)

    arguments = conf |> Keyword.get(:arguments, []) |> build_args()

    %__MODULE__{
      options: options,
      arguments: arguments,
      name: Keyword.get(conf, :name, nil),
      module: Keyword.get(conf, :module, nil),
      version: Keyword.get(conf, :version, nil),
      doc: Keyword.get(conf, :doc, nil)
    }
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
end
