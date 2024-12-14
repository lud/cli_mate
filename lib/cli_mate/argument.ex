defmodule CliMate.Argument do
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

  #### Returning errors

  Cast functions must return `{:ok, value}` or `{:error, reason}`. The `reason`
  can be anything, but at the moment CliMate does no spcial formatting on it to
  display errors (besides calling `to_string/1` with a safe fallback to
  `inspect/1`). It is advised to return a meaninful error message as the reason.

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
  @enforce_keys [:key, :required, :cast, :doc, :type]
  defstruct @enforce_keys

  @type vtype :: :integer | :float | :string
  @type t :: %__MODULE__{
          key: atom,
          required: boolean,
          type: vtype,
          doc: binary,
          cast: (term -> {:ok, term} | {:error, term}) | {module, atom, [term]}
        }

  def new(key, conf) when is_atom(key) and is_list(conf) do
    required = Keyword.get(conf, :required, true)
    cast = Keyword.get(conf, :cast, nil)

    doc = Keyword.get(conf, :doc, "")
    type = Keyword.get(conf, :type, :string)

    validate_type(type)
    validate_cast(cast)

    %__MODULE__{key: key, required: required, cast: cast, doc: doc, type: type}
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

  defp validate_type(type) do
    unless type in [:string, :float, :integer] do
      raise ArgumentError,
            "expected argument type to be one of :string, :float or :integer, got: #{inspect(type)}"
    end

    :ok
  end
end
