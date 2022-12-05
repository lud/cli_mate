# CliMate

This package implements a simple wrapper around
[OptionParser](https://hexdocs.pm/elixir/OptionParser.html) that allows to
define options, documentation and arguments in one data structure.

It also provides classic printing of "usage" for a command.

This package is targeted at standalone mix commands, _i.e._ commands defined in
packages installed globally (for instance `mix archive.install hex
some_package`). Those packages do not contain their dependencies, and for that
reason, all code defined in CliMate is injected in the consumer code.

For this reason, CliMate only defines a small set of  features.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cli_mate` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cli_mate, "~> 0.1.0", runtime: false},
  ]
end
```

All available functions of this library are defined in `CliMate.CLI`.

If you want to import the package in your own package so it does not depend on
CliMate, you must define a wrapper module:

```elixir
defmodule App.CLI do
  use CliMate
end
```

This module will export the exact same functionality as `CliMate.CLI`.

