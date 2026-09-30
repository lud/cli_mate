defmodule CliMate.CLI.Option do
  alias CliMate.CLI.OptsValidator

  @moduledoc """
  Describes an option.

  When declaring a command, the `:options` entry is a keyword list that accepts
  these settings, all optional:

  * `:type` - Uses the `OptionParser` module under the hood, so the following
    types are accepted:
    * `:boolean` - If the default value is `true`, `OptionParser` supports the
      `--no-` prefix to the options.
    * `:count` - Counts the number of times the flag is given.
    * `:integer` - Value is parsed or an error is returned.
    * `:float` - Same as `:integer`.
    * `:string` - Value is used as-is.
  * `:doc` - A string describing the role of the option. It is displayed in the
    usage block shown with `--help` or `mix help`.
  * `:short` - A single letter atom like `:a`, `:b`, etc. For instance with
    these options:

        @command options: [
          name: [short: :n]
        ]

  * `:default` - The default value to set if the option is not given. See the
    "Default values" section below.

    The command line will accept both `--name` and `-n` switches.

  * `:keep` - A boolean. This flag is used with `OptionParser`. When `true`
    duplicate options will not override each other but will rather be
    accumulated in a list. The option value will always be a list even when
    provided a single time in the command line arguments. The option will also
    be present, as an empty list, if the option is not given in command line
    arguments.
  * `:doc_arg` - A string to display in the usage block. Defaults the type of
    the option, as in:

    ```text
    Options

      -n --some-int <integer>  This option does not define :doc_arg.
      -o --other-int <other>   Here "other" was provided as :doc_arg.
    ```
  * `:default_doc` - The string to output when CliMate does not know how to
    display the default value. That is, when the default value is defined by a
    function. Not used when `:default` is not defined.
  * `:cast` - A fun accepting the value, or a `{module, function, arguments}`,
    returning a result tuple. See the "Casting" section below for more
    information.
  * `:deprecated` - Accepts a boolean or a string like `"use --bar instead"`.
    When the option is provided on the command line, a warning is printed once
    on stderr: `option --foo is deprecated` for `true`, or `option --foo is
    deprecated, use --bar instead` for a string. The string is where the
    deprecation is explained, as `:doc` is ignored for deprecated options.
    Deprecated options are hidden from usage blocks and generated docs, but
    their value is still parsed and returned like any other option.

  ### Casting

  When the `:cast` option is a fun, it will be called with the parsed value
  (after `OptionParser` has converted it to the appropriate type). When it is an
  "MFA" tuple, the parsed value will be prepended to the given arguments.

  Cast functions must return `{:ok, value}` or `{:error, reason}`. The `reason`
  can be anything, but at the moment CliMate doesn't do any special formatting
  on it to display errors (besides calling `to_string/1` with a safe fallback to
  `inspect/1`). It is advised to return a meaningful error message as the
  reason.

  When the `:keep` option is enabled, the cast function is called on each value
  individually, not on the entire list.

  Note that cast functions are NOT applied to default values.

  ### Default values

  Default values can be omitted, in that case, the option will not be present at
  all when parsing the command line arguments. This is especially important for
  booleans, where one would expect that they automatically default to false. It
  is not the case.

  When defined, a default value can be:

  * A raw value, that is anything that is not a function. This value will be
    used as the default value.
  * A function of arity zero. This function will be called when the option is
    not provided in the command line and the result value will be used as the
    default value. For instance `fn -> 123 end` or `&default_for_some_opt/0`.
  * A function of arity one. This function will be called with the option key as
    its argument. For instance, passing `&default_opt/1` as the `:default` for
    an option definition allow to define the following function:

        defp default_opt(:port), do: 4000
        defp default_opt(:scheme), do: "http"

  When the command is defined in a module attribute, you need to pass the module
  prefix or the compilation will fail:

      defmodule MyCommand do
        use Mix.Task

        @command name: "my command",
                 options: [
                   some_arg: [
                     default: &__MODULE__.cast_some/1
                   ]
                 ]
      end

  """
  @enforce_keys [
    :key,
    :doc,
    :type,
    :short,
    :default,
    :keep,
    :doc_arg,
    :default_doc,
    :cast,
    :deprecated
  ]
  defstruct @enforce_keys

  @types [:boolean, :count, :integer, :float, :string]

  @type vtype :: :integer | :float | :string | :count | :boolean
  @type caster :: (term -> {:ok, term} | {:error, term}) | {module, atom, [term]}
  @type t :: %__MODULE__{
          key: atom,
          doc: String.t(),
          type: vtype,
          short: atom,
          default: term,
          keep: boolean,
          doc_arg: String.t(),
          default_doc: String.t(),
          cast: nil | caster,
          deprecated: nil | boolean | String.t()
        }

  @doc """
  Builds an option struct from its key and settings.

  The accepted settings are listed in the module documentation. Raises an
  `ArgumentError` when the settings are invalid.

  ### Examples

  Settings that are not provided are given default values:

      iex> option = CliMate.CLI.Option.new(:verbose, type: :boolean, short: :v)
      iex> option.short
      :v
      iex> option.keep
      false
  """
  def new(key, conf) when is_atom(key) do
    settings = OptsValidator.validate!(conf, "option #{inspect(key)}", &validate_setting/2)

    keep = Map.get(settings, :keep, false)
    type = Map.get(settings, :type, :string)

    if keep and type == :count do
      raise ArgumentError, "option #{inspect(key)} cannot use keep: true with type: :count"
    end

    default =
      case Map.fetch(settings, :default) do
        {:ok, term} -> {:default, term}
        :error when keep -> {:default, []}
        :error -> :skip
      end

    %__MODULE__{
      key: key,
      doc: Map.get(settings, :doc) || "",
      type: type,
      short: Map.get(settings, :short),
      default: default,
      keep: keep,
      doc_arg: Map.get_lazy(settings, :doc_arg, fn -> default_doc_arg(type) end),
      default_doc: Map.get(settings, :default_doc),
      cast: Map.get(settings, :cast),
      deprecated: Map.get(settings, :deprecated)
    }
  end

  def new(key, _conf) do
    raise ArgumentError, "invalid option key, expected an atom, got: #{inspect(key)}"
  end

  defp validate_setting(:type, value), do: OptsValidator.one_of(value, @types)
  defp validate_setting(:doc, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:short, value), do: validate_short(value)
  defp validate_setting(:default, value), do: validate_default(value)
  defp validate_setting(:keep, value), do: OptsValidator.boolean(value)
  defp validate_setting(:doc_arg, value), do: OptsValidator.string(value)
  defp validate_setting(:default_doc, value), do: OptsValidator.optional_string(value)
  defp validate_setting(:cast, value), do: OptsValidator.caster(value)
  defp validate_setting(:deprecated, value), do: validate_deprecated(value)
  defp validate_setting(_, _), do: :unknown

  defp validate_short(nil), do: {:ok, nil}

  defp validate_short(short) when is_atom(short) and not is_boolean(short) do
    if String.match?(Atom.to_string(short), ~r/^\p{L}$/u),
      do: {:ok, short},
      else: {:error, "a single-letter atom"}
  end

  defp validate_short(_), do: {:error, "a single-letter atom"}

  defp validate_default(f)
       when is_function(f) and not is_function(f, 0) and not is_function(f, 1) do
    {:error, "a function of arity 0 or 1, or a non-function value"}
  end

  defp validate_default(value), do: {:ok, value}

  defp validate_deprecated(value) when is_boolean(value) when is_binary(value) when is_nil(value),
    do: {:ok, value}

  defp validate_deprecated(_), do: {:error, "a boolean, a string or nil"}

  defp default_doc_arg(:integer), do: "integer"
  defp default_doc_arg(:float), do: "float"
  defp default_doc_arg(:string), do: "string"
  defp default_doc_arg(:count), do: nil
  defp default_doc_arg(:boolean), do: nil

  @doc """
  Returns the option name in kebab case.
  """
  def cli_name(%__MODULE__{key: key}) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end
end
