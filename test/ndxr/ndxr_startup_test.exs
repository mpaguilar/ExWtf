defmodule ExWtf.Ndxr.Startup.Test do
  use ExUnit.Case
  require Logger
  doctest ExWtf
  import ExWtf
  import ExWtf.Ndxr
  require Logger
  import ExUnit.CaptureLog

  setup do
    {:ok, config} = WtfConfig.load("wtf_config_test.json")
    Logger.warn("config: #{inspect(config)}")

    cat = hd(config[:catalogs])
    catalog = struct(Ndxr.Catalog, cat)

    Logger.warn("catalog: #{inspect(catalog)}")

    %{
      config: config,
      catalog: catalog
    }
  end

  test "main startup", %{config: config} do
    # if it completes, it worked
  end

  test "start and stop catalog", %{catalog: catalog} do
    Logger.info("***************** start and stop catalog")
    assert :ok = ExWtf.CatalogNdxrs.start_catalog(catalog)
    {:ok, _} = GenServer.call(ExWtf.CatalogNdxrs, {:status})
    assert :ok = ExWtf.CatalogNdxrs.stop_catalog(catalog)
  end

  test "external stop catalog", %{catalog: catalog} do
    Logger.info("***************** external stop catalog")
    assert :ok = ExWtf.CatalogNdxrs.start_catalog(catalog)
    {:ok, pid} = ExWtf.CatalogNdxrs.get_catalog_pid(catalog)

    Logger.info("Got pid: #{inspect(pid)}")

    log = capture_log( fn-> 
      DynamicSupervisor.terminate_child(NdxCatalogSupervisor, pid)
      # give it time to fail so we can capture the log
      Process.sleep(100)
    end)
    assert log =~ "Catalog crashed"
  end
end
