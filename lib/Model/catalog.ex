defmodule Model.Catalog do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [autogenerate: {EctoTimestamps.Local, :autogenerate, [:usec]}]

  schema "catalogs" do
    field(:name, :string)
    field(:path, :string)
    field(:include, :string)
    field(:exclude, :string)
    field(:fstype, :string)
    field(:host, :string)
    timestamps()
    has_many(:directories, Model.Directory)
  end

  def changeset(%Model.Catalog{} = catalog, %Ndxr.Catalog{} = ndxr) do
    # Logger.warn("Using catalog changeset model #{inspect(catalog)}")
    # Logger.warn("Using catalog changeset ndxr #{inspect(ndxr)}")

    ndxr = %{
      Map.from_struct(ndxr)
      | include: Poison.encode!(ndxr.include),
        exclude: Poison.encode!(ndxr.exclude)
    }

    # |> cast_assoc(:directories)
    catalog
    |> EctoStorage.preload(:directories)
    |> cast(ndxr, [:name, :path, :fstype, :host, :include, :exclude])
    |> validate_required([:name, :path])
    |> unique_constraint(:id, name: :catalogs_pkey)
    |> unique_constraint(:name, name: :catalogs_name_index)
  end

  def find(catalog_name)
      when is_bitstring(catalog_name) do
    # Logger.info("Querying for catalog name #{inspect(catalog_name)}")

    q =
      from(
        c in Model.Catalog,
        where: c.name == ^catalog_name,
        select: c
      )

    recs = EctoStorage.all(q)

    case Enum.count(recs) do
      0 ->
        {:error, :not_found}

      1 ->
        {:ok, hd(recs)}

      _ ->
        Logger.error("Too many catalog results")
        {:error, "Too many catalog results"}
    end
  end
end

defimpl Model.Ndxr, for: Ndxr.Catalog do
  require Logger

  #    import Ecto.Query, only: [from: 2]
  import Model.Catalog

  def from(%Ndxr.Catalog{} = catalog) do
    # ensure all fields are present
    # catalog = Map.merge(%Ndxr.Catalog{}, catalog)
    %Model.Catalog{
      name: catalog.name,
      path: catalog.path,
      include: Poison.encode!(catalog.include),
      exclude: Poison.encode!(catalog.exclude),
      fstype: catalog.fstype
    }
  end

  def upsert(%Ndxr.Catalog{} = catalog, _) do
    Logger.info("Upserting catalog #{inspect(catalog.name)}")

    {:ok, _} =
      case find(catalog.name) do
        {:ok, cat_rec} ->
          Logger.debug("Found catalog #{inspect(catalog.name)}")

          {
            :ok,
            EctoStorage.update(
              changeset(
                cat_rec,
                catalog
              )
            )
          }

        {:error, :not_found} ->
          Logger.debug("Did not find catalog #{inspect(catalog.name)}")

          {
            :ok,
            EctoStorage.insert(
              changeset(
                %Model.Catalog{},
                catalog
              )
            )
          }

        err ->
          {:error, err}
      end
  end
end
