defmodule MongoHelpers.QueryManager do
  @moduledoc """
  QueryManager is a helper module responsible for handling the execution of MongoDB queries.

  Although QueryManager will not execute queries using an invalid QuerySet,  QueryManager takes a `DfmsData.QuerySet` as input and translates the QuerySet to executable MongoDB Queries. The motivation behind this is to encourage well-formed and validated use of the MongoDB library (which in itself contains no validation protocols). QueryManager is not responsible for attributing the validity of a QuerySet, and as such improper use of the QueryManager still attributes risk. Please see QuerySet documentation (in particular getters and setters) for more details on proper usage.
  """
  alias MongoHelpers.Queryset
  @query_defaults %{raw_cursor: false}

  @doc """
  Executes a MongoDB find query given a valid QuerySet.
  """
  def execute(:find, queryset = %Queryset{queries: queries}, raw_cursor)
      when is_map(queries) and is_boolean(raw_cursor) do
    # Check if the query has a projection.
    cond do
      Queryset.has_find(queryset) and Queryset.has_projection(queryset) and
          Queryset.is_valid(queryset) ->
        find = Queryset.get_find(queryset)
        projection = Queryset.get_projection(queryset)

        {:ok,
         make_find(
           find,
           projection,
           Queryset.get_repo(queryset),
           Queryset.get_collection(queryset),
           raw_cursor: raw_cursor
         )}

      Queryset.has_find(queryset) and not Queryset.has_projection(queryset) and
          Queryset.is_valid(queryset) ->
        find = Queryset.get_find(queryset)
        projection = %{}

        {:ok,
         make_find(find, projection, queryset.repo, queryset.collection, raw_cursor: raw_cursor)}

      true ->
        {:error, "Queryset must be valid and have a find statement associated."}
    end
  end

  @doc """
  Executes a MongoDB aggregation query given a valid QuerySet.
  """
  def execute(:aggregate, queryset = %Queryset{queries: queries}, raw_cursor)
      when is_map(queries) and is_boolean(raw_cursor) do
    # Check if the query has an aggregation.
    cond do
      Queryset.has_aggregation(queryset) and Queryset.is_valid(queryset) ->
        aggregation_query = Queryset.get_aggregation(queryset)

        {:ok,
         make_aggregation(
           aggregation_query,
           Queryset.get_repo(queryset),
           Queryset.get_collection(queryset),
           raw_cursor: raw_cursor
         )}

      true ->
        {:error, "Queryset must be valid and have an aggregation statement associated."}
    end
  end

  defp make_aggregation(aggregation_query, repo, collection, opts)
       when is_list(opts) and is_list(aggregation_query) and is_atom(repo) and
              is_binary(collection) do
    %{raw_cursor: raw_cursor} = Enum.into(opts, @query_defaults)

    cond do
      raw_cursor == true ->
        Mongo.aggregate(repo, collection, aggregation_query, pool: DBConnection.Poolboy)

      raw_cursor == false ->
        Mongo.find(repo, collection, aggregation_query, pool: DBConnection.Poolboy)
        |> Enum.to_list()
    end
  end

  defp make_find(query, projection, repo, collection, opts) do
    %{raw_cursor: raw_cursor} = Enum.into(opts, @query_defaults)

    cond do
      raw_cursor == true ->
        Mongo.find(repo, collection, query, projection: projection, pool: DBConnection.Poolboy)

      raw_cursor == false ->
        Mongo.find(repo, collection, query, projection: projection, pool: DBConnection.Poolboy)
        |> Enum.to_list()
    end
  end
end
