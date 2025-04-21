defmodule CliMate do
  @moduledoc """
  This module is the base namespace for the `:cli_mate` application.

  Most interactions with this library will be made through the `CliMate.CLI`
  module.


  ### Deprecation for `use CliMate` {: .warning}

  Including all CLI code in your own module is no longer supported and will be
  removedin a future release.

  Please see
  https://github.com/lud/cli_mate?tab=readme-ov-file#migration-to-version-100

  If you still want to extend the CLI module to add your own helpers, you can use
  the following:

      require CliMate.CLI
      CliMate.CLI.extend()

  This will import and re-export all the CLI exported functions into your module.
  """

  @deprecated "import or extend CliMate.CLI"
  defmacro __using__(_) do
    quote do
      CliMate.extend_cli()
    end
  end

  @doc false
  defmacro extend_cli do
    quote do
      require CliMate.CLI
      CliMate.CLI.extend()
    end
  end
end
