require Logger
import ExWtf.Ndxr
Logger.metadata(msg: "command line")


defmodule CliMain do

  def dummy() do
    catalog = %Ndxr.Catalog{
      name: "Test catalog",
      path: "d:\\data\\projects\\elixir\\ex_wtf\\testdata",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }
  end

  def reset() do
    {
      EctoStorage.delete_all(Model.File),
      EctoStorage.delete_all(Model.Directory),
      EctoStorage.delete_all(Model.Catalog)
    }
  end

  def load() do
    Logger.configure(level: :warn)

    with {:ok, config} <- WtfConfig.load("wtf_config.json")
      do
      Logger.debug(inspect(config))

      if false do
        # get the first catalog
        catx = hd(config[:catalogs])
        catalog = struct(Ndxr.Catalog, catx)
        :ok = ExWtf.start_catalog(catalog)

        # this calls cast/2, so it should always return :ok
        :ok = ExWtf.Ndxr.load_catalog(catalog.name)
      else

        Enum.each(
          config[:catalogs],
          fn (cat) ->
            catalog = struct(Ndxr.Catalog, cat)
            :ok = ExWtf.start_catalog(catalog)

            # this calls cast/2, so it should always return :ok
            :ok = ExWtf.Ndxr.load_catalog(catalog.name)
          end
        )
      end

    else

      err -> Logger.error(inspect(err))
    end
  end

  def dir() do
    dir = %Ndxr.Directory{
      relpath: ".",
      files: [],
      subdirs: [],
      name: "testdata",
      qcksum: "fake"
    }
    with {:ok, config} <- WtfConfig.load("wtf_config_test.json")
      do
      cat = hd(config[:catalogs])
      catalog = struct(Ndxr.Catalog, cat)
      {:ok, _} = Model.Ndxr.upsert(dir, catalog)

    end

  end


end

# CliMain.go()
# Process.sleep(10000)
