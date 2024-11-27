defmodule CliMate do
  @deprecated "just import CliMate.CLI"
  defmacro __using__(_) do
    quote do
      IO.warn("""
      TODO delegate all functions to CliMate.CLI

      You can directly import CliMate.CLI
      """)
    end
  end
end
