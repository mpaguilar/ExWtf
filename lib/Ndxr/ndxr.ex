# handles the data for one directory
defmodule ExWtf.Ndxr do
  use GenServer
  require Logger
  import ExWtf.NdxrIO

  def start_link(%Ndxr.Catalog{} = catalog, opts) do
    # make all the Path and File libraries happy
    catalog = cond do
      ( "" == catalog.path or "." == catalog.path ) ->
        %Ndxr.Catalog{ catalog | path: "./" }
      true -> catalog
    end

    Logger.info("Starting Ndxr with #{inspect(catalog)}")
    Logger.info("Ndxr #{catalog.name} options: #{inspect(opts)}")
    istate = %NdxrState{ catalog: catalog }
    GenServer.start_link(__MODULE__, istate, opts)
  end

  def init(%NdxrState{} = state) do   

    # {:ok, _} = Registry.register(
    #  CatalogNotify,
    #  "add_directory",
    #  {ExWtf.Ndxr, :add_directory})

    {:ok, state}
  end

  def get_id(catalog_name) do
    {:via, Registry, {Ndxrs, catalog_name}}
  end

  @doc ~S"""
  Starts crawling file system to load up the internal Directorys
  """

  def load_catalog(catalog_name) do
    Logger.warn("Loading catalog")
    GenServer.cast(get_id(catalog_name), :load_catalog)
  end

  @doc ~S"""
  Updates the db with it's current catalog,
  then starts the crawl
  """
  def handle_cast(:load_catalog, ndxrstate) do
    Logger.warn("recd msg to load catalog #{inspect(ndxrstate.catalog.name)}")
    {:ok, _} = Model.Ndxr.upsert(ndxrstate.catalog, nil)
    make_directories(ndxrstate.catalog)
    {:noreply, ndxrstate}
  end

  @doc ~S"""
  Calls NdxrIO.walk_path/2 asyncronously
  """
  def make_directories(%Ndxr.Catalog{} = catalog) do

    Logger.debug("Loading catalog #{inspect(catalog)}")

    # why a Task? So that the task can update the caller.
    walk_task = Task.async(
      fn -> walk_path(catalog, "")
      end)

    case Task.await(walk_task, :infinity) do
      {:ok, dirs} -> {:ok, dirs}
      :error -> 
        Logger.error("Error building directories")
        {:error, "Error building directories"}
    end
  end

  @doc ~S"""
  Returns the current list of directories 
  """
  def get_directories(catalog_name) do
    GenServer.call(get_id(catalog_name), :get_directories)
  end

  def handle_call(:get_directories, _from, state) do
    {:reply, {:ok, state.directories}, state}
  end

end
