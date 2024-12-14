defmodule CliMate do
  @deprecated """
  just import CliMate.CLI
  """
  defmacro __using__(_) do
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
