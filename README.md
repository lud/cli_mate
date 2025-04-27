# CliMate

A Command-Line-Interface solution for Elixir.

This library provides:

* A command line options and arguments parser implemented as a lightweight
  wrapper around [OptionParser](https://hexdocs.pm/elixir/OptionParser.html)
  that allows to define options, documentation and arguments in one data
  structure.
* Shell helpers to format shell outputs for releases where `Mix` is not
  available.
* Usage formatting and printing for `--help` and `mix help`.


## Table of contents

- [Table of contents](#table-of-contents)
- [Installation](#installation)
- [Basic usage](#basic-usage)
  - [Describe a command](#describe-a-command)
  - [Provide options and arguments docs for `mix help`](#provide-options-and-arguments-docs-for-mix-help)
  - [Parse the command arguments](#parse-the-command-arguments)
  - [Display the usage block](#display-the-usage-block)
- [Migration to version 0.7.0](#migration-to-version-070)
- [Building CLI applications in Elixir](#building-cli-applications-in-elixir)
- [Roadmap](#roadmap)


## Installation

```elixir
def deps do
  [
    {:cli_mate, "~> 0.7",runtime: false},
  ]
end
```

## Basic usage

To illustrate how that library work we will implement an example Mix task that
prints an integer in base 2 or 8.


The first step is to declare the module as a Mix task and alias the
`CliMate.CLI` module (or import it!).

```elixir
defmodule Mix.Tasks.Example do
  alias CliMate.CLI
  use Mix.Task

  # ...
end
```

### Describe a command

Then we define a command in your module. That command can be defined as a
variable directly in the `run/1` callback, or returned by a function, etc. It's
a simple raw value. In this example we define it as a module attribute so we can
print the usage for `mix help`.

```elixir
  @command name: "mix example",
           options: [
             verbose: [
               short: :v,
               type: :boolean,
               default: false,
               doc: "Output debug info about the command."
             ]
           ],
           arguments: [
             n: [type: :integer],
             base: [cast: &__MODULE__.cast_base/1]
           ]
```

We gave `"mix example"` as the name because this is how it is supposed to be
invoked. This we be displayed in the help and usage generated text. If you are
building an escript this should be the name of your executable instead.

We can now declare the documentation for the module:

### Provide options and arguments docs for `mix help`

```elixir
  @shortdoc "Formats an integer in base two or eight"

  @moduledoc """
  #{@shortdoc}

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}
  """
```

This will output something like that (but with colors):

```
%> mix help example

                                  mix example

Formats an integer in base two or eight

## Usage

    mix example [options] <n> <base>

## Options

  • -v, --verbose - Output debug info about the command. Defaults to false.
  • --help - Displays this help.

Location: _build/dev/lib/cli_mate/ebin
```

### Parse the command arguments

And finally our implementation!

```elixir
  @impl true
  def run(argv) do
    %{options: opts, arguments: args} = CLI.parse_or_halt!(argv, @command)

    formatted = Integer.to_string(args.n, args.base)

    if opts.verbose do
      IO.puts("#{args.n} in base #{args.base} is #{formatted}")
    else
      IO.puts(formatted)
    end
  end

  def cast_base("two"), do: {:ok, 2}
  def cast_base("eight"), do: {:ok, 8}
  def cast_base(_), do: {:error, :invalid_base}
```

The `CLI.parse_or_halt!/2` function will return a map with the `:options` and
`:arguments` as maps. The values in those maps are casted according to the
`:type` of an option and the `:type` and/or `:cast` of an argument.

The function will also stop if one of those casting functions fails.

Finally, this function will also halt the VM normally if the `--help` option is
provided. This option is built in and does not need to be defined.

### Display the usage block

All commands in CliMate support a `--help` option by default. This is useful
when Mix is not available. In this example we can still call that with mix:

```
%> mix example --help
Usage

  mix example [options] <n> <base>

Options

  -v, --verbose   Output debug info about the command. Defaults to false.
      --help      Displays this help.
  ```

## Migration to version 0.7.0

The orginal version of CliMate included the CLI code in a consumer module, using
`use CliMate`. This allowed library authors to use CliMate in mix tasks that
could be installed by users with `mix archive.install hex some_package`.
Archives installed that way cannot have dependencies so CliMate was providing a
way to use it anyway.

But this solution had too much problems regarding code loading with the recent
versions of Elixir. So we are stopping support for this feature.

The best way to provide commands with dependencies is to provide an
[escript](https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html) or something
like [burrito](https://github.com/burrito-elixir/burrito).


## Building CLI applications in Elixir

Note that due to the startup time of the BEAM, is is sometimes discouraged to
build command line applications with Elixir.

While the startup problem is real, this is only important for small utilities
like `ls`, `grep` or `cat`. You surely do not want that delay when piping or
looping with those commands in bash scripts.

But for commands that are doing more, like deployments or asset bundling, or
tools that run for a while like credo or dialyzer it is totally fine. And you
get to write them with Elixir!

## Roadmap

We would like to support the following in future releases:

* [ ] Merge code from Argument and Option to provide same capabilities of native
  and custom type casting.
* [ ] Support subcommands for escripts.