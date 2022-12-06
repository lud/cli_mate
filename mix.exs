defmodule CliMate.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/cli_mate"
  @version "0.1.0"

  def project do
    [
      app: :cli_mate,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "CLI Mate",
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    []
  end

  defp package do
    [
      description:
        "Helpers around OptionParser for options and arguments, embeddable in vendored mix tasks.",
      licenses: ["MIT"],
      maintainers: ["Ludovic Demblans <ludovic@demblans.com>"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
