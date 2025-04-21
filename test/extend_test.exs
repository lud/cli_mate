defmodule CliMate.CLI.ExtendTest do
  use ExUnit.Case, async: true

  test "modules can extend the cli" do
    defmodule ExtendsTheCLI do
      require(CliMate.CLI).extend()
    end

    exports = ExtendsTheCLI.module_info(:exports)

    assert {:color, 2} in exports
    assert {:debug, 1} in exports
    assert {:error, 1} in exports
    assert {:format_usage, 1} in exports
    assert {:format_usage, 2} in exports
    assert {:halt, 0} in exports
    assert {:halt, 1} in exports
    assert {:halt_error, 1} in exports
    assert {:halt_error, 2} in exports
    assert {:halt_success, 1} in exports
    assert {:parse, 2} in exports
    assert {:parse_or_halt!, 2} in exports
    assert {:put_shell, 1} in exports
    assert {:shell, 0} in exports
    assert {:success, 1} in exports
    assert {:warn, 1} in exports
    assert {:writeln, 1} in exports

    refute {:_halt, 1} in exports
    refute {:_print, 3} in exports
    refute {:safe_to_string, 1} in exports
  end
end
