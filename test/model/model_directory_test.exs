defmodule Model.DirectoryTest do
  use ExUnit.Case, async: false
  require Logger
  doctest ExWtf

  import Model.Ndxr
  import Model.Directory
  import Ecto.Query, only: [from: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoStorage)

    catalog = %Ndxr.Catalog{
      name: "Testdata directory",
      path: "D:\\Data\\projects\\elixir\\ex_wtf\\testdata",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }

    directory = %Ndxr.Directory{
      relpath: "./",
      subdirs: ["./subdir", "./whatever"],
      name: "",
      qcksum: "not really"
    }

    %{
      catalog: catalog,
      directory: directory
    }
  end

  test "find extra subdirs", %{catalog: catalog, directory: directory} do
    lvl = Logger.level()
    Logger.configure(level: :debug)

    # File.mkdir("#{catalog.path}/testdir")

    ret = find_subdirs(directory, catalog)
    Logger.debug("dbsubdirs: #{inspect(ret)}")

    :ok = delete_xtra_subdirs(directory, catalog)
    # Logger.debug("xtra: #{inspect(ret)}")

    # File.rmdir("#{catalog.path}/testdir")

    Logger.configure(level: lvl)
  end

  @tag :skip
  test "from_ndx", %{directory: directory} do
    assert %Model.Directory{} = from(%Ndxr.Directory{})
    assert %Model.Directory{} = from(directory)
  end

  @tag :skip
  test "add directory", %{catalog: catalog, directory: directory, cat_rec: cat_rec} do
    assert [] == cat_rec.directories

    moddir = from(directory)

    moddir =
      %Model.Directory{moddir | catalog_id: cat_rec.id}
      |> EctoStorage.preload(:catalog)

    # dirs = 
    Logger.warn("moddir: #{inspect(moddir)}")

    q =
      from(
        d in Model.Directory,
        join: c in assoc(d, :catalog),
        where: d.relpath == ^directory.relpath and c.name == ^catalog.name,
        select: {c.name, d.relpath, d.name}
      )

    recs = EctoStorage.all(q)

    assert [] == recs

    {:ok, change} =
      case Enum.count(recs) do
        0 ->
          {:ok, Model.Directory.changeset(%Model.Directory{catalog_id: cat_rec.id}, directory)}

        1 ->
          {:ok, Model.Directory.changeset(hd(recs), directory)}

        _ ->
          Logger.error("Too many directory results")
          {:error, "Too many directory results"}
      end

    assert {:ok, newrec} =
             EctoStorage.insert(
               change,
               on_conflict: :replace_all,
               conflict_target: :id
             )

    assert %Model.Directory{} = newrec
    # |> EctoStorage.preload(:catalog)
  end

  @tag :skip
  test "directory upsert", %{catalog: catalog, directory: directory} do
    assert {:ok, _} = Model.Ndxr.upsert(directory, catalog)
  end
end
