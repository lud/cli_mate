# CliMate

A lightweight, flexible Command-Line-Interface toolkit for Elixir applications.


## Features

* Command line options and arguments parser that extends [OptionParser](https://hexdocs.pm/elixir/OptionParser.html)
* Shell helpers for formatted output in releases where `Mix` is unavailable
* Automatic usage formatting for `--help` and `mix help` commands
* Support for custom type casting and validation


## Documentation

Detailed documentation is available on [HexDocs](https://hexdocs.pm/cli_mate):

* [Getting Started](https://hexdocs.pm/cli_mate/getting_started.html) - Getting started with CliMate


## Table of Contents

- [Features](#features)
- [Documentation](#documentation)
- [Table of Contents](#table-of-contents)
- [Installation](#installation)
- [Quick Example](#quick-example)
- [Building CLI Applications in Elixir](#building-cli-applications-in-elixir)
- [Migrating from older versions](#migrating-from-older-versions)
- [Roadmap](#roadmap)
- [License](#license)


## Installation

```elixir
def deps do
  [
    {:cli_mate, "~> 0.8", runtime: false},
  ]
end
```


## Quick Example

```elixir
defmodule Mix.Tasks.Example do
  import CliMate.CLI
  use Mix.Task

  @command name: "mix example",
           module: __MODULE__,
           options: [
             verbose: [
               short: :v,
               type: :boolean,
               default: false,
               doc: "Output debug info."
             ]
           ],
           arguments: [
             n: [type: :integer, doc: "The value to process."]
           ]

  @impl true
  def run(argv) do
    command = parse_or_halt!(argv, @command)

    if command.options.verbose do
      writeln("Hello!")
    end

    SomeModule.do_something_with(command.arguments.n)
  end
end
```


## Building CLI Applications in Elixir

Due to the startup time of the BEAM, it is generally discouraged to build
command line applications with Elixir.

While the startup problem is real, this is only important for small utilities
like `ls`, `grep` or `cat`. You surely do not want that delay when piping or
looping with those commands in bash scripts.

But for commands that are doing more, like deployments or asset bundling, or
tools that run for a while like credo or dialyzer it is totally fine. And you
get to write them with Elixir!

## Migrating from older versions

### Migration to version 0.8.0

Support for installable mix tasks is back, but now relies on code generation.

If your library was intended to be installed like this:

    mix archive.install hex your_library

This would not work when using CliMate because it would not embed the CLI code
in your code directly on compilation. This was dropped because maintenance of a full library wrapped in a `quote do` block was not perennial.

Since version 0.8.0, the `mix cli.embed` task will generate the CLI code
directly into your library:

    mix cli.embed MyApp.CLI lib/my_app/cli

Make sure to read the different options by calling `mix help cli.embed`.

When using code generation, CliMate should now be used as a dev dependency:

```elixir
def deps do
  [
    {:cli_mate, "~> 0.8", only: [:dev, :test], runtime: false},
  ]
end
```

Note that this is fully optional. If you are writing a mix task that can just
be installed as a regular dependency in other projects, that mix task can use
dependencies such as CliMate just as usual.

Code generation is intended to be used by mix tasks that are best used as
globally installed tasks, or escripts, but that still need to be able to load
mix projects (by loading `mix.exs` and projects code).

For regular applications that were using CliMate with either `use CliMate` or
`CliMate.extend_cli()`, there is a single change to perform, that is replacing
that line with:

```elixir
require CliMate.CLI
CliMate.CLI.extend()
```

### Migration to version 0.7.0

The original version of CliMate included the CLI code in a consumer module,
using `use CliMate`. This allowed library authors to use CliMate in mix tasks
that could be installed by users with `mix archive.install hex some_package`.
Archives installed that way cannot have dependencies so CliMate was providing a
way to use it anyway.

But this solution had too many problems regarding code loading with the recent
versions of Elixir. So we are stopping support for this feature.

The best way to provide commands with dependencies is to provide an
[escript](https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html) or something
like [burrito](https://github.com/burrito-elixir/burrito).


## Roadmap

* Merging code from Argument and Option for consistent capabilities
* Support for subcommands in escripts


## License

CliMate is released under the MIT License. See the [LICENSE](LICENSE.md) file for details.