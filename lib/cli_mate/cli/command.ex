defmodule CliMate.CLI.Command do
  alias CliMate.CLI.Argument
  alias CliMate.CLI.Option

  @moduledoc false

  @enforce_keys [:arguments, :options]
  defstruct [:arguments, :options, :module, :name]

  @type t :: %__MODULE__{
          arguments: [Argument.t()],
          options: [{atom, Option.t()}],
          module: module | nil,
          name: binary | nil
        }

  @help_option_def [type: :boolean, default: false, doc: "Displays this help."]

  def new(conf) do
    options =
      conf
      |> Keyword.get(:options, [])
      |> add_help()
      |> Enum.map(&build_option/1)

    arguments = conf |> Keyword.get(:arguments, []) |> build_args()
    name = conf |> Keyword.get(:name, nil)
    module = conf |> Keyword.get(:module, nil)
    %__MODULE__{options: options, arguments: arguments, name: name, module: module}
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
    {args, _} =
      Enum.map_reduce(list, nil, fn arg, last_unrequired ->
        arg = build_argument(arg)

        case arg do
          %{required: true} when last_unrequired == nil ->
            {arg, nil}

          %{key: key, required: true} ->
            raise ArgumentError,
                  "non-required arguments must be defined after required ones " <>
                    "but #{inspect(key)} was given after #{inspect(last_unrequired)}"

          %{key: key, required: false} ->
            {arg, key}
        end
      end)

    args
  end

  defp build_argument({key, conf}), do: Argument.new(key, conf)
end
