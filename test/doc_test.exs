defmodule CliMate.CLI.DocTest do
  use ExUnit.Case, async: true
  doctest CliMate.CLI, import: true
  doctest CliMate.CLI.Argument
  doctest CliMate.CLI.Command
  doctest CliMate.CLI.Option
end
