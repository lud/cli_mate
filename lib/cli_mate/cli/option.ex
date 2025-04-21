defmodule CliMate.CLI.Option do
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

  Note that when the command is defined in a module attribute, you need to pass
  the module prefix or the compilation will fail:

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
  @enforce_keys [:key, :doc, :type, :short, :default, :keep, :doc_arg, :default_doc]
  defstruct @enforce_keys

  @type vtype :: :integer | :float | :string | :count | :boolean
  @type t :: %__MODULE__{
          key: atom,
          doc: binary,
          type: vtype,
          short: atom,
          default: term,
          keep: boolean,
          doc_arg: binary,
          default_doc: binary
        }

  def new(key, conf) when is_atom(key) and is_list(conf) do
    keep = Keyword.get(conf, :keep, false)
    type = Keyword.get(conf, :type, :string)
    doc = Keyword.get(conf, :doc, "")
    short = Keyword.get(conf, :short, nil)
    doc_arg = Keyword.get_lazy(conf, :doc_arg, fn -> default_doc_arg(type) end)
    default_doc = Keyword.get(conf, :default_doc, nil)

    default =
      case Keyword.fetch(conf, :default) do
        {:ok, term} -> {:default, term}
        :error when type == :boolean -> :skip
        :error -> :skip
      end

    %__MODULE__{
      key: key,
      doc: doc,
      type: type,
      short: short,
      default: default,
      keep: keep,
      doc_arg: doc_arg,
      default_doc: default_doc
    }
  end

  defp default_doc_arg(:integer), do: "integer"
  defp default_doc_arg(:float), do: "float"
  defp default_doc_arg(:string), do: "string"
  defp default_doc_arg(:count), do: nil
  defp default_doc_arg(:boolean), do: nil
end
