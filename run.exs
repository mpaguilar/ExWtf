require Logger
Logger.metadata(msg: "command line")

defmodule CliMain do
  def wait() do
    while_running = fn cur, fun ->
      if Enum.count(cur) > 0 do
        Process.sleep(1000)
        Logger.debug("### Servers running: #{inspect(cur)}")

        {:ok, c} = GenServer.call(ExWtf.CatalogNdxrs, {:status})
        fun.(c, fun)
      else
        Logger.debug("### Servers running: #{inspect(cur)}")
      end
    end

    {:ok, c} = GenServer.call(ExWtf.CatalogNdxrs, {:status})
    while_running.(c, while_running)
  end

  # if you want to use a different config file...
  def run_config(filename) do
    {:ok, config} = WtfConfig.load(filename)

    Enum.each(config[:catalogs], fn catalog_config ->
      catalog = struct(Ndxr.Catalog, catalog_config)

      Logger.info("Starting catalog #{inspect(catalog.name)}")

      :ok = ExWtf.CatalogNdxrs.start_catalog(catalog)
      :ok = ExWtf.CatalogNdxrs.start_ndxr(catalog)
    end)

    wait()
  end

  def run() do
    ExWtf.CatalogNdxrs.run()
    wait()
  end
end
Logger.configure(level: :info)

CliMain.run()

# CliMain.run_config("wtf_config_dummy.json")
