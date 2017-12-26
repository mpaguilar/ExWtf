defmodule Model.Directory do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [autogenerate: {EctoTimestamps.Local, :autogenerate, [:usec]}]

  schema "directories" do
    belongs_to :catalog, Model.Catalog
    has_many :files, Model.File, [on_delete: :delete_all, on_replace: :delete]
    field :relpath, :string
    field :subdirs, :string
    field :name, :string
    field :qcksum, :string
    timestamps()
  end

  def changeset(%Model.Directory{} = model, %Ndxr.Directory{} = ndxr)
    do
    Logger.warn("Using directory changeset model: #{inspect(model)}")
    Logger.warn("Using directory changeset ndxr: #{inspect(ndxr)}")


    ndxr = %{
      Map.from_struct(ndxr) |
      subdirs: Poison.encode!(ndxr.subdirs)
    }

    model
    # |> EctoStorage.preload(:catalog)
    |> EctoStorage.preload(:files)
    |> cast(ndxr, [:relpath, :name, :qcksum, :subdirs], empty_values: [])
    |> cast_assoc(:files)
    # |> cast_assoc(:catalog)
    |> validate_required([:relpath, :name])
    # |> foreign_key_constraint(:catalog_id)
    |> unique_constraint(:id, name: :directories_pkey)

  end

  def find(%Ndxr.Catalog{} = catalog, relpath)
      when is_bitstring(relpath)
    do

    q = from d in Model.Directory,
             join: c in assoc(d, :catalog),
             where: c.name == ^catalog.name and d.relpath == ^relpath,
             select: [d]

    recs =
      case EctoStorage.all(q) do
        [] -> []
        res -> hd(res)
      end

    case Enum.count(recs) do
      0 -> {:error, :not_found}

      1 -> {:ok, hd(recs)}

      _ -> Logger.error("Too many directory results")
           {:error, "Too many directory results"}
    end

  end

end

defimpl Model.Ndxr, for: Ndxr.Directory
  do
  require Logger
  # import Ecto.Query, only: [from: 2]
  import Model.Directory

  def from(%Ndxr.Directory{} = directory) do
    # ensure all fields are present
    directory = Map.merge(%Ndxr.Directory{}, directory)

    %Model.Directory{
      relpath: directory.relpath,
      subdirs: Poison.encode!(directory.subdirs),
      name: directory.name,
      qcksum: directory.qcksum,
      # files: for nfile <- directory.files
      #  do
      #  Model.Ndxr.from(nfile)
      # end
    }
  end

  def upsert(
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      )
    do

    case find(catalog, directory.relpath) do

      {:ok, dir_rec} ->
        {:ok, EctoStorage.update(changeset(dir_rec, directory))}

      {:error, :not_found} ->

        {:ok, catrec} = Model.Catalog.find(catalog.name)

        Logger.warn("new directory")
        {
          :ok,
          EctoStorage.insert(changeset(
            %Model.Directory{catalog_id: catrec.id},
            directory
          ))
        }

      err -> {:error, err}

    end



  end
end
