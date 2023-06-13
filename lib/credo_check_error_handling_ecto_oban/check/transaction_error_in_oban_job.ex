# This file is part of credo_check_error_handling_ecto_oban.
#
# credo_check_error_handling_ecto_oban is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# credo_check_error_handling_ecto_oban is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with Foobar. If not, see <https://www.gnu.org/licenses/>.

defmodule CredoCheckErrorHandlingEctoOban.Check.TransactionErrorInObanJob do
  @moduledoc """
  `Ecto.Repo.transaction/2` will return a 4 tuple when an error occurs inside a Multi, per
  https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2

  Below is the warning that Oban gives when this happens in `iex`

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

  ----------------------------------------

  Here is an example of the potential situation:

  ```
  def perform(%{}) do
    Multi.new()
    |> Multi.error(:alas, :poor_yorick)
    |> Repo.transaction()
  end
  ```

  Here is an example of the possible resolution (mapping the 4 tuple to a 2 tuple):

  ```
  def perform(%{}) do
    Multi.new()
    |> Multi.error(:alas, :poor_yorick)
    |> Repo.transaction()
    |> case do
         {:ok, _} -> :ok
         {:error, :alas, _, _} -> {:error, "we knew him well"}
       end
  end
  ```

  Please note that this custom credo check is known to have false positives. In order to address
  that it would have to grow closer to an interpreter.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      `Ecto.Repo.transaction/2` will return a 4 tuple when an error occurs inside a Multi, per
      https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2

      Below is the warning that Oban gives when this happens in `iex`

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

      ----------------------------------------

      Here is an example of the potential situation:

      ```
      def perform(%{}) do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
      end
      ```

      Here is an example of the possible resolution (mapping the 4 tuple to a 2 tuple):

      ```
      def perform(%{}) do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
        |> case do
             {:ok, _} -> :ok
             {:error, :alas, _, _} -> {:error, "we knew him well"}
           end
      end
      ```
      """
    ]

  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, nil, issue_meta))
  end

  # Simplify the code by looking only at relevant files
  defp traverse({:defmodule, _, body} = ast, issues, _, _) do
    if in_header?(body, :use, :Oban) do
      {ast, issues}
    else
      {{}, issues}
    end
  end

  defp traverse({:def, [line: line, column: _column], heads} = ast, issues, params, issue_meta) do
    {ast, issues_for_function_definition(heads, line, issues, params, issue_meta)}
  end

  defp traverse({:defp, [line: line, column: _column], heads} = ast, issues, params, issue_meta) do
    {ast, issues_for_function_definition(heads, line, issues, params, issue_meta)}
  end

  # Everything else passes through
  defp traverse(ast, issues, _, _) do
    {ast, issues}
  end

  defp issues_for_function_definition([_, [do: body]], _, issues, _, issue_meta) do
    case walk(body, %{}) do
      # happy path!
      %{:multi_new => _, :repo_transaction => _, error: {:error, _}} ->
        issues

      # warning, unable to find a 4 -> 2 tuple mapping!
      %{:multi_new => [line: line, column: _column], :repo_transaction => _} ->
        [issue_for("potential error handling concern", line, issue_meta) | issues]

      _ ->
        issues
    end
  end

  defp issues_for_function_definition(_, _, issues, _, _), do: issues

  # `walk` does the heavy lifting
  defp walk({:|>, _, args}, acc) do
    Enum.reduce(args, acc, &walk/2)
  end

  defp walk({{:., metadata, [{:__aliases__, _, module}, :new]}, _, body}, acc) do
    acc =
      if Enum.any?(module, &(&1 == :Multi)) do
        Map.put(acc, :multi_new, metadata)
      else
        acc
      end

    Enum.reduce(body, acc, &walk/2)
  end

  defp walk({{:., metadata, [{:__aliases__, _, module}, :transaction]}, _, body}, acc) do
    acc =
      if Enum.any?(module, &(&1 == :Repo or &1 == :repo)) do
        Map.put(acc, :repo_transaction, metadata)
      else
        acc
      end

    Enum.reduce(body, acc, &walk/2)
  end

  defp walk({:case, _, [[do: clauses]]}, acc) do
    Enum.reduce(clauses, acc, &look_at_error_handling/2)
  end

  # trial and error is probably not going to scale ._.
  defp walk(
         {:case, _,
          [
            _,
            [
              do: [{:->, _, [_, {:__block__, _, [_, _, {:|>, _, clauses}]}]}, _]
            ]
          ]},
         acc
       ) do
    Enum.reduce(clauses, acc, &walk/2)
  end

  defp walk({:case, _, [_, [do: [{:->, _, [_, clauses]}]]]}, acc) do
    Enum.reduce(clauses, acc, &look_at_error_handling/2)
  end

  # this open list will probably be a papercut, but opting in is safe
  @expected_methods [
    :!,
    :&&,
    :.,
    :=,
    :__block__,
    :if
  ]

  defp walk({method, _, clauses}, acc) when method in @expected_methods do
    Enum.reduce(clauses, acc, &walk/2)
  end

  # I wish single line if blocks were wrapped in the standard 3 tuple, flatten is painful here
  defp walk([do: do_clauses, else: else_clauses], acc) do
    [else_clauses, do_clauses] =
      Enum.map([else_clauses, do_clauses], fn clauses ->
        clauses
        |> List.wrap()
        |> List.flatten()
      end)

    acc = Enum.reduce(do_clauses, acc, &walk/2)
    Enum.reduce(else_clauses, acc, &walk/2)
  end

  defp walk({{:., _, inner_clauses}, _, outer_clauses}, acc) do
    Enum.reduce(outer_clauses, Enum.reduce(inner_clauses, acc, &walk/2), &walk/2)
  end

  defp walk(_, acc) do
    acc
  end

  # this is the happy case
  defp look_at_error_handling(
         {:->, _, [[{:{}, _, [:error, _, _, _]}], {:error, _} = two_tuple]},
         acc
       ) do
    Map.put(acc, :error, two_tuple)
  end

  # good good, no concerns here
  defp look_at_error_handling({:->, _, [[ok: _], _]}, acc), do: acc

  # this area is concerning
  defp look_at_error_handling({:->, _, [[{:=, _, _}], {:error, _, _}]}, acc), do: acc
  defp look_at_error_handling({:->, _, [[{:{}, _, [:error, _, _]}], {:error, _}]}, acc), do: acc

  # would be better to scan and skip a method definition without Multi.new
  defp look_at_error_handling({_, _, _}, acc), do: acc

  # This HAS to be improvable. It used to have more than one caller.
  defp in_header?([{:__aliases__, _, _}, [do: {:__block__, [], header}]], section, module) do
    header
    |> Enum.filter(fn item ->
      section == get_in(item, [Access.elem(0)])
    end)
    |> Enum.map(fn item ->
      item
      |> get_in([Access.elem(2)])
      |> get_in([Access.at(0)])
      |> get_in([Access.elem(2)])
      |> get_in([Access.at(0)])
    end)
    |> Enum.any?(&Kernel.==(&1, module))
  end

  defp in_header?(_, _, _), do: false

  defp issue_for(trigger, line_no, issue_meta) do
    format_issue(
      issue_meta,
      message: "Potential false negative on Multi error handling in an Oban job",
      trigger: "@#{trigger}",
      line_no: line_no
    )
  end
end
