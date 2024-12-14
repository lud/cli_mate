defmodule CliMate.Command do
  alias CliMate.Argument
  alias CliMate.Option

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

    arguments = conf |> Keyword.get(:arguments, []) |> Enum.map(&build_argument/1)
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
  defp build_argument({key, conf}), do: Argument.new(key, conf)
end
