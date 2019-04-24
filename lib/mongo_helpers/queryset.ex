defmodule MongoHelpers.Queryset do
  @moduledoc """
  QuerySet holds a set of MongoDB queries and provides operations such as validation and type casting.
  """

  # Define the data structure used for the Queryset.
  defstruct queries: %{find: %{}, projection: %{}, aggregation: []},
            repo: :undefined,
            collection: :undefined,
            valid: true,
            errors: []

  # Alias the Queryset
  alias MongoHelpers.Queryset
  alias Utilities.MapUtils
  # Define characters which could result in an injection to MongoDB .
  @mongo_inject_regex ~r/^.*[{}\[\]()"]+.*$/

  @doc """
  Creates a new Queryset.
  """
  def new(repo, collection) when is_atom(repo) and is_binary(collection) do
    %Queryset{repo: repo, collection: collection}
  end

  @doc """
  Examines a Queryset and returns a new Queryset the validity of which determining whether or not its queries are be susceptible for a MongoDB injection.

  For more please see "No SQL, No Injection", a paper examining the security of NoSQL Injections by IBM (Open Source: https://arxiv.org/ftp/arxiv/papers/1506/1506.04082.pdf)
  """
  def validate_inject(%Queryset{
        queries: queries,
        valid: valid,
        repo: repo,
        collection: collection,
        errors: errors
      }) do
    # Take the `queries` from the Queryset and pass the data through a set of streams responsible for validating its datatype.
    inspected_data =
      inspect_regex(MapUtils.get_recursive_literals(queries), @mongo_inject_regex,
        stream: true,
        false_match: true
      )

    # Aggregate the results of the stream, returning {:ok, queries} if the queries do not carry injection risks or {:error, queries} otherwise.
    case aggregate_inspection(inspected_data) do
      {:ok, _} ->
        # If there are no errors in our query then persist the validity and errors of the input data-structure (the old queryset).
        %Queryset{
          queries: queries,
          valid: valid,
          repo: repo,
          collection: collection,
          errors: errors
        }

      {:error, _} ->
        # If there are errors in our query then add those errors to the list of errors and set the validity of the Queryset to false.
        %Queryset{
          queries: queries,
          valid: false,
          repo: repo,
          collection: collection,
          # Filter the errors from the inspected data.
          errors: [
            Enum.filter(inspected_data, fn
              {:ok, _} -> false
              {:error, value} -> {:error, value}
            end)
            | errors
          ]
        }
    end
  end

  @doc """
  Returns whether a Queryset contains a find statement.

  Find statements are represented as maps when queried to the MongoDB database, as such the method will return false if this condition is unmet..
  """
  def has_find(%Queryset{queries: queries}) do
    is_map(Map.get(queries, :find))
  end

  @doc """
  Returns whether a Queryset contains an aggregation statement.

  Aggregation statements are represented as a list when queried to the MongoDB database, as such the method will return false if this condition is unmet.
  """
  def has_aggregation(%Queryset{queries: queries}) do
    is_list(Map.get(queries, :aggregation))
  end

  @doc """
  Returns whether a Queryset contains a projection statement.

  Projection statements are represented as a map when queried to the MongoDB database, as such the method will return false if this condition is unmet.
  """
  def has_projection(%Queryset{queries: queries}) do
    is_map(Map.get(queries, :projection))
  end

  @doc """
  Returns the MongoDB find statement assigned to the QuerySet.

  The default find statement is %{}. It is recommended to validate with `QuerySet.has_find` whether a statement exists before usage.
  """
  def get_find(%Queryset{queries: queries}) when is_map(queries) do
    Map.get(queries, :find)
  end

  @doc """
  Returns the MongoDB aggregation statement assigned to the QuerySet.

  The default aggregation statement is %{}. It is recommended to validate with `QuerySet.has_aggregation` whether a statement exists before usage.
  """
  def get_aggregation(%Queryset{queries: queries}) when is_map(queries) do
    Map.get(queries, :aggregation)
  end

  @doc """
  Returns the MongoDB projection statement assigned to the QuerySet.

  The default projection statement is %{}. It is recommended to validate with `QuerySet.has_projection` whether a statement exists before usage.
  """
  def get_projection(%Queryset{queries: queries}) when is_map(queries) do
    Map.get(queries, :projection)
  end

  @doc """
  Returns the path of the repository assigned as the MongoDB. This should be the responsible application assigned to the database pool. Idiomatically this is best represented as an atom, however any valid Mix configuration for a MongoDB database pool can be used instead.
  """
  def get_repo(%Queryset{repo: repo}) when is_atom(repo) do
    repo
  end

  @doc """
  Returns whether or not the QuerySet is valid. A default QuerySet instance is considered valid (by virtue of its default configuration). The default configuation is...

  ```
  find = %{}
  projection = %{}
  aggregation = %{}
  repo = :undefined
  errors = []
  ```

  Changes to the QuerySet are then considered valid. Validity assignments mutate based on successful casts.
  """
  def is_valid(%Queryset{valid: validity}) when is_boolean(validity) do
    validity
  end

  @doc """
  Returns the collection assigned to the QuerySet.
  """
  def get_collection(%Queryset{collection: collection}) when is_binary(collection) do
    collection
  end

  @doc """
  Assigns a find statement to the QuerySet.
  """
  def set_find(queryset = %Queryset{queries: queries}, find_query)
      when is_map(find_query) and is_map(queries) do
    new_queries = %{queries | find: find_query}
    %{queryset | queries: new_queries}
  end

  @doc """
  Assigns an aggregation statement to the QuerySet.
  """
  def set_aggregation(queryset = %Queryset{queries: queries}, aggregation_query)
      when is_list(aggregation_query) and is_map(queries) do
    new_queries = %{queries | aggregation: aggregation_query}
    %{queryset | queries: new_queries}
  end

  @doc """
  Assigns a projection statement to a QuerySet.
  """
  def set_projection(queryset = %Queryset{queries: queries}, projection_query)
      when is_map(projection_query) and is_map(queries) do
    new_queries = %{queries | projection: projection_query}
    %{queryset | queries: new_queries}
  end

  @doc """
  Assigns a collection to a QuerySet.
  """
  def set_collection(queryset = %Queryset{collection: collection}, new_collection)
      when is_binary(new_collection) and is_binary(collection) do
    %{queryset | collection: new_collection}
  end

  @doc """
  Assigns a repository to a QuerySet.
  """
  def set_repo(queryset = %Queryset{repo: repo}, new_repo)
      when is_atom(repo) and is_atom(new_repo) do
    %{queryset | repo: new_repo}
  end

  @inspect_regex_defaults %{false_match: false, stream: false}
  defp inspect_regex(binaryset, regex, opts) when is_list(opts) and is_list(binaryset) do
    # The `false match` flag specified as false by default can be set to provide true matches in the case the regular expression is false.
    # The `stream` flag specified as false by default can be set to provide an Elixir Stream of results rather than a concrete enumeration.
    %{false_match: false_match, stream: stream} = Enum.into(opts, @inspect_regex_defaults)

    cond do
      # Inspect a regular expression of a set of values (of arbitrary types) by type casting and returns whether their string form matches a regular expression.
      stream ->
        Stream.map(
          binaryset,
          fn query ->
            match_regex("#{query}", regex, false_match: false_match)
          end
        )

      !stream ->
        Enum.map(
          binaryset,
          fn query ->
            match_regex("#{query}", regex, false_match: false_match)
          end
        )
    end
  end

  @match_regex_defaults %{false_match: false}
  defp match_regex(string, regex, opts) when is_binary(string) do
    %{false_match: false_match} = Enum.into(opts, @match_regex_defaults)

    cond do
      # If false match is true and the regex matches then return :ok.
      false_match and Regex.match?(regex, string) -> {:error, string}
      # If false match is true and the regex does not match then return :ok.
      false_match and !Regex.match?(regex, string) -> {:ok, string}
      # If false match is false and the regex matches.
      !false_match and Regex.match?(regex, string) -> {:ok, string}
      # If false match is false and the regex doesn't match.
      !false_match and !Regex.match?(regex, string) -> {:error, string}
    end
  end

  defp aggregate_inspection(internal_data) do
    case Enum.empty?(internal_data) do
      # In the case of an empty list of data an inspection of that data cannot succeed (we expect data to aggregate).
      true ->
        {:error, []}

      # Expects a list of the forms [{:ok, value}, {:ok, value}] or [{:ok, value}, {:error, value}] or [{:error, value}, {:error, value}], and aggregates the results to a tuple `{:ok, values}` or `{:error, values}`, maintaining whether or not the internal data was errornous.
      false ->
        Enum.reduce(internal_data, {:ok, []}, fn
          {:ok, kv}, {result, acc} -> {result, [kv | acc]}
          {:error, kv}, {_, acc} -> {:error, [kv | acc]}
        end)
    end
  end
end
