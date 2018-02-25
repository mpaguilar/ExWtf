# handles the data for one directory
defmodule ExWtf.Ndxr do
  use GenServer
  require Logger

  def start_link(%Ndxr.Catalog{} = catalog) do
    # make all the Path and File libraries happy
    catalog =
      cond do
        "" == catalog.path or "." == catalog.path ->
          %Ndxr.Catalog{catalog | path: "./"}

        true ->
          catalog
      end

    Logger.info("Starting Ndxr process with #{inspect(catalog)}")

    regname = ExWtf.get_id(catalog.name)
    GenServer.start_link(__MODULE__, %NdxrState{catalog: catalog}, name: regname)
  end

  def init(%NdxrState{} = state) do
    {:ok, state}
  end

  @doc ~S"""
  Calls NdxrIO.walk_path/2 asyncronously
  """
  def start_walk(%Ndxr.Catalog{} = catalog) do
    Logger.debug("Loading catalog #{inspect(catalog)}")
    {:ok, _} = Model.Ndxr.upsert(catalog, nil)
    Logger.debug("Catalog updated in db")
    selfpid = self()

    Task.start(fn ->
      try do
        ExWtf.NdxrIO.walk_path(selfpid, catalog, "./")
        Logger.info("Walk path complete")
      after
        # complete even if we crash
        ExWtf.CatalogNdxrs.catalog_complete(catalog)
      end
    end)
  end

  def add_directory(%Ndxr.Catalog{} = catalog, %Ndxr.Directory{} = directory) do
    Logger.debug("Adding directory for catalog #{inspect(catalog)}")
    Logger.debug(" *** \nDirectory: #{inspect(directory)}")

    Model.Ndxr.upsert(directory, catalog)
  end

  # Server callbacks

  def handle_call(msg, _from, ndxrstate) do
    case msg do
      {:add_directory, %Ndxr.Directory{} = newdir} ->
        Logger.debug("Adding directory #{inspect(newdir)} to catalog #{inspect(ndxrstate.catalog)}")
        Logger.info("Adding directory (#{ndxrstate.catalog.name}) - #{newdir.relpath}")
        add_directory(ndxrstate.catalog, newdir)
        {:reply, :ok, ndxrstate}

      _ ->
        Logger.warn("Received unknown call: #{inspect(msg)}")
        {:reply, :error, ndxrstate}
    end
  end

  def handle_cast(msg, ndxrstate) do
    case msg do

      {:add_directory, newdir} ->
        Logger.info("Adding directory #{inspect(newdir)} to catalog #{inspect(ndxrstate.catalog)}")
        add_directory(ndxrstate.catalog, newdir)
        {:noreply, ndxrstate}

      {:ndx_catalog} ->
        Logger.info("Received cast to ndx catalog #{inspect(ndxrstate.catalog.name)}")

        start_walk(ndxrstate.catalog)

        {:noreply, ndxrstate}

      _ ->
        Logger.warn("Received unexpected cast message: #{inspect(msg)}")
        {:noreply, ndxrstate}
    end
  end

  def handle_info(msg, state) do
    Logger.warn("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
