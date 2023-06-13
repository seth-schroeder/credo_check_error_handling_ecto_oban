defmodule CredoCheckErrorHandlingEctoOban.MixProject do
  use Mix.Project

  def project do
    [
      app: :credo_check_error_handling_ecto_oban,
      deps: deps(),
      description: description(),
      elixir: "~> 1.14",
      name: "CredoCheckErrorHandlingEctoOban",
      package: package(),
      source_url: "https://github.com/seth-schroeder/credo_check_error_handling_ecto_oban",
      start_permanent: Mix.env() == :prod,
      version: "0.9.1",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
      # maybe some day
      # {:makeup_org, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    This is a custom Credo check that looks for a very specific edge case:

    * Ecto.Repo.transaction/2 will return a 4 tuple when an error occurs inside a Multi.
    * An Oban worker that returns an error 4 tuple will be considered a success.

    """
  end

  defp package() do
    [
      licenses: ["GPL-3.0-or-later"],
      links: %{"GitHub" => "https://github.com/seth-schroeder/credo_check_error_handling_ecto_oban"}
    ]
  end
end
