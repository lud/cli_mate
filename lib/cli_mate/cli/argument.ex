defmodule CliMate.CLI.Argument do
  alias CliMate.CLI.OptsValidator

  @moduledoc """
  Describes an argument.

  When declaring a command, the `:arguments` entry is a keyword list that
  accepts these settings, all optional:

  * `:required` - A boolean. Arguments are required by default.
  * `:type` - `:string`, `:integer` or `:float`. Defaults to `:string`.
  * `:doc` - A string to document what the argument is for. This is not used at
    the moment but future releases will exploit it.
  * `:cast` - A fun accepting the value, or a `{module, function, arguments}`,
    returning a result tuple.  See the "Casting" section below for more
    information.
  * `:repeat` - A boolean, defines a variadic argument that accepts several
    values. This can only be enabled on the last argument.

  ### Casting

  When the `:cast` option is a fun, it will be called with the deserialized
  value. When it is an "MFA" tuple, the deserialized value will be prepended to
  the given arguments.

  #### Cast functions input

  What is a deserialized value though? By default it will be the raw string
  passed in the shell as command line arguments. But if the `:type` option is
  also defined to `:integer` or `:float`, your cast function will be called with
  the corresponding type. If that type deserialization fails, the cast function
  will not be called.

  #### Repeated arguments

  When the `:repeat` option is enabled, the cast function is called on each
  value individually, not on the entire list.

  #### Returning errors

  Cast functions must return `{:ok, value}` or `{:error, reason}`. The `reason`
  can be anything, but at the moment CliMate doesn't do any special formatting
  on it to display errors (besides calling `to_string/1` with a safe fallback to
  `inspect/1`). It is advised to return a meaningful error message as the
  reason.

  #### Compilation commands

  When commands are declared as a module attribute, you cannot use local
  functions definitions or the compilation will fail with "undefined function
  ...". You need to use a remote form by prefixing by `__MODULE__`, or use an
  MFA tuple.

      defmodule MyCommand do
        use Mix.Task

        @command name: "my command",
                 arguments: [
                   some_arg: [
                     cast: &__MODULE__.cast_some/1
                   ]
                 ]
      end

  """
  @enforce_keys [:key, :required, :cast, :doc, :type, :repeat]
  defstruct @enforce_keys

  @type vtype :: :integer | :float | :string
  @type caster :: (term -> {:ok, term} | {:error, term}) | {module, atom, [term]}
  @type t :: %__MODULE__{
          key: atom,
          required: boolean,
          type: vtype,
          doc: binary | nil,
          cast: nil | caster
        }

  @doc """
  Builds an argument struct from its key and settings.

  The accepted settings are listed in the module documentation. Raises an
  `ArgumentError` when the settings are invalid.

  ### Examples

  Settings that are not provided are given default values:

      iex> CliMate.CLI.Argument.new(:lang, [])
      %CliMate.CLI.Argument{key: :lang, required: true, cast: nil, doc: "", type: :string, repeat: false}
  """
  def new(key, conf) when is_atom(key) do
    settings = OptsValidator.validate!(conf, "argument #{inspect(key)}", &validate_setting/2)

    %__MODULE__{
      key: key,
      required: Map.get(settings, :required, true),
      cast: Map.get(settings, :cast),
      doc: Map.get(settings, :doc) || "",
      type: Map.get(settings, :type, :string),
      repeat: Map.get(settings, :repeat, false)
    }
  end

  def new(key, _conf) do
    raise ArgumentError, "invalid argument key, expected an atom, got: #{inspect(key)}"
  end

  defp validate_setting(:required, value), do: OptsValidator.boolean(value)

  defp validate_setting(:type, value),
    do: OptsValidator.one_of(value, [:string, :integer, :float])

  defp validate_setting(:doc, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:cast, value), do: OptsValidator.caster(value)
  defp validate_setting(:repeat, value), do: OptsValidator.boolean(value)
  defp validate_setting(_, _), do: :unknown
end
