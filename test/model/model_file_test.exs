defmodule Model.FileTest do
  use ExUnit.Case, async: false
  require IEx
  require Logger
  doctest ExWtf

  import Model.Ndxr
  import Model.File
  import Ecto.Query, only: [from: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoStorage)

    catalog = %Ndxr.Catalog{
      name: "Test catalog",
      path: "d:\\data\\projects\\elixir",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }

    {:ok, cat_rec} = EctoStorage.insert(Model.Ndxr.from(catalog))

    cat_rec =
      cat_rec
      |> EctoStorage.preload(:directories)

    # Logger.info("test catalog record: #{inspect(cat_rec)}")

    directory = %Ndxr.Directory{
      relpath: "ex_wtf",
      subdirs: ["ah-one", "ah-two"],
      name: "testdata",
      qcksum: "not really"
    }

    {:ok, dir_rec} = EctoStorage.insert(from(directory))

    dir_rec =
      dir_rec
      |> EctoStorage.preload(:files)

    file = %Ndxr.File{
      name: "bogus.txt",
      relpath: "some/path",
      size: 999,
      mimetype: "no mimes!",
      qcksum: "no cksum",
      created: DateTime.utc_now(),
      modified: DateTime.utc_now()
    }

    %{
      catalog: catalog,
      cat_rec: cat_rec,
      directory: directory,
      dir_rec: dir_rec,
      nfile: file
    }
  end

  @tag :skip
  test "from_ndx", %{nfile: file} do
    assert %Model.File{} = from(%Ndxr.File{})
    assert %Model.File{} = from(file)
  end

  @tag :skip
  test "add file", %{
    catalog: catalog,
    directory: directory,
    nfile: file,
    cat_rec: cat_rec,
    dir_rec: dir_rec
  } do
    modfile = from(file)
    assert %Model.File{} = modfile

    modfile =
      %Model.File{modfile | directory_id: dir_rec.id}
      |> EctoStorage.preload(:directory)

    q =
      from(
        f in Model.File,
        join: d in assoc(f, :directory),
        join: c in assoc(d, :catalog),
        where: f.name == ^file.name,
        where: d.name == ^directory.relpath,
        where: c.name == ^catalog.name,
        select: [f, d.name, d.id, c.name],
        preload: [
          directory: d
        ]
      )

    recs = EctoStorage.all(q)

    assert [] == recs

    {:ok, change} =
      case Enum.count(recs) do
        0 ->
          {
            :ok,
            Model.File.changeset(
              %Model.File{directory_id: dir_rec.id},
              file
            )
          }

        1 ->
          {:ok, Model.File.changeset(hd(recs), File)}

        _ ->
          Logger.error("Too many file results")
          {:error, "Too many file results"}
      end

    assert {:ok, newrec} =
             EctoStorage.insert(
               change,
               on_conflict: :replace_all,
               conflict_target: :id
             )

    assert %Model.File{} = newrec
  end

  @tag :skip
  test "upsert file", %{
    catalog: catalog,
    directory: directory,
    nfile: file,
    cat_rec: cat_rec,
    dir_rec: dir_rec
  } do
    assert {:ok, _} = Model.Ndxr.upsert(catalog, nil)
    assert {:ok, _} = Model.Ndxr.upsert(directory, catalog)
    assert {:ok, _} = Model.Ndxr.upsert(file, {directory, catalog})
  end

  @tag :skip
  @tag :thisone
  test "find file", %{catalog: catalog, directory: directory, nfile: file} do
    assert {:error, :not_found} == Model.File.find(file, {directory, catalog})

    assert {:ok, _} = Model.Ndxr.upsert(catalog, nil)
    assert {:ok, _} = Model.Ndxr.upsert(directory, catalog)
    assert {:ok, rec} = Model.Ndxr.upsert(file, {directory, catalog})

    assert {:ok, _} = Model.File.find(file, {directory, catalog})
  end
end
