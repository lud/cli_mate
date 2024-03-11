defmodule CliMate.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/cli_mate"
  @version "0.2.1"

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
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}]
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

  defp update_readme(vsn) do
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
end
