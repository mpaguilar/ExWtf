defmodule ExWtfMain do
  @moduledoc """
  ExWtf main Application
  """

  use Application
  require Logger

  @doc """
  Main entry point
  """

  def start(_type, args) do
    Logger.debug("Starting ExWtf application with args #{inspect(args)}")

    with {:ok, config} <- load_config(args) do
      ExWtf.start_link(config, name: ExWtf)
    else
      true -> {:error}
    end
  end

  defp load_config(args) do

    filename = case args[:config_file] do
      nil -> "wtf_config.json"
      filename -> filename
    end

    Logger.info("Loading config from #{filename}")

    with {:ok, config} <- WtfConfig.load(filename)
      do
      Logger.debug(inspect(config))
      {:ok, struct(WtfConfigData, config)}
    else
      err -> Logger.error(inspect(err))
             {:error}
    end
  end
end

defmodule ExWtf do
  use Supervisor
  # import Supervisor.Spec
  require Logger

  def start_link(%WtfConfigData{} = config, opts) do
    Logger.debug("Starting ExWtf supervisor: #{inspect(config)}")
    Supervisor.start_link(__MODULE__, config, opts)
  end

  # def init(config) do
  def init(_) do

    children = [
      {Registry, keys: :unique, name: Ndxrs},
      {Registry, keys: :duplicate, name: CatalogNotify},
      {Task.Supervisor, name: DbTasks},
      EctoStorage
    ]
    Supervisor.init(children, strategy: :one_for_one)

  end

  def start_catalog(%Ndxr.Catalog{} = catalog) do

    keys = Registry.keys(CatalogNotify, self())

    if("add_directory" not in keys) do

      {:ok, _} = Registry.register(
        CatalogNotify,
        "add_directory",
        {ExWtf, :add_directory}
      )
    end


    Logger.warn("Starting catalog #{inspect(catalog.name)}")

    name = ExWtf.Ndxr.get_id(catalog.name)

    wrkr = worker(ExWtf.Ndxr, [catalog, [name: name]], id: name)

    case Supervisor.start_child(ExWtf, wrkr) do

      {:ok, _} -> :ok

      {:error, {:already_started, pid}} ->
        Logger.warn("Catalog #{inspect(catalog.name)} already started with pid #{inspect(pid)}")

      {:error, err} -> Logger.error(inspect(err))

    end
  end

  def load_catalog(catalog_name)
      when is_bitstring(catalog_name)
    do
    Logger.warn("Loading catalog #{catalog_name}")
    GenServer.cast(
      {:via, Registry, {Ndxrs, catalog_name}},
      {:load_catalog, nil}
    )
  end

  @doc ~S"""
  Appends Ndxr.Directory to state of catalog.
  Used as the callback to load_catalog/3
  """
  def add_directory(catalog, %Ndxr.Directory{} = directory) do
    Logger.info("Adding directory (static) #{inspect(directory.relpath)} for catalog: #{inspect(catalog.name)}")
    Logger.warn("Active children: #{inspect(Supervisor.count_children(__MODULE__))}")
    Task.Supervisor.start_child(DbTasks, ExWtf.NdxrStorage, :add_directory, [catalog, directory])
  end
end
