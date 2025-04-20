defmodule CliMate.CLI.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/cli_mate"
  @version "0.7.1"

  def project do
    [
      app: :cli_mate,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      versioning: versioning(),
      name: "CLI Mate",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      description:
        "Helpers around OptionParser for options and arguments, embeddable in vendored mix tasks.",
      licenses: ["MIT"],
      maintainers: ["Ludovic Demblans <ludovic@demblans.com>"],
      links: %{"GitHub" => @source_url, "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"}
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "samples"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"],
      groups_for_docs: [
        Parsing: &(&1[:section] == :parser),
        "Shell & IO": &(&1[:section] == :io)
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [dialyzer: :test]
    ]
  end

  defp versioning do
    [
      annotate: true,
      before_commit: [
        &update_readme/1,
        {:add, "README.md"},
        &gen_changelog/1,
        {:add, "CHANGELOG.md"}
      ]
    ]
  end

  def update_readme(vsn) do
    version = Version.parse!(vsn)
    readme_vsn = "#{version.major}.#{version.minor}"
    readme = File.read!("README.md")
    re = ~r/:cli_mate, "~> \d+\.\d+"/
    readme = String.replace(readme, re, ":cli_mate, \"~> #{readme_vsn}\"")
    File.write!("README.md", readme)
    :ok
  end

  defp gen_changelog(vsn) do
    case System.cmd("git", ["cliff", "--tag", vsn, "-o", "CHANGELOG.md"], stderr_to_stdout: true) do
      {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
      {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
    end
  end

  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling, :unknown, :extra_return],
      list_unused_filters: true,
      plt_add_deps: :app_tree,
      plt_add_apps: [:ex_unit, :mix],
      plt_local_path: "_build/plts"
    ]
  end
end
