defmodule Utilities.EctoUtils do
  @doc """
  Executes a set of Ecto queries and concatenates the result of Ecto query structs to a list of structs.

  Returns a set of Ecto structs of result data.
  """
  def concat_ecto_results(queries) do
    Enum.flat_map(queries, fn query ->
      Repo.all(query)
    end)
  end
end
