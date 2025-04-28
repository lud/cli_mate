# Getting Started With CliMate

This guide demonstrates how to use CliMate to create command-line applications in Elixir. We'll walk through defining a simple command that outputs an integer in base 2 or base 8.

## Defining a Command

A command in CliMate consists of options, arguments, and metadata. First, declare your module as a Mix task and alias the `CliMate.CLI` module:

```elixir
defmodule Mix.Tasks.Example do
  alias CliMate.CLI
  use Mix.Task

  # ...
end
```

Then define your command structure:

```elixir
@command name: "mix example",
         module: __MODULE__,
         options: [
           verbose: [
             short: :v,
             type: :boolean,
             default: false,
             doc: "Output debug info about the command."
           ]
         ],
         arguments: [
           n: [type: :integer, doc: "The value to convert."],
           base: [
             cast: &__MODULE__.cast_base/1,
             doc: "A numeric base. Accepts 'two' or 'eight' only!"
           ]
         ]
```

The `name` should reflect how the command is invoked. This will be displayed in the help text.

## Parsing Command Arguments

Use the `CliMate.CLI.parse_or_halt!/2` function to parse command arguments:

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

The `parse_or_halt!/2` function returns a map with `:options` and `:arguments` keys. Values are automatically cast according to the specified `:type` or `:cast` functions. If parsing fails, it will display the usage information and halt with an error message.

## Argument Types and Options

### Argument Types

CliMate supports the following argument types:

- `:string` (default)
- `:integer`
- `:float`

```elixir
arguments: [
  count: [type: :integer, doc: "A count parameter"],
  rate: [type: :float, doc: "A floating point value"],
  name: [type: :string, doc: "A name"]
]
```

### Arguments Configuration

Arguments support the following parameters:

- `:required` - Default is `true`. Set to `false` for optional arguments.
- `:cast` - A function or MFA tuple that casts the value.
- `:doc` - Documentation string shown in help text.

```elixir
arguments: [
  required_arg: [],
  custom_arg: [cast: &MyModule.custom_cast/1]
  optional_arg: [required: false],
]
```

Non-required arguments must be defined after required ones.

### Option Types

Options support the following types:

- `:boolean` - Flags that don't need values (`--verbose`)
- `:count` - Counts the number of times an option appears
- `:integer` - Integer values
- `:float` - Floating point values
- `:string` - String values (default)

```elixir
options: [
  verbose: [type: :boolean],
  count: [type: :count],
  port: [type: :integer, default: 8080],
  rate: [type: :float],
  name: [] # :string is default
]
```

### Options Configuration

Options can be configured with:

- `:short` - Single letter alias (`:v` for `-v`)
- `:default` - Default value or function
- `:keep` - Keep all values when an option is repeated
- `:doc_arg` - Custom display name for the argument
- `:doc` - Option description

```elixir
options: [
  names: [short: :n, keep: true, doc: "Collects names (can be repeated)"],
  port: [short: :p, default: 4000, doc: "Port number"],
  type: [doc_arg: "db-type", doc: "Database type to use"]
]
```

## Automatic Help Option

All commands automatically include a `--help` option. When used, it displays command usage and halts the program with a success code (0).

```
%> mix example --help
mix example version 0.7.1

Synopsis

  mix example [options] <n> <base>

Arguments

  n
  The value to convert.

  base
  A numeric base. Accepts 'two' or 'eight' only!

Options

  -v, --verbose
        Output debug info about the command. Defaults to false.

      --help
        Displays this help.
```

## Providing Documentation for `mix help`

You can include command usage in your module documentation:

```elixir
@shortdoc "Formats an integer in base two or eight"

@moduledoc """
#{@shortdoc}

#{CliMate.CLI.format_usage(@command, format: :moduledoc)}
"""
```

## Advanced Usage

For more detailed information on configuring options and arguments, see:

- `CliMate.CLI.Argument` for advanced argument configuration
- `CliMate.CLI.Option` for advanced option configuration