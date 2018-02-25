defmodule Model.Directory do
  require Logger
  import ExWtf.PathHelper

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [autogenerate: {EctoTimestamps.Local, :autogenerate, [:usec]}]

  schema "directories" do
    belongs_to(:catalog, Model.Catalog)
    has_many(:files, Model.File, on_delete: :delete_all, on_replace: :delete)
    field(:relpath, :string)
    field(:subdirs, :string)
    field(:name, :string)
    field(:qcksum, :string)
    timestamps()
  end

  def changeset(%Model.Directory{} = model, %Ndxr.Directory{} = ndxr) do
    # Logger.warn("Using directory changeset model: #{inspect(model)}")
    # Logger.warn("Using directory changeset ndxr: #{inspect(ndxr)}")

    ndxr = %{
      Map.from_struct(ndxr)
      | subdirs: Poison.encode!(ndxr.subdirs)
    }

    model
    |> EctoStorage.preload(:files)
    |> cast(ndxr, [:relpath, :name, :qcksum, :subdirs], empty_values: [])
    |> cast_assoc(:files)
    |> validate_required([:relpath, :name])
    |> unique_constraint(:id, name: :directories_pkey)
  end

  def find(%Ndxr.Catalog{} = catalog, relpath)
      when is_bitstring(relpath) do
    q =
      from(
        d in Model.Directory,
        join: c in assoc(d, :catalog),
        where: c.name == ^catalog.name and d.relpath == ^relpath,
        select: [d]
      )

    recs =
      case EctoStorage.all(q) do
        [] -> []
        res -> hd(res)
      end

    case Enum.count(recs) do
      0 ->
        {:error, :not_found}

      1 ->
        {:ok, hd(recs)}

      _ ->
        Logger.error("Too many directory results")
        {:error, "Too many directory results"}
    end
  end

  def find_subdirs(
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      ) do
    Logger.debug("** dir relpath: #{inspect(directory.relpath)}")

    relpath = ExWtf.PathHelper.normalize_relpath(directory.relpath)

    relpath =
      case String.last(relpath) do
        "/" -> "#{relpath}"
        _ -> "#{relpath}/"
      end

    relpath_exp = "#{relpath}%"

    Logger.debug("*** relpath: #{inspect(relpath_exp)}")

    q =
      from(
        d in Model.Directory,
        join: c in assoc(d, :catalog),
        where: c.name == ^catalog.name and like(d.relpath, ^relpath_exp),
        select: [d.relpath]
      )

    recs = EctoStorage.all(q)

    recs = List.flatten(recs)
    {:ok, re} = Regex.compile("^#{relpath}[^/]+?$")

    {children, descendants} =
      Enum.split_with(recs, fn r ->
        String.match?(r, re)
      end)

    descendants = Enum.filter(descendants, fn d -> d != relpath end)

    # Logger.info("**** \nchildren/descendants: #{inspect({children, descendants})}\n")

    {children, descendants}
  end

  def delete_subdir(%Ndxr.Directory{} = directory, %Ndxr.Catalog{} = catalog, subdir) do
    dpath = "#{directory.relpath}/#{subdir}"
    dpath = normalize_relpath(dpath)
    Logger.warn("deleting db path: (#{catalog.name}) #{catalog.path} - #{inspect(dpath)}")

    # delete the children
    q =
      from(
        d in Model.Directory,
        join: c in assoc(d, :catalog),
        # join: f in assoc(d, :files),
        where: c.name == ^catalog.name and d.relpath == ^dpath
      )

    EctoStorage.delete_all(q)

    # delete the grandchildren
    dpath = "#{dpath}/%"

    q =
      from(
        d in Model.Directory,
        join: c in assoc(d, :catalog),
        # join: f in assoc(d, :files),
        where: c.name == ^catalog.name and like(d.relpath, ^dpath)
      )

    EctoStorage.delete_all(q)
    :ok
  end

  def delete_xtra_subdirs(
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      ) do
    {children, _} = find_subdirs(directory, catalog)

    children =
      Enum.map(children, fn child ->
        String.replace_leading(child, directory.relpath, "./")
        |> normalize_relpath
      end)

    dsubdirs = Enum.sort(directory.subdirs)
    children = Enum.sort(children)

    diff = List.myers_difference(children, dsubdirs)

    cond do
      nil == diff[:del] ->
        :ok

      Enum.count(diff[:del]) == 0 ->
        :ok

      Enum.count(diff[:del]) > 0 ->
        Enum.each(diff[:del], &delete_subdir(directory, catalog, &1))
        :ok
    end
  end
end

defimpl Model.Ndxr, for: Ndxr.Directory do
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
      qcksum: directory.qcksum
      # files: for nfile <- directory.files
      #  do
      #  Model.Ndxr.from(nfile)
      # end
    }
  end

  def upsert(
        %Ndxr.Directory{} = directory,
        %Ndxr.Catalog{} = catalog
      ) do
    case find(catalog, directory.relpath) do
      {:ok, dir_rec} ->
        :ok = Model.Directory.delete_xtra_subdirs(directory, catalog)
        {:ok, EctoStorage.update(changeset(dir_rec, directory))}

      {:error, :not_found} ->
        {:ok, catrec} = Model.Catalog.find(catalog.name)

        {
          :ok,
          EctoStorage.insert(
            changeset(
              %Model.Directory{catalog_id: catrec.id},
              directory
            )
          )
        }

      err ->
        {:error, err}
    end
  end
end
