defmodule Model.File do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "files" do
    belongs_to(:directory, Model.Directory)
    field(:name, :string)
    field(:relpath, :string)
    field(:size, :integer)
    field(:mimetype, :string)
    field(:qcksum, :string)
    field(:created, :utc_datetime)
    field(:modified, :utc_datetime)
    timestamps()
  end

  @doc ~S"""

  """
  def changeset(%Model.File{} = model, %Ndxr.File{} = ndxr) do
    # Logger.warn("Using file changeset model #{inspect(model)}")
    # Logger.warn("Using file changeset file #{inspect(ndxr)}")
    ndxr = Map.from_struct(ndxr)

    #  |> EctoStorage.preload(:directory)
    # |> cast_assoc(:directory)
    #  |> foreign_key_constraint(:directory_id)
    model
    |> cast(ndxr, [
      :name,
      :relpath,
      :size,
      :mimetype,
      :qcksum,
      :created,
      :modified
    ])
    |> validate_required([:relpath, :name])
    |> unique_constraint(:id, name: :files_pkey)
  end

  def find(%Ndxr.File{} = file, {
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      }) do
    q =
      from(
        f in Model.File,
        join: d in assoc(f, :directory),
        join: c in assoc(d, :catalog),
        where: f.name == ^file.name,
        where: d.relpath == ^directory.relpath,
        where: c.name == ^catalog.name,
        select: [f, d.name, d.id, c.name]
      )

    recs = EctoStorage.all(q)

    case Enum.count(recs) do
      0 -> {:error, :not_found}
      1 -> {:ok, hd(recs)}
      2 -> {:error, "Too many files returned for query"}
    end
  end
end

defimpl Model.Ndxr, for: Ndxr.File do
  require Logger
  import Model.File

  def from(ndxrfile) do
    file = Map.merge(%Ndxr.File{}, ndxrfile)

    %Model.File{
      name: file.name,
      relpath: file.relpath,
      size: file.size,
      mimetype: file.mimetype,
      modified: Ecto.DateTime.cast!(file.modified),
      created: Ecto.DateTime.cast!(file.created)
    }
  end

  def upsert(%Ndxr.File{} = file, {
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      }) do
    case find(file, {directory, catalog}) do
      {:ok, dbfile} ->
        {:ok, EctoStorage.update(changeset(dbfile, file))}

      {:error, :not_found} ->
        {:ok, _} = Model.Directory.find(catalog, directory.relpath)

        {
          :ok,
          EctoStorage.insert(
            changeset(
              %Model.File{},
              file
            )
          )
        }

      {:error, err} ->
        {:error, err}
    end
  end
end
