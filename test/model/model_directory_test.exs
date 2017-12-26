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
            name: "Test catalog", 
            path: "d:\\data\\projects\\elixir",
            include: ["*"],
            exclude: ["*.git"],
            fstype: "local"
        }

        {:ok, cat_rec} = EctoStorage.insert( Model.Ndxr.from(catalog) )  
        
        cat_rec = cat_rec
        |> EctoStorage.preload(:directories)

        # Logger.info("test catalog record: #{inspect(cat_rec)}")

        directory = %Ndxr.Directory{
            relpath: "ex_wtf",
            subdirs: ["ah-one", "ah-two"],
            name: "testdata",
            qcksum: "not really"
        }

        %{
            catalog: catalog,
            cat_rec: cat_rec,
            directory: directory
        }

    end

    @tag :db
    test "from_ndx", %{directory: directory} do
        assert %Model.Directory{} = from(%Ndxr.Directory{})
        assert %Model.Directory{} = from(directory)
    end

    @tag :db
    test "add directory", %{catalog: catalog, directory: directory, cat_rec: cat_rec} do
        assert [] == cat_rec.directories

        moddir = from(directory)
        moddir = %Model.Directory{ moddir | catalog_id: cat_rec.id }
            |> EctoStorage.preload(:catalog)

        # dirs = 
        Logger.warn("moddir: #{inspect(moddir)}")

        q = from d in Model.Directory,
            join: c in assoc(d, :catalog),
            where: 
                d.relpath == ^directory.relpath and 
                c.name == ^catalog.name,
            select: {c.name, d.relpath, d.name}
        
        recs = EctoStorage.all(q)

        assert [] == recs

        {:ok, change} = case Enum.count(recs) do
            0 -> {:ok, Model.Directory.changeset(%Model.Directory{ catalog_id: cat_rec.id }, directory)}
            1 -> {:ok, Model.Directory.changeset(hd(recs), directory)}
            _ -> Logger.error("Too many directory results")
                {:error, "Too many directory results"}
        end
        
        assert {:ok, newrec} = EctoStorage.insert(
            change,
            on_conflict: :replace_all,
            conflict_target: :id
        )

        assert %Model.Directory{} = newrec 
        # |> EctoStorage.preload(:catalog)

    end

    test "directory upsert", %{catalog: catalog, directory: directory} do
        assert {:ok, _} = Model.Ndxr.upsert(directory, catalog)        
    end

end    