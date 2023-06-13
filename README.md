# CredoCheckErrorHandlingEctoOban

This is a custom [Credo](https://github.com/rrrene/credo) check that looks for a very specific edge case:

* [Ecto.Repo.transaction/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2) will return a 4 tuple when an error occurs inside a Multi.
* An [Oban](https://github.com/sorentwo/oban) worker that returns an error 4 tuple will be considered a success.

Many thanks to [@andersonmcook](https://github.com/andersonmcook) for being the human version of this check!

Below is the warning that Oban gives when this happens in `iex`

```elixir
  iex(14)> [warning] Expected Elixir.MyApp.MultiFailure.perform/1 to return:
  - `:ok`
  - `:discard`
  - `{:ok, value}`
  - `{:error, reason}`,
  - `{:cancel, reason}`
  - `{:discard, reason}`
  - `{:snooze, seconds}`
  Instead received:
  {:error, :alas, :poor_yorick, %{}}

  The job will be considered a success.
```

Here is an example of a potential situation:

  ```elixir
  def perform(%{}) do
    Multi.new()
    |> Multi.error(:alas, :poor_yorick)
    |> Repo.transaction()
  end
  ```

Here is a possible resolution (mapping the 4 tuple to a 2 tuple):

  ```elixir
  def perform(%{}) do
    Multi.new()
    |> Multi.error(:alas, :poor_yorick)
    |> Repo.transaction()
    |> case do
         {:error, :alas, _, _} -> {:error, "we knew him well"}
         any -> any
       end
  end
  ```

Please note that this custom credo check is known to have false positives. In order to address
that it would have to grow closer to an interpreter. It has been lightly tested against public repositories,
and has moderate unit test coverage.

My [Org mode](https://orgmode.org/) brain dump is [progress.org](progress.org).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `credo_check_error_handling_ecto_oban` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:credo_check_error_handling_ecto_oban, "~> 0.9.0", only: [:dev, :test], runtime: false}
  ]
end
```

### Add to your `.credo.exs`.

Recent versions of `credo`:

```elixir
  checks: %{
    enabled: [
      # ...
      {CredoCheckErrorHandlingEctoOban.Check.TransactionErrorInObanJob, []}
    ]
  }
```

Older versions of `credo`:

```elixir
  checks: [
    # ...
    {CredoCheckErrorHandlingEctoOban.Check.TransactionErrorInObanJob, []}
  ]
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/credo_check_error_handling_ecto_oban>.

