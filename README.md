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


## Installation & Use

```elixir
def deps do
  [
    {:cli_mate, "~> 0.3", runtime: false},
  ]
end
```

All available functions of this library are defined in `CliMate.CLI`.

If you want to use CLI Mate in a mix task that you will distribute as a
standalone command, you must define a wrapper module:

```elixir
defmodule App.CLI do
  use CliMate
end
```

This module will export the exact same functionality as `CliMate.CLI`.

Make sure to provide `runtime: false` in your dependency declaration for
`:cli_mate`.


## Providing usage block in `mix help my.command`

The default usage block rendered when calling `mix my.command --help` is not
included by default when calling `mix help my.command`.

If you want, you can include it manually by adding it to the `@moduledoc`
attribute:

```elixir
# Use the CLI module that you defined if you need to.

alias App.CLI

# Define the command once, so you can use it in module docs and in the `run/1`
# callback.

@command [
  module: __MODULE__,
  options: [
    some_option: [
      type: :boolean,
      short: :s,
      doc: "Does something, for sure."
    ]
  ]
]

# Generate the usage block and include it to @moduledoc, with the appropriate
# format.

@moduledoc """
This command does things!

#{CLI.format_usage(@command, format: :moduledoc)}
"""

# Since we defined the options in a @command attribute, we can now reuse it in
# the code.

@impl Mix.Task
def run(argv) do
  %{options: options,arguments: arguments} = CLI.parse_or_halt!(argv, @command)
  # ...
end
```
