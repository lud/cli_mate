defmodule CliMate.Option do
  @moduledoc false
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
          doc_arg: binary
        }

  def new(key, conf) when is_atom(key) and is_list(conf) do
    keep = Keyword.get(conf, :keep, false)
    type = Keyword.get(conf, :type, :string)
    doc = Keyword.get(conf, :doc, "")
    short = Keyword.get(conf, :short, nil)
    doc_arg = Keyword.get(conf, :doc_arg, Atom.to_string(type))
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
end
