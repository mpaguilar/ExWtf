defmodule ExWtf.Catalog.Test do
  use ExUnit.Case
  require Logger
  doctest ExWtf
  import ExWtf
  require Logger

  require IEx

  setup_all do
    ExUnit.configure(timeout: :infinity)
    {:ok, config} = WtfConfig.load("wtf_config_test.json")
    Logger.warn("config: #{inspect(config)}")

    cat = hd(config[:catalogs])
    catalog = struct(Ndxr.Catalog, cat)

    Logger.warn("catalog: #{inspect(catalog)}")
    :ok = ExWtf.CatalogNdxrs.start_catalog(catalog)

    on_exit fn ->
      :ok = ExWtf.CatalogNdxrs.stop_catalog(catalog)
    end

    %{
      catalog: catalog
    }
  end
  

  test "run one catalog", %{catalog: catalog} do
    Logger.info("***************** run one catalog")
    ExWtf.CatalogNdxrs.start_ndxr(catalog)

    Process.sleep(10000)
  end
end

#    while_running = fn(cur, fun) ->
#      if cur > 0 do
#        Logger.debug("### Servers running: #{inspect(cur)}")
#        Process.sleep(1000)
#        {:ok, c} = GenServer.call(ExWtf.CatalogNdxrs, {:status})
#        fun.(c, fun)        
#      end
#    end
