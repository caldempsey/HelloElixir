defmodule Acknowledgements do
  @moduledoc """
  As Elixir has evolved over the past five years, we have grown idiomatic standards of how to express acknowledgements as atoms of `:ok` or `:error` throughout our code. However, by using pattern matching many implementations in many libraries result in repetitive

  `Acknowledgements` aims to reduce repetition of generic use cases when writing Elixir code. Acknowledgements are responses which can be sent from your Elixir modules.

  Acknowledgements encapsulate idiomatic Elixir responses of sending tuples of `{:ok, data}` and `{:error, data}` or `{:error, reasons}`. With this in mind, errors are always sent as a list (of errors as enumerable) and data is always sent as input. The module provides supports sending responses based on asserts some truthy values about the data you are trying to "send" or "return" from your Elixir function, i.e. the length of a list, whether your data matches a specific pattern. The implication of this approach is in reducing code repetition for common operations.


  ## Examples

  To illustrate, it's common to take a list of multiple results and want to guarantee there exists only one result. Each result is represented by an element in a list.
  One approach is to write, `cond do length == 1`, multiple times in our code (resulting in a lot of case operations). We may want to implicitly send the result to the agent _only if_ one result exists. Re-writing multiple case statements can then be helpfully replaced by a call to `Acknowledgements.assert_one` providing `{:ok, data}` if the assertion is true, or `{:error, data}` if the assertion is false. Similarly, it is possible to _send_ that data to an agent using `Acknowledgements.send_one`, which assumes there will be one result, and returns an idiomatic error of the form `{:error, binary()}` if false. For flexibility (as there may be different conventions per implementation) the response string can be customised as opts.

  A call to...
  ```
  no_results = length(results)
  # Check the correct number of results are present and return the result if so.
  if no_results == 1 do
    # Retrieve the first struct from the list.
    {:ok, List.first(results)}
  else
    {:error, "Expected 1 retrieval."}
  end
  ```

  Becomes either...
  `Acknowledgements.assert_one(results, "Expected 1 retrieval")`

  Or...

  `Acknowledgements.send_one(results, "Expected 1 retrieval")`
  """
  @expect_one_exception %{exception: "Expected one result, got invalid value."}

  alias Ecto.Changeset

  @doc """
  Sends a successful acknowledgement.
  """
  def send_success(term) do
    {:ok, term}
  end

  @doc """
  Sends an error acknowledgement.
  """
  def send_error(term) do
    process_error(term)
  end

  defp process_error(term) when is_binary(term) do
    {:error, to_list(term)}
  end

  defp process_error(term) when is_list(term) do
    {:error, to_list(term)}
  end

  defp process_error(term) when is_map(term) do
    {:error, to_list(term)}
  end

  defp process_error(changeset = %Changeset{}) do
    # Process errors from changeset to a list then resend to enforce standard format.
    {:error, send_error(from_changeset(changeset))}
  end

  @doc """
  Asserts the number of elements in a list is equal to one. If true returns {:ok, list}, if false returns {:error,  list}
  """
  def assert_one(term) when is_list(term) do
    # Used to assert the number of results is one. If the number of results is one, returns {:ok, results}. Otherwise returns {:error, results}
    no_elements = length(term)

    if no_elements == 1 do
      {:ok, term}
    else
      {:error, term}
    end
  end

  @send_one_exception %{exception: "Expected one result, got invalid value."}
  @doc """
  Asserts the number of elements in a list is equal to one, and if true sends the result as an acknowledgement. If not returns error followed by a reason.
  """
  def send_one(term, opts \\ []) when is_list(term) and is_list(opts) do
    %{exception: exception} = Enum.into(opts, @send_one_exception)

    case assert_one(term) do
      {:ok, term} -> send_success(List.first(term))
      {:error, term} -> send_error(exception)
    end
  end

  defp to_list(term) when is_list(term) do
    term
  end

  defp to_list(term) do
    [term]
  end

  defp from_changeset(changeset = %Changeset{}) do
    # Recursive enumeration over Ecto changesets.
    changeset
    # Ecto extract and translate the errors
    |> translate_errors
    |> List.flatten()
  end

  defp translate_errors(changeset = %Changeset{}) do
    errors = for change <- changeset.changes, do: elem(change, 1).errors
  end

  @doc """
    Expects a list of acknowledgements and aggregates the results to a single list of acknowledgements, maintaining whether the internal data of the structure contained an error.

    When performing key aggregation ensure that the data is consistent. 

    # Examples 
      
      Suppose we have a list of acknowledgements `[{:ok, "data"}, {:error, "data"},  {:ok, "data"}]`. The acknowledgement will aggregate the first value `:ok` or `:error` such that if `:error` exists within the structure, the result will be `{:ok, data_list}` where data_list refers to all of the data within the result.
       
  """
  def aggregate_key(internal_data) when is_list(internal_data) do
    Enum.reduce(internal_data, {:ok, []}, fn
      {:ok, kv}, {result, acc} -> {result, [kv | acc]}
      {:error, kv}, {_, acc} -> {:error, [kv | acc]}
    end)
  end
end
