defmodule ExWtf.NdxrTest do

    use ExUnit.Case, async: false
    require Logger
    doctest ExWtf

    import ExWtf.Ndxr

    setup do
        {:ok, config} = WtfConfig.load("wtf_config_test.json")
        Logger.warn("config: #{inspect(config)}")

        cat = hd(config[:catalogs])
        catalog = struct(Ndxr.Catalog, cat)
        
        name = {:via, Registry, {Ndxrs, catalog.name}}

        Logger.warn("catalog: #{inspect(catalog)}")
        
        {:ok, _} = ExWtf.Ndxr.start_link(catalog, name: name)                 

        %{
            config: config,
            name: name,
            catalog: catalog
        }     
    end

@tag :thatone
    test "ndxr startup", %{config: config} do
        # we want to use a different process name for this
        # than is in the test setup to check for collisions
        Logger.info("Ndxr startup: #{inspect(config)}") 
        name = {:via, Registry, {Ndxrs, "ndxr startup"}}
        catalog = struct(Ndxr.Catalog, (hd(config[:catalogs])))   

        assert %Ndxr.Catalog{} = catalog
        res = ExWtf.Ndxr.start_link(catalog, name: name)
        assert {:ok, _} = res

        name2 = {:via, Registry, {Ndxrs, "ndxr startup two"}}
        res = ExWtf.Ndxr.start_link(catalog, name: name2)
        assert {:ok, _} = res
    end

    def test_cb(data) do
        Logger.warn("Test data: #{inspect(data)}")
        data
    end

    test "ndxr load catalog (direct)", %{catalog: catalog} do

        Logger.info("Ndxr load catalog: #{inspect(catalog)}") 

        catalog = cond do
            ( "" == catalog.path or "." == catalog.path ) ->
                %Ndxr.Catalog{ catalog | path: "./" }
            true -> catalog
        end

        assert {:ok, _} = make_directories(catalog)        
    end

    test "async ndxr load catalog (cast)", %{name: name} do
        assert :ok = GenServer.cast(name, :load_catalog )        
        assert {:ok, _} = GenServer.call(name, :get_directories)
    end

    @tag :quick
    test "quick", %{catalog: catalog} do
        Logger.warn("Doing a quick test! #{inspect(catalog)}")
        # catalog = %Ndxr.Catalog{ catalog | path: "."}
        assert nil == make_directories(catalog)        
    end
end
