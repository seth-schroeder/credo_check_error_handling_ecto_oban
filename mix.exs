defmodule CredoCheckErrorHandlingEctoOban.MixProject do
  use Mix.Project

  def project do
    [
      app: :credo_check_error_handling_ecto_oban,
      deps: deps(),
      docs: [
        main: "CredoCheckErrorHandlingEctoOban.Check.TransactionErrorInObanJob",
        extras: ["README.md"]
      ],
      elixir: "~> 1.14",
      licenses: "GPL-3.0-or-later",
      source_url: "https://github.com/seth-schroeder/credo_check_error_handling_ecto_oban",
      start_permanent: Mix.env() == :prod,
      version: "0.9.0",
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
end
