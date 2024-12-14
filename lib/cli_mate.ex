defmodule CliMate do
  @deprecated """
  Including all CLI code in your own module is no longer supported and will be removedin a future release.

  Please see https://github.com/lud/cli_mate?tab=readme-ov-file#migration-to-version-100

  If you still want to extend the CLI module to add your own helpers, you can use the following:

      require CliMate
      Climate.extend_cli()

  This will delegate all the CLI exported functions into your module.
  """
  defmacro __using__(_) do
    quote do
      CliMate.extend_cli()
    end
  end

  defmacro extend_cli do
    quote unquote: false do
      delegations = [
        color: 2,
        debug: 1,
        error: 1,
        format_usage: 1,
        format_usage: 2,
        halt: 0,
        halt: 1,
        halt_error: 1,
        halt_error: 2,
        halt_success: 1,
        parse: 2,
        parse_or_halt!: 2,
        put_shell: 1,
        shell: 0,
        success: 1,
        warn: 1,
        writeln: 1
      ]

      Enum.each(delegations, fn
        {fun, 0} ->
          defdelegate unquote(fun)(), to: CliMate.CLI

        {fun, arity} ->
          args = Enum.map(1..arity, &Macro.var(:"arg#{&1}", __MODULE__))
          defdelegate unquote(fun)(unquote_splicing(args)), to: CliMate.CLI
      end)
    end
  end
end
