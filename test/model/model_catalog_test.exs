defmodule Model.CatalogTest do
    use ExUnit.Case, async: false
    require Logger
    doctest ExWtf

    import Model.Ndxr
    import Ecto.Query, only: [from: 2, preload: 2]

    
    setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoStorage)

        catalog = %Ndxr.Catalog{ 
            name: "Test catalog", 
            path: "d:\\data\\projects\\elixir",
            include: ["*"],
            exclude: ["*.git"],
            fstype: "local"
        }

        %{
            catalog: catalog
        }

    end

    @tag :db
    test "get path from catalog", %{catalog: catalog} do
        assert {:ok, rec} = Model.Ndxr.upsert(catalog, nil)
        # not working
        # assert nil = Model.Catalog.get_path(rec, "")
    end

    @tag :db
    test "from_ndx", %{catalog: catalog} do
        assert %Model.Catalog{} = from(%Ndxr.Catalog{})
        assert %Model.Catalog{} = from(catalog)
        :ok
    end

    @tag :db
    test "add to catalog", %{catalog: catalog} do
        {:ok, _} = EctoStorage.insert( Model.Ndxr.from(catalog) )
        :ok
    end

    @tag :db
    test "update catalog", %{catalog: catalog} do
        
        # do we already have this catalog?
        q = from c in Model.Catalog,
            where: c.name == ^catalog.name,
            select: c

        dbres = EctoStorage.all(q)

        # we shouldn't, we've just started the test
        assert [] == dbres
       
        # add a record
        onerec = from(catalog)
        Logger.warn("onerec: #{inspect(onerec)}")
        assert {:ok, res} = EctoStorage.insert(
            onerec, 
            on_conflict: :replace_all,
            conflict_target: :id
            )

        # let's find the record we created
        dbres = EctoStorage.all(q)
        |> EctoStorage.preload(:directories)

        # there should be only one
        Logger.info("dbres: #{inspect(dbres)}")
        assert 1 == Enum.count(dbres)
        dbres = hd(dbres)
        
        # make a change from Ndxr.Catalog
        newcat = %Ndxr.Catalog{catalog | path: "whatever you say"}
        Logger.info("newcat: #{inspect(newcat)}")

        change = Model.Catalog.changeset(dbres, newcat)
        assert true == change.valid?

        Logger.warn("change valid?: #{inspect(change)}")

        assert {:ok, ares} = EctoStorage.insert(
            change,
            on_conflict: :replace_all,
            conflict_target: :id)

        dbres = EctoStorage.all(q)
        assert [%Model.Catalog{} = res] = dbres
        Logger.warn("res: #{inspect(res)}")
    end

    @tag :db
    test "upsert for sure", %{catalog: catalog} do
        #catalog = Model.Ndxr.from(catalog) |> preload(:directories)

        {:ok, cat_rec} = EctoStorage.insert( Model.Ndxr.from(catalog ))

        assert {:ok, res} = Model.Ndxr.upsert(catalog, nil)
        assert {:ok, %Model.Catalog{}} = res
    end

end