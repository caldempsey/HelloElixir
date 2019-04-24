defmodule Utilities.MapUtils do
  @moduledoc """
  Placeholder module document.
  """

  @doc """
  Takes a map and a bare map map as input. Returns only the values of bare map that correspond to the keys passed to the former map.
  ## Example
  ```
  IO.inspect DfmsData.map_filter(%{"id"=> 32}, %{"id"=> 12, "name"=> "some username"})
  ```
  Returns `%{"id"=>12}
  """
  def map_filter(filter_keys, map) do
    Enum.reduce(
      filter_keys,
      %{},
      fn {key, _}, acc ->
        atom_key = String.to_atom(key)

        case Map.get(map, atom_key) do
          nil ->
            acc

          value ->
            Map.put_new(acc, atom_key, value)
        end
      end
    )
  end

  @doc """
  Returns a list of all literal values in a map (of lists of maps).
  """
  def get_recursive_literals(input) when is_map(input) do
    Enum.flat_map(input, fn {_, value} -> do_values(value, []) end) |> List.flatten()
  end

  # If the input is a struct, then skip it. 
  defp do_values(%_{}, acc), do: acc

  defp do_values(map, acc) when is_map(map) do
    [Enum.flat_map(map, fn {_key, value} -> do_values(value, []) end) | acc]
  end

  defp do_values(list, acc) when is_list(list) do
    list
    |> Enum.flat_map(fn v -> do_values(v, []) end)
    |> Enum.concat(acc)
  end

  defp do_values(literal, acc) do
    [literal | acc]
  end

  @doc """
  Expects input data in the form of a `struct` datatype. Creates a map from that existing struct containing only key-value pairs corresponding to data related to known areas.

  Returns an Elixir map having extracted relevant data.
  """
  def extract(:struct, struct = %{}, keys) when is_list(keys) do
    struct |> Map.from_struct() |> Map.take(keys)
  end
end
