defmodule CliMate.DocTest do
  use ExUnit.Case, async: false
  doctest CliMate.CLI, import: true
end
